---
# Index
date: 2025-02-25T19:21:00-08:00
# Metadata
title: "Ethernet: Gigabit Media Independent Interface (GMII)"
series: ethernet
series_weight: 300
slug: ethernet-gmii
tags:
  - embedded
  - ethernet
  - hardware
  - network
---

When introducing Gigabit Ethernet, there was a problem adopting the existing <abbr title="Media Independent Interface">MII</abbr>.
Simply increasing the clock speed another order of magnitude would bring it to 250&nbsp;MHz and a period of 4&nbsp;ns.
This introduced two issues:
First, the clock speed would be well in excess of those used by commodity memory buses of the time, making it difficult to implement.
Second, the system synchronous design of the transmit path would make it impossible to control setup and hold timing.

So, in order to facilitate the new high speed protocol, a new xMII was introduced: the Gigabit Media Independent Interface (<abbr>GMII</abbr>), defined in Clause 35.
This doubles the data bus width to a full byte, limiting the clock rate to a more modest 125&nbsp;MHz, and switches the transmit path to a source-synchronous configuration.
This interface is defined exclusively for Gigabit Ethernet but may occasionally crop up in 2.5G applications.

Given the high pin count and complexity when supporting 10/100/1000 operation, GMII is rarely seen as an inter-chip interface in modern designs.
The externally defined <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> (effectively a <addr title="Double Data Rate">DDR</abbr> version of GMII) or <abbr title="Serial Gigabit Media Independent Interface">SGMII</abbr> interfaces are more commonly seen.
Despite this, these are still defined in context of GMII.

> **Note:** The most recent version of the 802 standards are available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68) at no cost.
> It is highly advised that anyone working with Ethernet download a copy of 802.3 (Wired Ethernet).

## Signaling (Clause 35.2) {id="signaling"}

<abbr title="Gigabit Media Independent Interface">GMII</abbr> is defined by 24 individual signals, largely straightforward extensions from those used in <abbr title="Media Independent Interface">MII</abbr>.
Each direction (transmit and receive) has eleven signals: a source-synchronous clock (`RX_CLK`/`GTX_CLK`), a valid/enable signal (`RX_DV`/`TX_EN`), an error signal (`RX_ER`/`TX_ER`), and an eight-bit data bus (`RXD`/`TXD`).
The MII half-duplex signals, *Carrier Sense* (`CRS`) and *Collision Detected* (`COL`), are still present even though half-duplex was never widely supported on Gigabit.

<figure>
<svg viewBox="-5 -15 310 230" style="display:block;margin:auto;max-width:400px;">
  <title>GMII Signals</title>
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
    <text x="110" y="75">RXD[7:0]</text>
    <!-- Transmit Bus -->
    <use href="#arrow" x="-200" y="-100" transform="rotate(180)"/>
    <text x="110" y="95">GTX_CLK</text>
    <use href="#arrow" x="-200" y="-120" transform="rotate(180)"/>
    <text x="110" y="115">TX_EN</text>
    <use href="#arrow" x="-200" y="-140" transform="rotate(180)"/>
    <text x="110" y="135">TX_ER</text>
    <use href="#arrow" x="-200" y="-160" transform="rotate(180)"/>
    <text x="110" y="155">TXD[7:0]</text>
    <!-- Asynchronous -->
    <use href="#arrow" x="100" y="180"/>
    <text x="110" y="175">CRS</text>
    <use href="#arrow" x="100" y="200"/>
    <text x="110" y="195">COL</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr title="Gigabit Media Independent Interface">GMII</abbr> Signals</figcaption>
</figure>

The transmit and receive paths are largely symmetric.
`RX_DV`/`TX_EN` indicate when the medium is transmitting a packet and `RX_ER`/`TX_ER` indicate the presence of a special condition.
Together, the combination of the valid/enable and error signals control the interpretation of the data bus with an equivalent encoding as MII:

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
    <text x="0" y="15">GTX_CLK</text>
    <text x="0" y="45">TX_EN</text>
    <text x="0" y="75">TXD[7:0]</text>
    <text x="0" y="105">TX_ER</text>
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
    <path d="M150,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M170,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
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
    <text x="120" y="75">55</text>
    <text x="140" y="75">55</text>
    <text x="160" y="75">55</text>
    <text x="180" y="75">55</text>
    <text x="200" y="75">55</text>
    <text x="220" y="75">55</text>
    <text x="240" y="75">55</text>
    <!-- SFD -->
    <text x="260" y="75">D5</text>
    <!-- Payload -->
    <text x="310" y="75">...</text>
    <text x="370" y="75">X</text>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="110" y1="5" x2="110" y2="120"/>
    <line x1="250" y1="5" x2="250" y2="120"/>
    <line x1="270" y1="5" x2="270" y2="120"/>
    <line x1="350" y1="5" x2="350" y2="120"/>
  </g>
  <!-- Captions -->
  <g dominant-baseline="middle" font-size="12" text-anchor="middle">
    <text x="180" y="95">Preamble</text>
    <text x="260" y="95" font-size="10">SFD</text>
    <text x="310" y="95">Frame</text>
  </g>
</svg>
<figcaption style="text-align:center">Packet Structure</figcaption>
</figure>

Even though a standard preamble is 7 bytes of `0x55` followed by the SFD, as with MII, there is no guarantee you will receive the full preamble.
It is advised that the MAC accept any number of `0x55`, including zero, prior to the appearance of the SFD, `0xD5`.

## Clocking (Clause 35.5.2) {id="clocking"}

Both clocks in <abbr title="Gigabit Media Independent Interface">GMII</abbr> are source-synchronous.
The transmit clock is sourced by the <abbr title="Media Access Controller">MAC</abbr> and the receive clock by the PHY.
A standard clock 125&nbsp;MHz (8&nbsp;ns period) with a tolerance of 100&nbsp;<abbr title="Parts Per Million">ppm</abbr> and duty cycle between 35% and 75%.
Setup and hold times are defined as 2.5&nbsp;ns and 0.5&nbsp;ns at the signal source, reducing to 2.0&nbsp;ns and 0&nbsp;ns at the receiver, indicating a maximum permissible mismatch of 500&nbsp;ps when length matching.

<figure>
<svg viewBox="20 -5 280 160" style="display:block;margin:auto;max-width:500px;">
  <title>Signal Timing</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="12">
    <text x="25" y="15" font-size="15">RX_CLK</text>
    <text x="25" y="35" font-size="15">GTX_CLK</text>
    <text x="25" y="105">RX_DV/ER</text>
    <text x="25" y="120">RXD[7:0]</text>
    <text x="25" y="135">TX_EN/ER</text>
    <text x="25" y="150">TXD[7:0]</text>
  </g>
  <!-- Waveforms -->
  <polyline fill="none" stroke="black"
    points="105,50 135,50 145,0 175,0 185,50 215,50 225,0 255,0 265,50 295,50"/>
  <g fill="#8F88" stroke="#4F4">
    <polyline points="120,125 125,100 145,100 150,125 145,150 125,150 120,125"/>
    <polyline points="200,125 205,100 225,100 230,125 225,150 205,150 200,125"/>
    <polyline points="295,100 285,100 280,125 285,150 295,150"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <polyline points="105,100 115,100 120,125 115,150 105,150"/>
    <polyline points="150,125 155,100 195,100 200,125 195,150 155,150 150,125"/>
    <polyline points="230,125 235,100 275,100 280,125 275,150 235,150 230,125"/>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="120" y1="65" x2="120" y2="150"/>
    <line x1="140" y1="5" x2="140" y2="110"/>
    <line x1="150" y1="65" x2="150" y2="150"/>
  </g>
  <!-- Spans -->
  <g stroke="black">
    <line x1="140" y1="77.5" x2="145" y2="77.5"/>
    <line x1="140" y1="87.5" x2="125" y2="87.5"/>
  </g>
  <g fill="black" stroke="none">
    <polyline points="145,80 145,75 150,77.5"/>
    <polyline points="125,90 125,85 120,87.5"/>
  </g>
  <!-- Dimensions -->
  <g dominant-baseline="middle" font-size="10">
    <text x="117.5" y="87.5" text-anchor="end">Tsu = 2.5 ns / 2.0 ns</text>
    <text x="152.5" y="77.5" text-anchor="start">Thold = 0.5 ns / 0 ns</text>
  </g>
  <!-- Validity -->
  <g dominant-baseline="middle" text-anchor="middle" font-size="8">
    <text x="135" y="125" class="caption">VALID</text>
    <text x="175" y="125" class="caption">INVALID</text>
    <text x="215" y="125" class="caption">VALID</text>
    <text x="255" y="125" class="caption">INVALID</text>
  </g>
</svg>
<figcaption style="text-align:center">Signal Timing</figcaption>
</figure>

As with MII, the receive clock may be sourced from the local oscillator or the recovered clock from the peer and may be suppressed under Low Power Idle (LPI).
Due to this, it may shift in frequency, phase, or disappear entirely based upon the link state.
As such, it cannot be safely used as the reference for a <abbr title="Phase Locked Loop">PLL</abbr>.

The MAC-provided transmit clock, `GTX_CLK`, may or may not be used for transmission on the media.
In 1000Base-T, for example, part of autonegotiation process is to determine a master/slave relationship and the slave will use the recovered clock for transmission, maintaining a constant phase relationship between the two directions.
This means that there will be transmit buffering within the PHY and may end up masking considerable clock error on minimum length packets while mysteriously failing on larger packets.

An example <abbr title="Synopsys Design Constraint">SDC</abbr> would be:

```tcl
# Requirements from 802.3
set clk_period 8
set txd_hold 0.5
set txd_setup 2.5
set rxd_hold 0.0
set rxd_setup 2.0

# Transmit Constraints
# TODO: Update source and division to match logic
create_generated_clock -name GTX_CLK [get_ports GTX_CLK] \
    -source [get_pins */GTX_CLK_GEN/C] -divide_by 1
set_output_delay -clock GTX_CLK -min -$txd_hold \
    [get_ports {TX_EN TX_ER TXD[*]}]
set_output_delay -clock GTX_CLK -max +$txd_setup \
    [get_ports {TX_EN TX_ER TXD[*]}]

# Receive Constraints
create_clock -name RX_CLK -period $clk_period [get_ports RX_CLK]
create_clock -name RX_CLK_virt -period $clk_period
set_input_delay -clock RX_CLK_virt -min $rxd_hold \
    [get_ports {RX_DV RX_ER RXD[*]}]
set_input_delay -clock RX_CLK_virt \
    -max [expr {$clk_period - $rxd_setup}] \
    [get_ports {RX_DV RX_ER RXD[*]}]
```

## Data Errors (Clause 35.2.2.5, 35.2.2.9) {id="errors"}

As with <abbr title="Media Independent Interface">MII</abbr>, encoding errors can be indicated by the use of `RX_ER` or `TX_ER`.
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
    <text x="0" y="75">RXD[7:0]</text>
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

## Control Sequences (Clause 35.2.2.4, 35.2.2.8) {id="control"}

As with <abbr title="Media Independent Interface">MII</abbr>, the error signal (`RX_ER`/`TX_ER`) can be used to indicate the presence of control sequences when the valid signal (`RX_DV`/`TX_EN`) are held low.
The values are broadly similar to those in MII, simply zero extended, with the addition of two new values for the special handling of half-duplex in Gigabit.

Value | Transmit             | Receive
:----:|:---------------------|:------------------
`00`  | Reserved             | Normal Interframe
`01`  | Assert <abbr title="Low Power Idle">LPI</abbr> | Assert <abbr>LPI</abbr>
`0E`  | Reserved             | False Carrier
`0F`  | Carrier Extend       | Carrier Extend
`1F`  | Carrier Extend Error | Carrier Extend Error
{style="margin:auto"}

*False Carrier* (`0E`) typically indicates a coding error on the part of the remote peer (Clause 36.2.5.2.3).
This can generally be ignored except for logging purposes but may indicate hardware malfunction.

*Carrier Extend* (`0F`) and *Carrier Extend Error* (`1F`) are used in half-duplex Gigabit operation to extend a packet to meet the minimums required by the extended *slotTime*.
They are not normally part of full-duplex operation but may be introduced by 1000Base-X (e.g. fiber) and its derivatives (e.g. <abbr title="Serial Gigabit Media Independent Interface">SGMII</abbr>).

## Tri-Mode Operation (Clause 35.3) {id="trimode"}

Tri-Mode (10/100/1000) operation is somewhat involved under <abbr title="Gigabit Media Independent Interface">GMII</abbr>.
As GMII is only defined for Gigabit operation, the bus is required to revert to <abbr title="Media Independent Interface">MII</abbr> when operating at reduced rate, including switching the transmit bus from `GTX_CLK` to `TX_CLK` and only sending one nibble at a time.

While operating at reduced rate, the high order bits (four through seven) and `GTX_CLK` becomes do-not-care.
For power reduction and stability purposes, they should be driven to a known value (e.g. zero).

This means that a tri-mode PHY has 25 pins (the addition of `TX_CLK`) instead of the standard GMII set of 24.
And both sets of constraints (MII and GMII) should be present for the transmit pins.

## Link Configuration {id="link-config"}

The fundamental properties when configuring the interface, be it manually or through autonegotiation, are the following:

- *Link Speed*.
  As the clocking structure changes between 10/100 and Gigabit, it is essential for the <abbr title="Media Access Controller">MAC</abbr> to know which speed has been negotiated.
  Failure to do so will result in link failure.
- *Link Duplex*.
  Half-duplex requires the implementation of <abbr title="Carrier Sense Multiple Access with Collision Detection">CSMA/CD</abbr> on the part of the MAC along with the Gigabit-specific complications.
  This is rarely supported on Gigabit and should be disabled in autonegotiation.
- *Energy Efficient Ethernet*.
  <abbr>EEE</abbr> will result in the potential generation of <abbr title="Low Power Idle">LPI</abbr> sequences by the peer, which may result in `RX_CLK` being halted.
  It also allows the local MAC to generate LPI sequences of its own and halt `GTX_CLK` to reduce power consumption.

These properties are not available in-band and need to be accessed through the management interface.

> **Note:** Autonegotiation is required on 1000Base-T to determine the master/slave relationship.
> Even when disabled in the management interface, the autonegotiation process will still occur but with only one rate/duplex offered.

## Crossover

Crossover in this context refers to connecting two devices of the same class (PHY or <abbr title="Media Access Controller">MAC</abbr>) directly.
For example, connecting the TX of one <abbr>MAC</abbr> directly to the RX of a second <abbr>MAC</abbr> without an intervening PHY, or using a pair of PHYs as a media converter.

As both sides of the link are source-synchronous and largely identical in their operation, direct crossover is broadly compatible.
The only complication would be possible truncation of the preamble in a PHY-to-PHY crossover.
There are no expected complications in a MAC-to-MAC crossover.

## Energy Efficient Ethernet (Clause 35.4, 78) {id="eee"}

As with 100Base-TX, the transmitters run continuously in Gigabit Ethernet, even when the link is idle.
Energy Efficient Ethernet (<abbr>EEE</abbr>) is a mechanism by which the transmitter can be disabled during periods of extended inactivity, reducing power consumption.
To maintain the link, the PHY will periodically enable its transmitter to send a refresh signal.

First, <abbr>EEE</abbr> support needs to be negotiated with the peer.
On some PHYs, this is enabled by default.
On others, some form of configuration is required.
This is normally handled through the Clause 45 register sets MMD3 and MMD7.

When the peer signals it is entering Low Power Idle (<abbr>LPI</abbr>), the local PHY will report this to the MAC by signalling *Assert LPI*, holding `RX_DV` low, `RX_ER` high, and `01` on `RXD`.
Once the PHY has indicated this condition for at least nine clock cycles, it may halt `RX_CLK` until the peer leaves <abbr>LPI</abbr>.
Upon leaving LPI, the PHY will provide some number of cycles of ordinary idle before sending packets.

When the local <abbr title="Media Access Controller">MAC</abbr> is idle, it may request the PHY enter LPI in a similar manner:
It pulls `TX_EN` low, `TX_ER` high, and loads `01` onto `TXD`.
However, when it wishes to resume transmission, it cannot do so immediately upon releasing *Assert LPI*.
The peer needs time to synchronize its clock recovery and descrambler.
The minimum required time is specified in Clause 78 as <var>T<sub>w_sys_tx</sub></var>, which is provided for each PHY in Table 78-4.
For the PHYs covered by Clause 35 GMII, these times are:

- For 1000Base-KX, this is 13.26&nbsp;&mu;s (1657.5 clock cycles).
- For 1000Base-T, this is 16.5&nbsp;&mu;s (2062.5 clock cycles).
- For 1000Base-T1, this is 10.8&nbsp;&mu;s (1350 clock cycles).

As with the PHY, the MAC is allowed to halt `GTX_CLK` after clocking at least nine cycles of *Assert LPI*.

<figure>
<svg viewBox="0 0 400 120" style="display:block;margin:auto;max-width:500px;">
  <title>LPI Transmit Timing</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="0" y="45">TX_EN</text>
    <text x="0" y="75">TXD[7:0]</text>
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
    <text x="190" y="75">01</text>
    <text x="310" y="75">X</text>
    <text x="370" y="75">...</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr title="Low Power Idle">LPI</abbr> Transmit Timing</figcaption>
</figure>

Failure to meet these timing requirements may result in data loss as the peer may not have been able to complete synchronization.

## Half-Duplex (Clause 4.2.3.2, 35.2.2) {id="duplex"}

The specification for 1000Base-T includes half-duplex operation (Clause 41).
To my knowledge, Gigabit hubs were never commercially available and, as a result, many pieces of Gigabit hardware do not include support for half-duplex operation.
As such, it is best to disable half-duplex operation in the autonegotiation register set.

Half-Duplex operation in Gigabit is broadly similar to that in 10/100 with one notable exception.
As the duration of a minimum length frame at these speeds is less than the round-trip time at the maximum segment length, the *slotTime* was increased from 512&nbsp;bits (64&nbsp;bytes) to 4096&nbsp;bits (512&nbsp;bytes).
This means the <abbr title="Media Access Controller">MAC</abbr> must hold the media for at least that long in order to detect collisions.

Instead of increasing the minimum packet size, <abbr title="Gigabit Media Independent Interface">GMII</abbr> allows one to hold the carrier beyond the end of a frame by using the *Carrier Extend* condition (`0F`) listed previously.
This acts like an <abbr title="Inter-Packet Gap">IPG</abbr> between packets while maintaining the carrier.
To avoid simply wasting this time, after the normal 96&nbsp;bits (12&nbsp;bytes) of IPG and, if still within the initial *slotTime*, the MAC may continue transmitting packets.

While half-duplex Gigabit may be a historical curiosity, *Carrier Extend* does make an appearance in 1000Base-X (e.g. fiber and <abbr title="Serial Gigabit Media Independent Interface">SGMII</abbr>).
Even in full-duplex operation, a couple cycles may appear at the end of each frame due to the nature of the encoding.

## Ten Bit Interface (Clause 35.3, 36.3) {id="tbi"}

1000Base-X (and its derivatives) encodes the packet stream using 8b10b encoding, where every byte (8b) is encoded with ten bits (10b).
The specifics of this encoding will be covered in the article on 1000Base-X; however, <abbr title="Gigabit Media Independent Interface">GMII</abbr> includes a provision to carry the <abbr title="Physical Coding Sublayer">PCS</abbr> encoding directly.
This mode is known as the Ten Bit Interface (<abbr>TBI</abbr>), covered by Clause 36.3.

GMII covers the mapping between its signals and TBI in Clause 35.3.
Under TBI, `RXD[7:0]` and `TXD[7:0]` map to the low order eight bytes directly, while `RX_DV`/`TX_EN` map to the ninth bit and `RX_ER`/`TX_ER` map to the tenth.
This is merely a pin assignment; the PCS encoding is not equivalent to that described in previous sections.

As 1000Base-T does not use this encoding, it makes little sense when communicating with a traditional PHY where it is rarely supported (e.g. Marvell Alaska 88E1111).
This encoding is used with 1000Base-X (e.g. fiber), where one is more likely to use the high-speed transceivers built into the processor or <abbr title="Field Programmable Gate Array">FPGA</abbr> instead of an external PHY.
