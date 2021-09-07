---
date: 2020-12-27T20:15:00-08:00
title: FreeBSD Jail Startup Sequence
slug: freebsd-jail-startup
tags:
  - containers
  - FreeBSD
  - jails
  - sysadmin
---

On my home server, I use [FreeBSD](https://www.freebsd.org/).
While FreeBSD beat Linux to the containers by nearly a decade (comparing jails to cgroups), I have to acknowledge that cgroups are the superior design.
Whereas jails are a bunch of hacks piled on top of chroot, cgroups are a much cleaner abstraction of the kernel's namespaces.
But even beyond the elegance of the design, software like [Docker](https://www.docker.com/) makes it much easier to run your tools in containers, even if the offloading of sysadmin responsibilities it encourages triggers my OCD.

One of the things Docker does differently than most people's usage of jails (at least from my limited understanding) is that a docker instance is [ephemeral](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/).
The last time I touched [iocage](https://iocage.io/) (years ago, granted), it was still focused on modeling jails like [pets, not cattle](http://cloudscaling.com/blog/cloud-computing/the-history-of-pets-vs-cattle/).
So I wanted my jails to go through the closest analog I could to Docker without porting over a massive ecosystem.
That means if I'm going to write my own scripts, I need to understand how the FreeBSD jail system is put together.

> **Note:** Jail functionality has improved *a lot* in the past two years.
> I had started this essay with a lot of frustration over things I had to work around only to find things much improved during my research.

<!--more-->

## Jail Startup Sequence

While jails are a kernel feature, most of the magic is actually implemented by the [`jail(8)`](https://www.freebsd.org/cgi/man.cgi?query=jail&sektion=8) command.
Unfortunately, the documentation follows a pattern common in software documentation: they describe things in regards to how the software represents it, not what it *actually means*.

The actual core of creating a new jail comes from the [`jail_set(2)`](https://www.freebsd.org/cgi/man.cgi?query=jail_set&sektion=2) syscall (which, as expected, can also modify an existing jail).
But this merely constructs a new kernel namespace.
It doesn't mount any file systems, manipulate network devices, or run any programs.
All of that is handled by the previously mentioned [`jail(8)`](https://www.freebsd.org/cgi/man.cgi?query=jail&sektion=8).

Thankfully, the [source code for `jail`](https://github.com/freebsd/freebsd/tree/stable/12/usr.sbin/jail) spells it out as a handy, easy-to-follow [set of instructions](https://github.com/freebsd/freebsd/blob/stable/12/usr.sbin/jail/jail.c#L88):

1. Execute the `exec.prepare` script. (New in FreeBSD 12.2)
   - This is where you could clone off a new filesystem, for example.
2. Create network aliases.
   1. Create the IPv4 aliases listed in `ip4.addr`.
   2. Create the IPv6 aliases listed in `ip6.addr`.
   -  **Note:** `jail(8)` simply shells out to `/sbin/ifconfig`.
3. Mount File Systems.
   1. Mount the file systems listed in `mount`.
   2. Mount the file systems listed in `mount.fstab`.
   3. Mount `/dev` (if enabled by `mount.devfs`).
   4. Mount `/dev/fd` (if enabled by `mount.fdescfs`).
   5. Mount `/proc` (if enabled by `mount.procfs`).
   - **Note:** `jail(8)` simply shells out to `/sbin/mount`.
4. Execute the `exec.prestart` scripts.
   - This is where people would traditionally create their bridged interfaces, copy files into the filesystem, and other *last chance* actions.
     Some of these actions are better relegated to `exec.created` or `exec.prepare` now that those options exist.
5. Create the jail (actual call to [`jail_set(2)`](https://www.freebsd.org/cgi/man.cgi?query=jail_set&sektion=2)).
6. Execute the `exec.created` scripts.  (New in FreeBSD 12.0)
   - This is where you could delegate ZFS datasets using `zfs jail`, for example.
7. Jail the interfaces listed in `vnet.interface`
   - **Note:** `jail(8)` simply shells out to `/sbin/ifconfig ${intf} vnet ${jid}`
8. Execute the `exec.start` scripts *inside the jail*
   - Most people will execute `/bin/sh /etc/rc`
9. Execute the `command` command line *inside the jail*
10. Execute the `exec.poststart` scripts.
    - This is where I normally update my firewall rules.

The obvious question is what happens when when one of these steps fails?
Well, the sequence just rolls up in reverse to undo the actions which have already occurred.
Unfortunately, it simply skips over the script execution.
If your `exec.prepare` or `exec.prestart` script allocate some expensive resources and `exec.start` fails due to some silly transient issue, you're not going to have a chance to clean it up, so make sure you squash any exit codes after that point.

## Jail Shutdown Sequence

Just like the startup sequence, the shutdown sequence is a handy [table of instructions](https://github.com/freebsd/freebsd/blob/stable/12/usr.sbin/jail/jail.c#L112), which largely just goes in reverse order of the creation steps:

1. Execute the `exec.prestop` scripts.
   - This is normally where I remove my firewall additions.
2. Execute the `exec.stop` scripts *inside the jail*
   - Most people will execute `/bin/sh /etc/rc.shutdown jail`.
3. Send `SIGTERM` to all processes still running inside the jail and wait up to `stop.timeout` seconds.
4. Destroy the jail (actual call to [`jail_remove(2)`](https://www.freebsd.org/cgi/man.cgi?query=jail_remove&sektion=2)).
   - If you notice, it never reverses `vnet.interface` before this point.
     The kernel will simply release the interfaces back to the base system...once all the TCP timed waits are over.
5. Execute the `exec.poststop` scripts.
   - This is where you could copy data out of the filesystem, for example.
6. Unmount File Systems.
   1. Unmount `/proc` (if enabled by `mount.procfs`).
   2. Unmount `/dev/fs` (if enabled by `mount.fdescfs`).
   3. Unmount `/dev` (if enabled by `mount.devfs`).
   4. Unmount the file systems listed in `mount.fstab`.
   5. Unmount the file systems listed in `mount`.
7. Delete network alises.
   1. Remove the IPv6 aliases listed in `ip6.addr`.
   2. Remove the IPv4 aliases listed in `ip4.addr`.
8. Execute the `exec.release` scripts.
   - This is where you could destroy the file system you created at the very beginning.

What happens when one of these steps fails?
According to the documentation, <q cite="https://www.freebsd.org/cgi/man.cgi?query=jail&sektion=8">all commands must succeed...or the jail will not be created or removed</q>.
But unlike jail creation, you can't simply *undo* a teardown action.

As far as `jail(8)` is concerned, everything up to destroying the jail (step 4) doesn't matter.
Should your `exec.prestop` or `exec.stop` scripts fail, `jail(8)` will simply leave the jail in that zombie state.
After the jail is destroyed, it will simply run through the rest of the script, reporting but otherwise ignoring any failures that occur.

It's important to realize that all of these tasks are being done by `jail(8)`, not the kernel.
This means that `jail(8)` has only the contents of `/etc/jail.conf` to go on.
If you've modified your configuration after starting the jail, it's going to use the *new* configuration to shut down the previously constructed jail.
That means file systems left mounted and IP aliases left in place.

## What Comes Next?

My goal was to move closer to the goal of system as cattle.
Of course, with a single machine sitting in my cabinet, it's always going to be a bit of a special snowflake, but I can try to get my containers to function as commodities.

Right now, I maintain a number of *templates* that get cloned into an ephemeral dataset prior to starting up.
ZFS makes this an extremely cheap operation.
These templates are constructed by makefiles as a sort of jerry-rigged Dockerfile, but I can blow them away and recreated them even while the jail is still running.
But as it stands, there is a lot of jail-specific state buried in the configuration: IP addresses, hostnames, network interface names, etc.
There is still a one-to-one correspondence between a configuration and an instance.
I can't load up multiple instances of a container (e.g. seamless upgrades and testing) or simply roll out one-offs for experiments, let alone migrate them between machines.

Things I've been putting off:
- Move away from [`if_bridge(4)`](https://www.freebsd.org/cgi/man.cgi?query=if_bridge&sektion=4) + [`if_epair(4)`](https://www.freebsd.org/cgi/man.cgi?query=if_epair&sektion=4) to something like [`netgraph(4)`](https://www.freebsd.org/cgi/man.cgi?query=netgraph&sektion=4) or [`netmap(4)`](https://www.freebsd.org/cgi/man.cgi?query=netmap&sektion=4).
  The first two are not scalable and make an absolute mess of the network configuration while the later two are specifically designed for large software-defined networks.
  Even `bhyve(8)` will be able to interface directly with `netgraph(4)` in [FreeBSD 13.0](https://www.freebsd.org/cgi/man.cgi?query=bhyve&sektion=8&manpath=FreeBSD+13.0-current).
- *Automatic allocation of network devices, addresses, and other configuration.*
  While much of it can be handled using existing techniques like DHCP, we need to find the network applications *somehow*.
  This means the jail needs to either communicate its address allotment to the host (for setting up redirects and DNS entries) or use an IP sharing protocol like [`carp(4)`](https://www.freebsd.org/cgi/man.cgi?query=carp&sektion=4).
- *Cloning a template into a unique dataset when launching a new instance.*
  Right now, `templates/nginx` gets cloned into `jail/nginx` prior to execution.
  It should get cloned into `jail/f85ff265-48b9-11eb-9aa9-0cc47a32cf0c` or some other randomly-generated series of characters.
  I should be able to quickly spin off variants of templates so if I need an instance of nginx for testing, it's not going to pull in all my mount points, configuration files, and TLS certificates from the "production" server.

In retrospect, I should probably learn something like Kubernetes or Docker, but my eyes always glaze over when I get tarred up by the business speak.
I'm an engineer who spends his day designing circuits and firmware, not a sysadmin managing thousand-node clusters.
