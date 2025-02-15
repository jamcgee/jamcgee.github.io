---
date: 2021-08-24T00:00:00-07:00
title: FreeBSD Jails And Networking
slug: freebsd-jail-networking
tags:
  - containers
  - FreeBSD
  - jails
  - network
  - sysadmin
---

When using FreeBSD, the most common method for virtualization and process isolation are jails.
Introduced with FreeBSD 4.0 in March of 2000, they predate the closest Linux equivalent, cgroups (and, by extension, Docker), by nearly a decade.

A core part of any virtualization technology is its interaction with the networking infrastructure.
In this regard, I've found much of the [available documentation](https://docs.freebsd.org/en/books/handbook/jails/) lacking, often deferring to third party tools which are no longer maintained.
As such, I've had to scrape multiple sources and [reverse engineer system programs]({{< relref "/article/2020-12-27-freebsd-jail-startup" >}}) to figure out how it's put together.

In today's article, I'll describe the results of my foray into FreeBSD jail networking.
It's not the most cohesive piece, but I'll refine it over time and hopefully it will assist someone else in their efforts to deploy FreeBSD jails.

> **Note:** These instructions were written at the time of FreeBSD 13.0.

## IP Sharing

When jails were first introduced, they were modeled as a variant of [`chroot(2)`](https://www.freebsd.org/cgi/man.cgi?query=chroot&sektion=4), placing direct constraints on the superuser instead of creating a virtual machine.
In this initial implementation, one of the objectives was to restrict access to the networking stack.
Instead of having unfettered access, raw sockets are forbidden and socket activity is limited to a subset of the host's addresses.

There's multiple ways to implement this in practice.
The most common mechanism is to load up a bunch of IPs on the loopback device `lo0` and use firewall translation rules to give it network access.
For example:

```sh
# jail.conf
www {
  ip4.addrs += "lo0|192.168.0.5";
}
```

```sh
# pf.conf
nat on $ext_if from 192.168.0.0/24 -> $ext_if:0
rdr on $ext_if to $ext_if:0 port 80 -> 192.168.0.5
```

Alternatively, the jail can be given addresses on the network device directly:

```sh
# jail.conf
www {
  # The ordering of these addresses is significant
  ip4.addrs += "lo0|127.0.0.2";
  ip4.addrs += "igb0|1.2.3.4";
}
```

The first caveat concerns the handling of loopback in general.
As the addresses `127.0.0.1` and `::1` still belong to the host, those addresses are not available to jails.
Instead, the jail will treat the first address listed under `ip4.addrs` and `ip6.addrs` as its loopback addresses and any attempt to bind to `127.0.0.1` or `::1` will bind to these addresses instead.
This is why it's critical that the first address be an internal interface and protected using the system firewall.

The second caveat stems from the nature of addresses as a shared resource between the jail and the host.
This means that even when binding jails to external IPs, all traffic between jails will occur over `lo0` instead of the expected interface, which is important when constructing firewall rules.
And since these addresses are shared with the host, the host can freely use these addresses when communicating with jails and will be able to bind (commonly seen by `ntpd` and `sshd` in their default configurations).
It is important to avoid wildcard bindings on a machine hosting jails, especially on interfaces shared with jails.

A common problem seen when using IPv6 with jails is that a given IPv6 address is not available in time for daemon startup, generating unexpected failures.
This is a side-effect of the IPv6 Duplicate Address Detection (DAD) feature.
There are two possible workarounds:

- Delay jail startup long enough for DAD to complete.
- Set the sysctl `net.inet6.ip6.dad_count=0` to disable DAD entirely.

## Network Virtualization

Over time, jails evolved from a refinement of `chroot(2)` to a more complete virtualization system.
Kernel subsystems gained the ability to be virtualized, granting a unique namespace to jails, much like Linux's cgroups.
One of the first examples of this was the System V IPC mechanisms (e.g. `sysvshm`).

For several releases, FreeBSD had a work-in-progress jail feature where the networking stack could be virtualized.
Called [VNET](https://www.freebsd.org/cgi/man.cgi?query=vnet&sektion=9), it allowed jails to completely take over any number of interfaces (real or synthetic) and construct a proper networking stack.
However, it was liable to induce kernel panics until it was finally brought to heel in the 12.0 release and became a standard part of the default kernel.

The simplest method is to simply grant a jail exclusive control of a hardware device.

```sh
www {
  vnet;
  vnet.interface += "igb2";
}
```

When a jail marked as `vnet` is started, a new instance of the kernel's networking stack is brought up with its own, unique set of interfaces (including an `lo0`), addresses, routing tables, and firewall rules.
The `jail(8)` utility will then take the listed interfaces and transfer ownership to the jail's networking stack.
Once that's done, said interface completely disappears from the host and the jail can use it as a normal interface under its control.

From inside the jail, we'll see a completely normal set of network interfaces:

```plain
> ifconfig
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> metric 0 mtu 16384
        options=680003<RXCSUM,TXCSUM,LINKSTATE,RXCSUM_IPV6,TXCSUM_IPV6>
        inet6 ::1 prefixlen 128
        inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
        inet 127.0.0.1 netmask 0xff000000
        groups: lo
        nd6 options=21<PERFORMNUD,AUTO_LINKLOCAL>
pflog0: flags=0<> metric 0 mtu 33160
        groups: pflog
igb2: flags=8822<BROADCAST,SIMPLEX,MULTICAST> metric 0 mtu 1500
        options=4e507bb<RXCSUM,TXCSUM,VLAN_MTU,VLAN_HWTAGGING,JUMBO_MTU,VLAN_HWCSUM,TSO4,TSO6,LRO,VLAN_HWFILTER,VLAN_HWTSO,RXCSUM_IPV6,TXCSUM_IPV6,NOMAP>
        ether 90:e2:ba:74:ba:ec
        media: Ethernet autoselect (1000baseT <full-duplex>)
        status: active
        nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>
```

And we can configure it like any normal interface using `rc.conf`:

```sh
# /etc/rc.conf
ifconfig_igb2="DHCP"
ifconfig_igb2_ipv6="inet6 accept_rtadv"
```

When the jail is shutdown, the hardware device will be returned to the host's control...eventually.
Any outstanding connections are closed and placed into the `TIME_WAIT` state.
Only once these connections expire will the interface be returned to the host, which can be a massive annoyance when restarting a jail.
Thus far, I haven't found an effective way to speed up the process.

### if_bridge and if_epair

While some people may be able to dedicate an ethernet device to each jail, most people are going to engage in some form of software-defined networking.
The traditional technique for this involves the use of [`if_bridge(4)`](https://www.freebsd.org/cgi/man.cgi?query=if_bridge&sektion=4) and [`if_epair(4)`](https://www.freebsd.org/cgi/man.cgi?query=if_epair&sektion=4).

`if_epair` is a synthetic ethernet device that is the equivalent of a cross-over cable.
When a new instance is cloned, you end up with a pair of interfaces, `epair<num>a` and `epair<num>b`.
All traffic sent on one interface is received by the other.
Using VNET, one end can be inserted into the jail to exchange traffic with the host.

```sh
# jail.conf
www {
  vnet;
  vnet.interface += "epair0b";
}
```

The administrator is left with two possible choices: either they can assign an IP to the host system's end and treat it as a point-to-point link, performing routing and translation as necessary, or they can *bridge* the endpoints with each other and a physical network.
When using the `epair` as a point-to-point link, we need only give it an address on the host side.

```sh
# rc.conf
cloned_interfaces="epair0"
ifconfig_epair0a="inet 1.2.3.4/30 up"
```

More commonly, the host side of the `epairs` are all bundled together and (optionally) connected to an external interface.
This uses the `if_bridge` interface, which behaves like a network switch.

```sh
# rc.conf
cloned_interfaces="bridge0 epair0"
ifconfig_bridge0="addm igb0 addm epair0a up"
ifconfig_igb0="up"
ifconfig_epair0a="up"
```

There's a few caveats to consider.
First, this can result in a massive number of network devices on the host system.
Second, this will disable any hardware features on a physical device like TCP overloading and checksum computation.
Third, performance can be poor as the bridge is not thread-safe and will serialize all traffic through a single lock.

But most of all, firewall rules under this arrangement can be nightmarish.
There are at least three network devices involved and it took me several readings through the `if_bridge` man page to even *begin* to understand how the firewall interacts with it all.
In the end, I broke down to experimentation and fiddling with `sysctl` to make something I could handle.
My final solution was to disable all the `net.link.bridge.pfil_*` sysctl's, place the host's addresses on the `if_bridge` interface, and let the owner of a given interface (`if_bridge` for the host, `if_epair` for the jails) control the associated firewall rules.

### Netgraph

An alternative networking approach under VNET is to use [`netgraph(4)`](https://www.freebsd.org/cgi/man.cgi?query=netgraph&sektion=4).
Netgraph is a rather old subsystem within FreeBSD that doesn't get much press but it is specifically designed for these types of software-defined networking applications.
Unlike the previous approach, where we slotted network devices together like legos, netgraph takes a graph-oriented approach to packet handling.

Under netgraph, we have *nodes*, which are the entities that process packets, such as ethernet cards and switches.
And each *node* has one or more *hooks*, which serve as the I/O ports to exchange packets between nodes.
In our case, we're interested in three specific node types: [`ng_ether(4)`](https://www.freebsd.org/cgi/man.cgi?query=ng_ether&sektion=4), which allows us to interface with physical ethernet devices; [`ng_eiface(4)`](https://www.freebsd.org/cgi/man.cgi?query=ng_eiface&sektion=4), which creates a synthetic ethernet device; and [`ng_bridge(4)`](https://www.freebsd.org/cgi/man.cgi?query=ng_bridge&sektion=4), which lets us link two or more ethernet devices together in a switched network.

Of these, `ng_eiface` and `ng_bridge` are the most straightforward.
When creating an instance of `ng_eiface`, the kernel assigns it the first available index and creates a new synthetic device named `ngeth<num>`.
It has a single hook, named `ether`, which allows it to deliver and receive packets from the kernel's protocol stack.
Similarly, an instance of `ng_bridge` can have any number of hooks, all named `link<num>`, which connect any number of devices together.

By comparison, `ng_ether` is a bit more complicated.
Under normal operation, a packet received by the hardware is delivered to the kernel's protocol stack and packets generated by the kernel are transmitted out the port.
Netgraph allows us to insert ourselves into the middle of that process.
To accomplish this, `ng_ether` has *three* hooks, two of which are relevant to us: `lower` and `upper`.
`lower` corresponds to the ethernet hardware itself: if we send a packet into `lower`, it will be transmitted out on the wire and if a packet is received from the wire, it will come out of `lower`.
`upper`, on the other hand, corresponds to the kernel's protocol stack: when the kernel wants to send a packet, it will send it out `upper` and if we inject a packet into `upper`, it will be as if the networking stack received it from the wire.
By default, `upper` is joined with `lower`, allowing the network device to operate normally; however, we can place an `ng_bridge` between the two ports and now we switch traffic between a physical segment, the kernel, and our jails (or virtual machines).

Unfortunately, the base system doesn't provide any boot scripts to configure this for us, so we're on our own.

```sh
#!/bin/sh
# /usr/local/etc/rc.d/netgraph
#
# REQUIRE: FILESYSTEM kld
# PROVIDE: netgraph
# BEFORE: netif

netgraph_start() {
  # Ensure the kernel modules are loaded
  kld_load ng_bridge ng_eiface ng_ether
  # Destroy any lingering pieces
  ngctl shutdown bridge0:
  ngctl shutdown bridge1:
  # Create the graph
  ngctl -f- <<EOF
    # Create the bridge by extending from the hardware device.
    mkpeer igb0: ng_bridge lower link0
    # Bridges don't have a name by default, so assign it one.
    name igb0:lower bridge0
    # With our bridge now named, we can finish connecting the hardware device.
    connect igb0: bridge0: upper link1
    # Create three synthetic devices and connect them to the bridge.
    mkpeer bridge0: ng_eiface link2 ether
    mkpeer bridge0: ng_eiface link3 ether
    mkpeer bridge0: ng_eiface link4 ether

    # For a virtual network, we can use ngctl's control socket as an anchor. 
    mkpeer . ng_bridge virt link0
    name virt bridge1
    # Gaps in the hook sequence are acceptable (e.g. no link0 or link1).
    mkpeer bridge1: ng_eiface link2 ether
    mkpeer bridge1: ng_eiface link3 ether
    mkpeer bridge1: ng_eiface link4 ether
EOF
}

netgraph_stop() {
  # All the instances of eiface will vanish once the bridge is gone
  ngctl shutdown bridge0:
  ngctl shutdown bridge1:
}
```

```sh
# jail.conf
www {
  vnet;
  vnet.interface += "ngeth0";
  vnet.interface += "ngeth3";
}
```

One of the limitations of `ng_eiface` is that it simply assigns devices sequentially.
This makes it exceptionally difficult to manage multiple virtual networks, especially if interfaces are being created during operation.
To address this, we can use the `name` command from `ifconfig`.

```sh
ifconfig ngeth0 name phys0
ifconfig ngeth1 name phys1
ifconfig ngeth2 name phys2

ifconfig ngeth3 name virt0
ifconfig ngeth4 name virt1
ifconfig ngeth5 name virt2
```

Now, we can use friendly names in our configuration.
Of course, if we're building up our network graph dynamically, it doesn't address how one selects the newly created interface.
For that, we need only to ask it.

```plain
> ngctl msg bridge1:link2 getifname
Rec'd response "getifname" (1) from "[1a9]:":
Args:   "ngeth3"
```

Since ngctl wraps an annoying level of markup around the answer with no way to minimize it, we can use [`expr(1)`](https://www.freebsd.org/cgi/man.cgi?query=expr&sektion=1) to select out the part we want:

```sh
iface=$(expr "$(ngctl msg bridge1:link2 getifname)" : '.*Args:.*"\([a-zA-Z]*[0-9]*\)"')
ifconfig "${iface}" name virt0
```

### Interactions with if_lagg

On a server with multiple interfaces, it makes sense to aggregate devices for reliability and performance.
Under FreeBSD, this is accomplished with the [`if_lagg(4)`](https://www.freebsd.org/cgi/man.cgi?query=if_lagg&sektion=4) device.

```sh
# rc.conf
cloned_interfaces="lagg0"
ifconfig_lagg0="laggport igb0 laggport igb1 1.2.3.4/24 up"
ifconfig_igb0="up"
ifconfig_igb1="up"
```

Unfortunately, there is a complication when using the `failover` operating mode.
By default, the `lagg` device will discard packets that come in from the "wrong" interface and netgraph runs afoul of this logic when delivering packets from the switch.
This behavior can be suppressed using the `net.link.lagg.failover_rx_all` sysctl but I never managed to have it do anything other than lock up the network device.
This means that under `failover`, the host can't use the `lagg` device for its own traffic or it won't be able to communicate with any devices bridged into that device.

On my own system, I use a dedicated `lagg` device for the host and a second `lagg` device for the virtual devices.
While it means that traffic between the public interfaces of the host and virtual machines goes through a physical switch, it is ultimately a minor problem.
By having a dedicated networking device, the host's ethernet traffic takes advantage of the hardware TCP and checksum acceleration.
