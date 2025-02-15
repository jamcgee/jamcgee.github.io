---
date: 2025-02-14T22:55:00-0800
title: "Ethernet: Media Independent Interface (MII)"
series: Ethernet
slug: ethernet-mii
tags:
  - embedded
  - ethernet
  - hardware
  - network
---

With Fast Ethernet, Ethernet introduced something new.
Previously, the <abbr>Physical Signaling</abbr> layer was integrated into the <abbr title="Media Access Controller">MAC</abbr> and connected to the actual media through a <abbr>Media Attachment Unit</abbr>.
While the user could switch between twisted pair (10Base-T), thinnet (10Base2), thicknet (10Base5), or even fiber (10Base-F) simply by changing <abbr>MAU</abbr>s, switching to a different encoding (e.g. Fast Ethernet) would require a completely new interface.

Instead of requiring new networking equipment to manage the <abbr title="Physical Coding Sublayer">PCS</abbr> of each individual protocol, the <abbr>MAC</abbr> communicates with the PHY with a Media Independent Interface (<abbr>MII</abbr>).
Now, free of protocol-specific encodings, different line rates and protocols could be selected by simply switching between different PHYs, leaving the <abbr>MAC</abbr> unaffected.
While interchangeable PHYs is now the domain of high-end networking (e.g. <abbr title="Small Formfactor Pluggable">SFP</abbr> modules), the <abbr>MII</abbr> interface and its derivatives are the primary mechanism for connecting integrated <abbr>MAC</abbr>s (and <abbr title="Field Programmable Gate Array">FPGA</abbr>s) to commodity Ethernet transceivers.

The expression <em>Media Independent Interface</em> can be a little vague.
It can either describe the specific interface defined in Clause 22, used for 10 megabit and 100 megabit Ethernet, or serve as a category of all such interfaces.
In the later case, 802.3 will abbreviate it as <abbr>xMII</abbr>.
For this chapter, <abbr>MII</abbr> will refer to the specific interface from Clause 22.

<!--more-->

When originally proposed, <abbr>MII</abbr> was to facilitate the construction of PHYs as a Line Replaceable Unit (<abbr>LRU</abbr>).
As such, a standardized connector is included in 802.3, covered by Clauses 22.4 (Electrical), 22.5 (Power Supply), and 22.6 (Connector).
It is unlikely anyone will make use of this connector.
Instead, most modern usages of <abbr>MII</abbr> will be chip-to-chip over a single <abbr title="Printed Circuit Board">PCB</abbr>.

> **Note:** The most recent version of the 802 standards are available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68) at no cost.
> It is highly advised that anyone working with Ethernet download a copy of 802.3 (Wired Ethernet).

## Signaling (Clause 22.2)

<abbr title="Media Independent Interface">MII</abbr> is defined by sixteen individual signals.
Each direction (transmit and receive) has seven signals: a PHY-provided clock (`RX_CLK`/`TX_CLK`), a valid/enable signal (`RX_DV`/`TX_EN`), an error signal (`RX_ER`/`TX_ER`), and a four-bit data bus (`RXD`/`TXD`).
The last two signals, *Carrier Sense* (`CRS`) and *Collision Detected* (`COL`), are used for half-duplex operation.

<figure>
<svg viewBox="-5 -15 310 230" style="display:block;margin:auto;max-width:400px;">
  <title>MII Signals</title>
  <symbol id="arrow" y="-5">
    <line stroke="black" x1="5" y1="5" x2="100" y2="5"/>
    <polyline fill="black" stroke="none" points="5,2.5 5,7.5 0,5"/>
  </symbol>
  <!-- Top Level Blocks-->
  <g fill="none" stroke="black">
    <rect x="0" y="5" width="100" height="205"/>
    <rect x="200" y="5" width="100" height="205"/>
    <line x1="0" x2="100" y1="90" y2="90"/>
    <line x1="200" x2="300" y1="90" y2="90"/>
    <line x1="0" x2="100" y1="170" y2="170"/>
    <line x1="200" x2="300" y1="170" y2="170"/>
  </g>
  <g font-size="15" text-anchor="middle">
    <text x="50">MAC</text>
    <text x="250">PHY</text>
  </g>
  <g dominant-baseline="middle" font-size="15" text-anchor="middle">
    <text x="50" y="50">RX</text>
    <text x="50" y="130">TX</text>
    <text x="50" y="190">CSMA/CD</text>
    <text x="250" y="50">RX</text>
    <text x="250" y="130">TX</text>
    <text x="250" y="190">CSMA/CD</text>
  </g>
  <!-- Buses -->
  <g font-size="12">
    <!-- Receive Bus -->
    <use href="#arrow" x="100" y="20"/>
    <text x="110" y="15">RX_CLK</text>
    <use href="#arrow" x="100" y="40"/>
    <text x="110" y="35">RX_DV</text>
    <use href="#arrow" x="100" y="60"/>
    <text x="110" y="55">RX_ER</text>
    <use href="#arrow" x="100" y="80"/>
    <text x="110" y="75">RXD[3:0]</text>
    <!-- Transmit Bus -->
    <use href="#arrow" x="100" y="100"/>
    <text x="110" y="95">TX_CLK</text>
    <use href="#arrow" x="-200" y="-120" transform="rotate(180)"/>
    <text x="110" y="115">TX_EN</text>
    <use href="#arrow" x="-200" y="-140" transform="rotate(180)"/>
    <text x="110" y="135">TX_ER</text>
    <use href="#arrow" x="-200" y="-160" transform="rotate(180)"/>
    <text x="110" y="155">TXD[3:0]</text>
    <!-- Asynchronous -->
    <use href="#arrow" x="100" y="180"/>
    <text x="110" y="175">CRS</text>
    <use href="#arrow" x="100" y="200"/>
    <text x="110" y="195">COL</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr title="Media Independent Interface">MII</abbr> Signals</figcaption>
</figure>

The transmit and receive paths are largely symmetric.
`RX_DV`/`TX_EN` indicate when the medium is transmitting a packet and `RX_ER`/`TX_ER` indicate the presence of a special condition.
Together, the combination of the valid/enable and error signals control the interpretation of the data bus:

`EN` | `ER` | Meaning        | `RXD`/`TXD`
:---:|:----:|:---------------|:-------------
`0`  | `0`  | Bus Idle       | (Do Not Care)
`0`  | `1`  | Control Word   | Control Word
`1`  | `0`  | Transmit Data  | Data Byte
`1`  | `1`  | Transmit Error | (Do Not Care)
{style="margin:auto;"}

Under normal operation, `RX_ER`/`TX_ER` is held low.
Raising `RX_DV`/`TX_EN` is done to indicate when a packet is being sent (including during the preamble and <abbr title="Start Frame Delimiter">SFD</abbr>).

<figure>
<svg viewBox="0 0 400 120" style="display:block;margin:auto;max-width:500px;">
  <title>Packet Structure</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="0" y="15">RX_CLK</text>
    <text x="0" y="45">RX_DV</text>
    <text x="0" y="75">RXD[3:0]</text>
    <text x="0" y="105">RX_ER</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,24 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10"/>
    <path d="M70,54 h40 v-20 h240 v20 h40"/>
    <path d="M70,114 h320"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M110,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M130,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M150,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
    <path d="M190,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M210,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M230,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M250,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M270,74 l5,-10 h70 l5,10 l-5,10 h-70 l-5,-10"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M70,64 h35 l5,10 l-5,10 h-35"/>
    <path d="M390,84 h-35 l-5,-10 l5,-10 h35"/>
  </g>
  <!-- Values -->
  <g dominant-baseline="middle" font-size="12" text-anchor="middle">
    <text x="90" y="75">X</text>
    <!-- Preamble -->
    <text x="120" y="75">5</text>
    <text x="140" y="75">5</text>
    <text x="170" y="75">...</text>
    <text x="200" y="75">5</text>
    <text x="220" y="75">5</text>
    <!-- SFD -->
    <text x="240" y="75">5</text>
    <text x="260" y="75">D</text>
    <!-- Payload -->
    <text x="310" y="75">...</text>
    <text x="370" y="75">X</text>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="110" y1="5" x2="110" y2="120"/>
    <line x1="230" y1="5" x2="230" y2="120"/>
    <line x1="270" y1="5" x2="270" y2="120"/>
    <line x1="350" y1="5" x2="350" y2="120"/>
  </g>
  <!-- Captions -->
  <g dominant-baseline="middle" font-size="12" text-anchor="middle">
    <text x="170" y="95">Preamble</text>
    <text x="250" y="95">SFD</text>
    <text x="310" y="95">Frame</text>
  </g>
</svg>
<figcaption style="text-align:center">Packet Structure</figcaption>
</figure>

As discussed previously, Ethernet is *primarily* a little endian protocol.
Each data byte is sent least significant nibble first with the most significant bit stored in position three and the least significant bit stored in position zero.
For example, the [example packet from the introduction]({{<ref "2024-10-08-ethernet-intro#ethernet-packets-and-frames-clause-3">}}) (ends with <abbr title="Frame Check Sequence">FCS</abbr> `69 70 39 BB`) would be sent:

SIGNAL    |   | 1 | 2 |...| 13| 14| 15| 16|...|141|142|143|144|
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`TX_EN`   |`0`|`1`|`1`|...|`1`|`1`|`1`|`1`|...|`1`|`1`|`1`|`1`|`0`
`TXD[3:0]`|`X`|`5`|`5`|...|`5`|`5`|`5`|`D`|...|`9`|`3`|`B`|`B`|`X`
`TXD[3]`  |`X`|`0`|`0`|...|`0`|`0`|`0`|`1`|...|`1`|`0`|`1`|`1`|`X`
`TXD[2]`  |`X`|`1`|`1`|...|`1`|`1`|`1`|`1`|...|`0`|`0`|`0`|`0`|`X`
`TXD[1]`  |`X`|`0`|`0`|...|`0`|`0`|`0`|`0`|...|`0`|`1`|`1`|`1`|`X`
`TXD[0]`  |`X`|`1`|`1`|...|`1`|`1`|`1`|`1`|...|`1`|`1`|`1`|`1`|`X`
{style="font-size:80%;margin:auto"}

Sent in this order, it is possible to compute the <abbr title="Cyclic Redundancy Check">CRC</abbr> nibble-at-a-time without any buffering.

Even though the standard preamble is 7 bytes of `0x55` followed by the <abbr>SFD</abbr>, there is no guarantee you will receive this on <abbr>MII</abbr>.
The preamble may be truncated, missing entirely, or possibly a non-integer number of bytes.
It is advised that the <abbr>MAC</abbr> accept any number of `0x5` (`0101`) prior to the appearance of the <abbr>SFD</abbr>, `0xD` (`1101`), which establishes the actual byte alignment.

As the interface is nibble-based, it is possible to encode frames with a non-integer number of bytes.
Transmitting a trailing half-byte is implementation-defined and the PHY is not required to handle it in any specific manner (Clause 22.2.3.5).
On reception, a trailing half-byte is to be truncated and the resulting frame reported as an alignment error if it fails the <abbr>FCS</abbr> (Clause 4.2.4.2.1).

In half-duplex operation, it is implementation-defined whether transmit data is looped back into the receive bus unless explicitly enabled through the management interface.
For full-duplex operation, this is expressly forbidden unless loopback mode is enabled.

The remaining signals, `CRS` and `COL`, are used in half-duplex operation.
They are *undefined* in full-duplex operation and must be ignored by the reconciliation layer.
Many PHYs will signal them identically in both modes.

## Clocking (Clause 22.3)

Both clocks are sourced from the PHY and run at 25% of the target bitrate (e.g. 2.5&nbsp;MHz / 400&nbsp;ns for 10Base-T, 25&nbsp;MHz / 40&nbsp;ns for 100Base-T) with a duty cycle between 35% and 65%.
The transmit clock (`TX_CLK`) is always sourced from the local reference oscillator and should have an accuracy of 100&nbsp;<abbr title="Parts Per Million">ppm</abbr>.
The <abbr title="Media Access Controller">MAC</abbr> is expected to drive the transmit signals on the rising edge of `TX_CLK`.
Clause 22.3.1 specifies a transition window of 0&nbsp;ns (min) to 25&nbsp;ns (max) from the rising edge.

<figure>
<svg viewBox="20 -5 280 160" style="display:block;margin:auto;max-width:500px;">
  <title>Transmit Signal Timing</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="25" y="25">TX_CLK</text>
    <text x="25" y="105">TXD[3:0]</text>
    <text x="25" y="125">TX_EN</text>
    <text x="25" y="145">TX_ER</text>
  </g>
  <!-- Waveforms -->
  <polyline fill="none" stroke="black"
    points="105,50 135,50 145,0 175,0 185,50 215,50 225,0 255,0 265,50 295,50"/>
  <g fill="#8F88" stroke="#4F4">
    <polyline points="105,100 135,100 140,125 135,150 105,150"/>
    <polyline points="190,125 195,100 215,100 220,125 215,150 195,150 190,125"/>
    <polyline points="295,100 275,100 270,125 275,150 295,150"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <polyline points="140,125 145,100 185,100 190,125 185,150 145,150 140,125"/>
    <polyline points="220,125 225,100 265,100 270,125 265,150 225,150 220,125"/>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="140" y1="5" x2="140" y2="150"/>
    <line x1="190" y1="65" x2="190" y2="150"/>
    <line x1="220" y1="5" x2="220" y2="150"/>
  </g>
  <!-- Spans -->
  <line stroke="black" x1="140" y1="77.5" x2="185" y2="77.5"/>
  <polyline points="185,80 185,75 190,77.5" class="solid"/>  
  <!-- Dimensions -->
  <text x="142.5" y="75" font-size="12">25&nbsp;ns</text>
  <!-- Validity -->
  <g dominant-baseline="middle" text-anchor="middle" font-size="8">
    <text x="165" y="125" class="caption">INVALID</text>
    <text x="205" y="125" class="caption">VALID</text>
    <text x="245" y="125" class="caption">INVALID</text>
  </g>
</svg>
<figcaption style="text-align:center">Transmit Signal Timing</figcaption>
</figure>

An example <abbr title="Synopsys Design Constraint">SDC</abbr> would be:

```tcl
create_clock -name TX_CLK -period 40 [get_ports TX_CLK]
set_output_delay -clock TX_CLK -min 0 [get_ports {TX_EN TX_ER TXD[*]}]
set_output_delay -clock TX_CLK -max 25 [get_ports {TX_EN TX_ER TXD[*]}]
```

The receive clock (`RX_CLK`), on the other hand, may be sourced from the local oscillator or the recovered clock from the peer and may be suppressed under Low Power Idle (<abbr>LPI</abbr>).
Due to this, it may shift in frequency, phase, or disappear entirely based upon the link state.
The <abbr>MAC</abbr> is expected to capture the signals on the rising edge of `RX_CLK`.
Clause 22.3.2 specifies setup and hold times of 10&nbsp;ns from the rising edge.

<figure>
<svg viewBox="20 -5 280 160" style="display:block;margin:auto;max-width:500px;">
  <title>Receive Signal Timing</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="25" y="25">RX_CLK</text>
    <text x="25" y="105">RXD[3:0]</text>
    <text x="25" y="125">RX_DV</text>
    <text x="25" y="145">RX_ER</text>
  </g>
  <!-- Waveforms -->
  <polyline fill="none" stroke="black"
    points="105,50 135,50 145,0 175,0 185,50 215,50 225,0 255,0 265,50 295,50"/>
  <g fill="#8F88" stroke="#4F4">
    <polyline points="120,125 125,100 155,100 160,125 155,150 125,150 120,125"/>
    <polyline points="200,125 205,100 235,100 240,125 235,150 205,150 200,125"/>
    <polyline points="295,100 285,100 280,125 285,150 295,150"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <polyline points="105,100 115,100 120,125 115,150 105,150"/>
    <polyline points="160,125 165,100 195,100 200,125 195,150 165,150 160,125"/>
    <polyline points="240,125 245,100 275,100 280,125 275,150 245,150 240,125"/>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="120" y1="65" x2="120" y2="150"/>
    <line x1="140" y1="5" x2="140" y2="110"/>
    <line x1="160" y1="65" x2="160" y2="150"/>
  </g>
  <!-- Spans -->
  <g stroke="black">
    <line x1="140" y1="77.5" x2="155" y2="77.5"/>
    <line x1="140" y1="87.5" x2="125" y2="87.5"/>
  </g>
  <g fill="black" stroke="none">
    <polyline points="155,80 155,75 160,77.5"/>
    <polyline points="125,90 125,85 120,87.5"/>
  </g>
  <!-- Dimensions -->
  <g dominant-baseline="middle" font-size="12">
    <text x="162.5" y="77.5" text-anchor="start">10&nbsp;ns</text>
    <text x="117.5" y="87.5" text-anchor="end">10&nbsp;ns</text>
  </g>
  <!-- Validity -->
  <g dominant-baseline="middle" text-anchor="middle" font-size="8">
    <text x="140" y="125" class="caption">VALID</text>
    <text x="180" y="125" class="caption">INVALID</text>
    <text x="220" y="125" class="caption">VALID</text>
    <text x="260" y="125" class="caption">INVALID</text>
  </g>
</svg>
<figcaption style="text-align:center">Receive Signal Timing</figcaption>
</figure>

An example <abbr title="Synopsys Design Constraint">SDC</abbr> would be:

```tcl
create_clock -name RX_CLK -period 40 [get_ports RX_CLK]
set_input_delay -clock RX_CLK -min 10 [get_ports {RX_DV RX_ER RXD[*]}]
set_input_delay -clock RX_CLK -max 30 [get_ports {RX_DV RX_ER RXD[*]}]
```

Strictly speaking, the signals should be length matched to their respective clock; however, it would take a mismatch on the better part of a meter to introduce an issue at the frequencies used here.
Ultimately, one should consult the datasheet of the PHY they are using.
It is possible, although highly unlikely, the PHY will have stricter requirements.

The remaining two signals, `COL` and `CRS`, are asynchronous to both clocks so users will need to explicitly synchronize them (generally to the transmit clock).

## Data Errors (Clause 22.2.2.5, 22.2.2.10)

Encoding errors can be indicated by the use of `RX_ER` or `TX_ER`.
When asserted during a packet (`RX_DV`/`TX_EN` are high), this indicates that an issue with that specific byte position.
For example, on reception, the PHY detected a coding error and indicates the byte is invalid.
Alternatively, on transmission, the MAC suffered a buffer underflow and needs to spoil the packet to ensure its peer will not mistakenly interpret it as a valid packet.
The specific value of the data bus is undefined during a data error.

<figure>
<svg viewBox="0 0 400 120" style="display:block;margin:auto;max-width:500px;">
  <title>Example Packet Error</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="0" y="15">RX_CLK</text>
    <text x="0" y="45">RX_DV</text>
    <text x="0" y="75">RXD[3:0]</text>
    <text x="0" y="105">RX_ER</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,24 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10 v20 h10 v-20 h10"/>
    <path d="M70,54 h40 v-20 h240 v20 h40"/>
    <path d="M70,114 h180 v-20 h20 v20 h120"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M110,74 l5,-10 h130 l5,10 l-5,10 h-130 l-5,-10"/>
    <path d="M270,74 l5,-10 h70 l5,10 l-5,10 h-70 l-5,-10"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M70,64 h35 l5,10 l-5,10 h-35"/>
    <path d="M250,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M390,84 h-35 l-5,-10 l5,-10 h35"/>
  </g>
  <g dominant-baseline="middle" text-anchor="middle" font-size="12">
    <text x="90" y="75">X</text>
    <text x="180" y="75">...</text>
    <text x="260" y="75">X</text>
    <text x="310" y="75">...</text>
    <text x="370" y="75">X</text>
  </g>
</svg>
<figcaption style="text-align:center">Example Packet Error</figcaption>
</figure>

**Note:** These signals are often absent on the <abbr title="Media Access Controller">MAC</abbr>s of low-end microcontrollers.
If not used, `RX_ER` is left floating and `TX_ER` is tied to ground.

## Special Conditions (Clause 22.2.2.4, 22.2.2.8)

Outside of a packet (`RX_DV`/`TX_EN` is low), the error signal (`RX_ER`/`TX_ER`) is used to indicate the presence of special conditions on the medium.
Most of these will be discussed in the following sections.

Value  | Transmit    | Receive
------:|:------------|:------------------
`0000` | Reserved    | Normal Interframe
`0001` | Assert <abbr title="Low Power Idle">LPI</abbr> | Assert <abbr>LPI</abbr>
`0010` | <abbr title="Physical Layer Collision Avoidance">PLCA</abbr> BEACON | <abbr>PLCA</abbr> BEACON
`0011` | <abbr>PLCA</abbr> COMMIT | <abbr>PLCA</abbr> COMMIT
`1110` | Reserved    | False Carrier
{style="margin:auto"}

False Carrier (`1110`) typically indicates a coding error on the part of the remote peer (Clause 24.2.4.4.2).
This can generally be ignored except for logging purposes but may indicate hardware malfunction.

## Link Configuration

The fundamental properties when configuring the interface, be it manually or through autonegotiation, are the following:

- *Link Speed*.
  As all clocks are provided by the PHY, it is rarely necessary for the <abbr title="Media Access Controller">MAC</abbr> to know which speed has been negotiated.
- *Link Duplex*.
  Half-duplex requires the implementation of <abbr title="Carrier Sense Multiple Access with Collision Detection">CSMA/CD</abbr> on the part of the <abbr>MAC</abbr>.
- *Energy Efficient Ethernet*.
  <abbr>EEE</abbr> will result in the potential generation of <abbr title="Low Power Idle">LPI</abbr> sequences by the peer, which may result in `RX_CLK` being halted.
  It also allows the local <abbr>MAC</abbr> to generate <abbr>LPI</abbr> sequences of its own to reduce power consumption.

These properties are not available in-band and need to be accessed through the management interface.

## Crossover

Crossover in this context refers to connecting two devices of the same class (PHY or <abbr title="Media Access Controller">MAC</abbr>) directly.
For example, connecting the TX of one <abbr>MAC</abbr> directly to the RX of a second <abbr>MAC</abbr> without an intervening PHY, or using a pair of PHYs as a media converter.

Unlike later <abbr>MII</abbr> variants, all clocks are provided by the PHY.
This means that PHY-to-PHY will have conflicting clocks while MAC-to-MAC will have no clock.
While external clocks can be provided in the later case, the setup and hold requirements would likely not be met in a naïve configuration.

Assuming one peer in this arrangement cannot be configured to switch interface direction through configuration, there are limited options.
PHY-to-PHY will require active logic to perform clock domain crossing, including an elastic buffer to address potential clock skew.
MAC-to-MAC can be connected directly, so long as an external clock is provided and opposite polarity is connected to the `TX_CLK` and `RX_CLK` inputs to mitigate differences in timing.

## Energy Efficient Ethernet (Clause 22.7, 78)

Under 100Base-TX and later, the transmitter runs continuously, even when no packet is being transmitted, consuming energy.
Energy Efficient Ethernet (<abbr>EEE</abbr>) is a mechanism by which the transmitter can be disabled during periods of extended inactivity, reducing power consumption.
To maintain the link, the peer will periodically enable its transmitter to send a refresh signal, normally handled automatically by the PHY.

First, <abbr>EEE</abbr> support needs to be negotiated with the peer.
On some PHYs, this is enabled by default.
On others, some form of configuration is required.
This is normally handled through the Clause 45 registers MMD3 and MMD7.

When the peer signals it is entering Low Power Idle (<abbr>LPI</abbr>), the local PHY will report this to the MAC by signalling *Assert LPI*, holding `RX_DV` low, `RX_ER` high, and `0001` on `RXD`.
Once the PHY has indicated this condition for at least nine clock cycles, it may halt `RX_CLK` until the peer leaves <abbr>LPI</abbr>.

When the local <abbr title="Media Access Controller">MAC</abbr> is idle, it may request the PHY enter <abbr>LPI</abbr> in a similar manner:
It pulls `TX_EN` low, `TX_ER` high, and loads `0001` onto `TXD`.
However, when it wishes to resume transmission, it cannot do so immediately upon releasing *Assert LPI*.
The peer needs time to synchronize its clock recovery and descrambler.
The minimum required time is specified in Clause 78 as <var>T<sub>w_sys_tx</sub></var>, which is provided for each PHY in Table 78-4.
For the PHYs covered by Clause 22 <abbr>MII</abbr>, these times are:

- For 10Base-T1L, this is 270&nbsp;&mu;s (675 clock cycles).
- For 100Base-TX, this is 30&nbsp;&mu;s (750 clock cycles).

<figure>
<svg viewBox="0 0 400 120" style="display:block;margin:auto;max-width:500px;">
  <title>LPI Transmit Timing</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="0" y="45">TX_EN</text>
    <text x="0" y="75">TXD[3:0]</text>
    <text x="0" y="105">TX_ER</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,54 h280 v-20 h40"/>
    <path d="M70,114 h40 v-20 h160 v20 h120"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M110,74 l5,-10 h150 l5,10 l-5,10 h-150 l-5,-10"/>
    <path d="M390,84 h-35 l-5,-10 l5,-10 h35"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M70,64 h35 l5,10 l-5,10 h-35"/>
    <path d="M270,74 l5,-10 h70 l5,10 l-5,10 h-70 l-5,-10"/>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="110" y1="5" x2="110" y2="120"/>
    <line x1="270" y1="5" x2="270" y2="120"/>
    <line x1="350" y1="5" x2="350" y2="120"/>
  </g>
  <!-- Spans -->
  <g stroke="black">
    <line x1="70" y1="20" x2="105" y2="20"/>
    <line x1="115" y1="20" x2="265" y2="20"/>
    <line x1="275" y1="20" x2="345" y2="20"/>
    <line x1="355" y1="20" x2="390" y2="20"/>
  </g>
  <g fill="black" stroke="none">
    <polyline points="105,17.5 105,22.5 110,20"/>
    <polyline points="115,17.5 115,22.5 110,20"/>
    <polyline points="265,17.5 265,22.5 270,20"/>
    <polyline points="275,17.5 275,22.5 270,20"/>
    <polyline points="345,17.5 345,22.5 350,20"/>
    <polyline points="355,17.5 355,22.5 350,20"/>
  </g>
  <!-- Labels -->
  <g font-size="12" text-anchor="middle">
    <text x="90" y="17.5">IDLE</text>
    <text x="190" y="17.5">LPI</text>
    <text x="310" y="17.5">WAKE</text>
    <text x="370" y="17.5">TX</text>
  </g>
  <!-- Content -->
  <g dominant-baseline="middle" text-anchor="middle" font-size="12">
    <text x="90" y="75">X</text>
    <text x="190" y="75">0001</text>
    <text x="310" y="75">X</text>
    <text x="370" y="75">...</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr title="Low Power Idle">LPI</abbr> Transmit Timing</figcaption>
</figure>

Failure to meet these timing requirements may result in data loss as the peer may not have been able to complete synchronization.

Many embedded <abbr>MAC</abbr>s do not provide `TX_ER`, let alone implement <abbr>LPI</abbr>.
As a result, many PHYs will allow software to manually enter <abbr>LPI</abbr> through a management action.

10Base-T does not transmit continuously so does not implement <abbr>LPI</abbr>.
Instead, <abbr>EEE</abbr> introduced 10Base-Te, which reduces the transmit amplitude but is otherwise identical.
As it can freely interop with traditional 10Base-T, it does not need to be negotiated and many PHYs will enable it by default.

> **Note:** I do not have personal experience with <abbr>EEE</abbr>.
> This section is simply a summarization of the standard.

## Half-Duplex (Clause 4.2.3.2, 22.2.2)

Half-duplex is largely extinct for desktop usage with most protocols dedicated to shared media having been expired.
It may still appear when autonegotiation is disabled or incorrectly configured.
Failure to properly implementing half-duplex under these conditions may lead to significant difficulty transmitting data across the link when one peer continuously falls back into collision recovery.

However, half-duplex is an essential component of 10Base-T1S (Clause 147).
This is a special-purpose Ethernet interface intended to replace <abbr title="Controller Area Network">CAN</abbr>, using a shared media and an optional scheduling scheme to provide a similar system of prioritization.
However, even when <abbr title="Physical Layer Collision Avoidance">PLCA</abbr> is in use, failure of node zero will result in the network reverting to classic half-duplex operation.

The two asynchronous signals, `CRS` and `COL`, are for the express purpose of managing half-duplex communication:

- `CRS`, *Carrier Sense*, will be asserted when the medium is non-idle (i.e. someone is transmitting, possibly ourselves).
  This is a distinct signal from `RX_DV` owing to latency within the PHY.
- `COL`, *Collision Detected*, will be asserted when the PHY detects a collision.
  This need not necessarily be a collision caused by our own device.

Medium access is described by Clause 4.2.3.2 and has three core phases:

1. Deference (Clause 4.2.3.2.1)
3. Collision Detection (Clause 4.2.3.2.4)
4. Backoff and Retransmission (Clause 4.2.3.2.5)

This algorithm is known as Carrier Sense Multiple Access with Collision Detection (<abbr>CSMA/CD</abbr>).

*Deference* means that transmission will not begin so long as the medium is active.
Instead, the <abbr title="Media Access Controller">MAC</abbr> will monitor the `CRS` signal.
While this signal is asserted, the <abbr>MAC</abbr> will defer its own transmission until `CRS` is deasserted plus an additional number of `TX_CLK` periods equal to the InterPacket Gap (<abbr>IPG</abbr>) of 96 bits (24 clock cycles).
Once this period has elapsed, and a packet is ready for transmission, the <abbr>MAC</abbr> will begin transmitting the packet *even if the carrier sense has been reasserted*.
This later requirement is to ensure fair access to the media.

Once the transmission has commenced, the <abbr>MAC</abbr> will monitor the `COL` signal for the duration of the transmission.
Should this signal be asserted, the PHY has detected a collision and the <abbr>MAC</abbr> must terminate the packet after transmitting an additional 32 bits (8 clock cycles) to ensure the collision is detected by all parties.
The content of this jam pattern is not important, so long as it does not (intentionally) hold the <abbr title="Field Check Sequence">FCS</abbr> for a valid packet.
A good recommendation is to emit an intentionally spoiled <abbr>FCS</abbr>.

Upon a collision, the <abbr>MAC</abbr> is permitted to make up to sixteen attempts to transmit the packet (including the first).
However, instead of transmitting the packet immediately, it will enter into a random delay.
The bounds of this delay expand exponentially with each retransmission attempt according to the formula:

<math display="block">
<mn>0</mn><mo>&le;</mo><mi>r</mi><mo>&lt;</mo>
<msup><mn>2</mn><mrow><mo>min</mo><mo>(</mo><mn>10</mn><mo>,</mo><mi>n</mi><mo>)</mo></mrow></msup>
</math>

Where <var>r</var> is the number of slot times and <var>n</var> is the retransmission attempt (presumably one-based but Clause 4.2.3.2.5 isn't clear).
As the upper bound is a power of two, this makes it straightforward to generate in hardware by simply masking off the appropriate number of bits from a random generator, such as a Linear Feedback Shift Register (<abbr>LFSR</abbr>) formed from the <abbr>FCS<abbr> generation logic.
The slotTime for 10 and 100 megabit is 512 bits (128 clocks).

<figure>
<svg viewBox="5 10 395 130" style="display:block;margin:auto;max-width:500px;">
  <title>Carrier Sense Multiple Access with Collision Detection</title>
  <!-- Axes -->
  <g dominant-baseline="middle" font-size="15">
    <text x="10" y="65">CRS</text>
    <text x="10" y="95">COL</text>
    <text x="10" y="125">TX_EN</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,54 h40 v20 h40 v-20 h120 v20 h120"/>
    <path d="M70,104 h150 v-20 h40 v20 h130"/>
    <path d="M70,134 h100 v-20 h80 v20 h80 v-20 h60"/>
  </g>
  <!-- Divisions -->
  <g stroke-dasharray="3,3" stroke="black">
    <line x1="110" x2="110" y1="40" y2="140"/>
    <line x1="170" x2="170" y1="20" y2="140"/>
    <line x1="220" x2="220" y1="40" y2="140"/>
    <line x1="250" x2="250" y1="20" y2="140"/>
    <line x1="330" x2="330" y1="20" y2="140"/>
  </g>
  <!-- Spans -->
  <g stroke="black">
    <line x1="70" y1="25" x2="165" y2="25"/>
    <line x1="115" y1="45" x2="165" y2="45"/>
    <line x1="175" y1="25" x2="245" y2="25"/>
    <line x1="225" y1="45" x2="245" y2="45"/>
    <line x1="255" y1="25" x2="325" y2="25"/>
    <line x1="335" y1="25" x2="390" y2="25"/>
  </g>
  <g fill="black">
    <polyline points="165,22.5 165,27.5 170,25"/>
    <polyline points="115,42.5 115,47.5 110,45"/>
    <polyline points="165,42.5 165,47.5 170,45"/>
    <polyline points="175,22.5 175,27.5 170,25"/>
    <polyline points="245,22.5 245,27.5 250,25"/>
    <polyline points="225,42.5 225,47.5 220,45"/>
    <polyline points="245,42.5 245,47.5 250,45"/>
    <polyline points="255,22.5 255,27.5 250,25"/>
    <polyline points="325,22.5 325,27.5 330,25"/>
    <polyline points="335,22.5 335,27.5 330,25"/>
  </g>
  <!-- Labels -->
  <g text-anchor="middle" font-size="12">
    <text x="120" y="20">Deference</text>
    <text x="210" y="20">Detection</text>
    <text x="290" y="20">Backoff</text>
    <text x="360" y="20">Retrans</text>
    <text x="140" y="40">IPG</text>
    <text x="235" y="40">Jam</text>
  </g>
</svg>
<figcaption style="text-align:center">Carrier Sense Multiple Access with Collision Detection</figcaption>
</figure>

Per Clause 4.2.3.2.2, there is a distinction between collisions that occur within the first slot time and those that come after.
*Late collisions* indicate a network configuration error (e.g. someone's not engaging in <abbr>CSMA/CD</abbr>) and are reported in a separate category.

> **Note:** I do not have personal experience with half-duplex operation.
> This section is simply a summarization of the standard.

## Physical Layer Collision Avoidance (Clause 148)

As mentioned in the previous section, 10Base-T1S (Clause 147) has an optional mode to permit a CAN-like prioritization scheme on the shared media.
This scheme is in addition to <abbr title="Carrier Sense Multiple Access with Collision Detection">CSMA/CD</abbr>.
Non-participating hosts can share the mixing domain with <abbr title="Physical Layer Collision Avoidance">PLCA</abbr> hosts and <abbr>PLCA</abbr> will reduce to <abbr>CSMA/CD</abbr> in the case of failure.
In effect, <abbr>PLCA</abbr> is a modified scheme for transmit deference.

The basic concept:

1. When a node comes out of reset, there is an initial wait to synchronize with the mixing domain.
2. The highest priority node will send out periodic BEACONs (<abbr>MII</abbr> command `0010`).
3. Following the beacon are a number of equally sized time slots, each corresponding to for a transmit opportunity of decreasing priority.
4. A host participating in <abbr>PLCA</abbr> can either use its transmit opportunity by sending out a packet or COMMIT (<abbr>MII</abbr> command `0011`), or yield the slot by doing nothing.
5. If the beacon is missing, hosts revert to traditional <abbr>CSMA/CD</abbr> behavior.

The actual state machines in Clause 148 are fairly complex because they serve to describe an implementation that lives entirely within the <abbr>MII</abbr> reconciliation layer.
Permitting some portion of it to live within the <abbr title="Media Access Controller">MAC</abbr> would greatly simplify the implementation and improve reliability.

When constructing the mixing domain, a few things need to be established.
These are variables used within the controlling framework and aren't directly exposed on the network.

1. The maximum identifier for the mixing domain (*aPLCANodeCount*).
   This is used by node zero to determine the period between BEACONs.
   The default value (Clause 30.16.1.1.3) is eight.
2. The unique identifier for each node (*aPLCALocalNodeID*), between 0 and 255 (inclusive).
   Higher numbered identifiers are of *lower* priority with node zero being the one responsible for sending BEACONs.
   The default value (Clause 30.16.1.1.4) is 255.
3. The length of the window for each transmit opportunity (*aPLCATransmitOpportunityTimer*).
   This is an integer between 1 and 255 bit times (inclusive) and needs to be able to absorb the propagation times of the medium and latency of participating PHYs.
   The default value (Clause 30.16.1.1.5) is 32 bit times (3.2&nbsp;&mu;s, 8 <abbr>MII</abbr> clock cycles).
   It is unclear how to manage a value that is not a multiple of four.
4. The maximum number of additional packets a node can send in a burst (*aPLCAMaxBurstCount*).
   This is an integer between 0 and 255 (inclusive).
   The default value (Clause 30.16.1.1.6) is zero.
5. The maximum time between packets in a burst (*aPLCABurstTimer*).
   This is an integer between 0 and 255 bit times (inclusive)
   The default value (Clause 30.16.1.1.7) is 128 bit times.
   It is unclear how to manage a value that is not a multiple of four.

The control node, node zero has the following scheduling behavior:

1. On reset, it will wait one transmit opportunity and, assuming the medium is idle, send out a BEACON.
   - **Note:** There is a discrepancy between the text and the state diagram.
     The text in Clause 148.4.4.1 states to wait one transmit opportunity while following the state diagram in Clause 148.4.4.6 would have node zero wait for *aPLCANodeCount* periods.
     This is because the entry point, `DISABLE`, initializes curID to zero and `RECOVER` does not change this value before launching it into the core of the state machine.
2. The BEACON is sent for 20 bit periods (5 <abbr>MII</abbr> clock cycles).
   This synchronizes the mixing domain's schedule and marks the beginning of the transmit opportunity for node zero (itself).
3. Wait for the BEACON condition to clear.
4. Wait for one of three actions:
   - If the medium goes active without COMMIT or a packet, we return to step (1) as this indicates a possible loss of synchronization.
   - If the medium goes active with COMMIT or a packet, we increment the node index once the medium is released.
   - After a period of *aPLCATransmitOpportunityTimer* elapses, the current node index is incremented.
     If new node index is equal to or greater than the node count (*aPLCANodeCount*), return to step (2) and send another BEACON.

The remaining nodes have the following scheduling behavior:

1. On reset, the node will assume <abbr>PLCA</abbr> is not active until it sees a BEACON, defaulting to <abbr>CSMA/CD</abbr>.
2. Upon receiving a BEACON, the node will enter <abbr>PLCA</abbr> mode and (re)start a 4&nbsp;&mu;s timer, `invalid_beacon_timer`.
   This establishes the transmit opportunity for node zero.
3. We wait for one of five actions:
   - If we receive a BEACON, we return to step (2), resetting the timer and node index.
   - If the medium goes active without receiving a COMMIT, BEACON, or packet, we return to step (1) as this indicates a possible loss of synchronization.
   - If the medium goes active with COMMIT or a packet, we increment the node index once the medium is released.
   - After a period of *aPLCATransmitOpportunityTimer* elapses, the current node index is incremented.
   - The timer we set in step (2), `invalid_beacon_timer`, elapses, placing <abbr>PLCA</abbr> into an inactive state.
4. Once <abbr>PLCA</abbr> has been inactive for at least 13 ms (technically, 130,090 bit times), it is considered to have failed and the mixing segment reverts to legacy <abbr>CSMA/CD</abbr> operation.
   This constitutes the purpose of the state machine described in Clause 148.4.6.

When using one's transmit opportunity, the following logic is used:

- COMMIT replaces idle to hold the transmit opportunity.
- Additional packets can be sent, up to a limit of *aPLCAMaxBurstCount*, with a maximum of *aPLCABurstTimer* between them.
- If the medium is active during our transmit opportunity, this is considered a collision and voids this opportunity.
  Transmission is delayed until our next transmit opportunity.

The state diagram in Clause 148.4.5.7 includes an elastic buffer to permit use of a <abbr>MAC</abbr> not aware of <abbr>PLCA</abbr>.
It makes extensive use of induced collision indications to force retransmissions when buffer capacity is exhausted or the transmit opportunity is violated.

> **Note:** I do not have personal experience with 10Base-T1S.
> This section is simply a summarization of the standard.
