---
date: 2025-02-24T20:35:00-0800
title: "Ethernet: Reduced Media Independent Interface (RMII)"
series: ethernet
series_weight: 250
slug: ethernet-rmii
tags:
  - embedded
  - ethernet
  - hardware
  - network
---

One of the early complaints about <abbr title="Media Independent Interface">MII</abbr> was that it used too many pins.
For a switch <abbr title="Application-Specific Integrated Circuit">ASIC</abbr> and external PHYs, it would require sixteen pins and two clock domains per port.
For an eight port switch, that's 128 pins and sixteen clock domains before power and other considerations.
As silicon became cheaper, *packaging* started to be the dominant cost for low-end integrated circuits.
In order to keep costs down, they needed a way to reduce the number of pins.

A group of silicon makers came together and formed the <abbr title="Reduced Media Independent Interface">RMII</abbr> Consortium to propose a new interface.
As this was performed externally to the ethernet working group, this interface will not be found in <abbr title="Institute of Electrical and Electronic Engineers">IEEE</abbr> 802.3.
The standard needs to be sourced separately.
As there is no clear restriction on distribution, a copy is mirrored locally:
[RMII Specification Rev 1.2](rmii_1_2.pdf).

> **Note:** There is no relationship between RMII and <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr>.
> Implementations and concepts from one will not translate to the other.

## Signaling (Clause 5)

In brief, <abbr title="Reduced Media Independent Interface">RMII</abbr> operates on a fixed 50&nbsp;MHz system clock, sending two bits at a time instead of four.
The `RX_DV` and `CRS` signals are merged into a combined `CRS_DV` while the error signals, `RX_ER` and `TX_ER`, are largely jettisoned.
`COL` is derived in the reconciliation layer from `CRS_DV` and `TX_EN`.
This derivation of the half-duplex signals from the receive and transmit enables will become increasingly common in <abbr title="Media Independent Interface">xMII</abbr> variants.

<figure>
<svg viewBox="-5 -15 310 210" style="display:block;margin:auto;max-width:400px;">
  <title>RMII Signals</title>
  <symbol id="arrow" y="-5">
    <line stroke="black" x1="5" y1="5" x2="100" y2="5"/>
    <polyline fill="black" stroke="none" points="5,2.5 5,7.5 0,5"/>
  </symbol>
  <!-- Top Level Blocks-->
  <g fill="none" stroke="black">
    <rect x="0" y="5" width="100" height="125"/>
    <line x1="0" x2="100" y1="70" y2="70"/>
    <line x1="0" x2="100" y1="110" y2="110"/>
    <rect x="200" y="5" width="100" height="125"/>
    <line x1="200" x2="300" y1="70" y2="70"/>
    <line x1="200" x2="300" y1="110" y2="110"/>
    <rect x="110" y="150" width="80" height="40"/>
  </g>
  <g font-size="15" text-anchor="middle">
    <text x="50">MAC</text>
    <text x="250">PHY</text>
  </g>
  <g dominant-baseline="middle" font-size="15" text-anchor="middle">
    <text x="50" y="40">RX</text>
    <text x="50" y="90">TX</text>
    <text x="250" y="40">RX</text>
    <text x="250" y="90">TX</text>
    <text x="150" y="170">Oscillator</text>
  </g>
  <!-- Buses -->
  <g font-size="12">
    <!-- Receive Bus -->
    <use href="#arrow" x="100" y="20"/>
    <text x="110" y="15">CRS_DV</text>
    <use href="#arrow" x="100" y="40"/>
    <text x="110" y="35">RXD[1:0]</text>
    <use href="#arrow" x="100" y="60" stroke-dasharray="3,3"/>
    <text x="110" y="55">RX_ER *</text>
    <!-- Transmit Bus -->
    <use href="#arrow" x="-200" y="-80" transform="rotate(180)"/>
    <text x="110" y="75">TX_EN</text>
    <use href="#arrow" x="-200" y="-100" transform="rotate(180)"/>
    <text x="110" y="95">TXD[3:0]</text>
    <!-- Shared -->
    <g>
      <line stroke="black" x1="100" y1="120" x2="200" y2="120"/>
      <polyline fill="black" stroke="none" points="105,122.5 105,117.5 100,120"/>
      <polyline fill="black" stroke="none" points="195,122.5 195,117.5 200,120"/>
      <line stroke="black" x1="150" y1="150" x2="150" y2="120"/>
      <polyline fill="black" stroke="none" points="152.5,125 147.5,125 150,120"/>
    </g>
    <text x="110" y="115">REF_CLK</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr title="Reduced Media Independent Interface">RMII</abbr> Signals</figcaption>
</figure>

### Transmit (Clause 5.5)

For 100&nbsp;megabit transmit operation, <abbr title="Reduced Media Independent Interface">RMII</abbr> is largely equivalent to ordinary <abbr title="Media Independent Interface">MII</abbr> except by using two bits per clock cycle (di-bit) instead of four.
As in keeping with Ethernet conventions, these bits are transmitted LSB first.
For example, the [example packet from the introduction]({{<ref "2024-10-08-ethernet-intro#ethernet-packets-and-frames-clause-3">}}) (ends with <abbr title="Frame Check Sequence">FCS</abbr> `69 70 39 BB`) would be sent:

SIGNAL    |   | 1 | 2 |...| 29| 30| 31| 32|...|281|282|283|284|285|286|287|288|
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`TX_EN`   |`0`|`1`|`1`|...|`1`|`1`|`1`|`1`|...|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`0`
`TXD[1]`  |`0`|`0`|`0`|...|`0`|`0`|`0`|`1`|...|`0`|`1`|`1`|`0`|`1`|`1`|`1`|`1`|`0`
`TXD[0]`  |`0`|`1`|`1`|...|`1`|`1`|`1`|`1`|...|`1`|`0`|`1`|`0`|`1`|`0`|`1`|`0`|`0`
{style="font-size:80%;margin:auto"}

When the bus is idle, `TXD` is supposed to be zero.
Non-zero values are reserved under Clause 9.1.

### Receive (Clause 5.3)

For receive, `CRS` (Carrier Sense) and `RX_DV` (Receive Data Valid) are merged.
This means that `CRS_DV` will assert *asynchronously* to `REF_CLK` and remain high prior to the appearance of received data on `RXD`.
During this period of time, `RXD` will be zero until the PHY determines whether it's a valid packet or not.
If so, it will then immediately transition into sending the preamble.

SIGNAL    |   |   |   |   |   |   |   | 1 | 2 |...| 29| 30| 31| 32|...
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`CRS_DV`  |`0`|`R`|`R`|`1`|`1`|...|`1`|`1`|`1`|...|`1`|`1`|`1`|`1`|...
`RXD[1]`  |`X`|`0`|`0`|`0`|`0`|...|`0`|`0`|`0`|...|`0`|`0`|`0`|`1`|...
`RXD[0]`  |`X`|`0`|`0`|`0`|`0`|...|`0`|`1`|`1`|...|`1`|`1`|`1`|`1`|...
{style="font-size:80%;margin:auto"}

If the PHY instead decides it is a false carrier, it will signal `10` on the receive interface instead.

SIGNAL    |   |   |   |   |   |   |   |   |   |   |   |   |   |
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
`CRS_DV`  |`0`|`R`|`R`|`1`|`1`|...|`1`|`1`|`1`|`1`|`1`|`0`|`0`|
`RXD[1]`  |`X`|`0`|`0`|`0`|`0`|...|`0`|`1`|`1`|`1`|`1`|`X`|`X`|
`RXD[0]`  |`X`|`0`|`0`|`0`|`0`|...|`0`|`0`|`0`|`0`|`0`|`X`|`X`|
{style="font-size:80%;margin:auto"}

As such, `00` should be interpreted as "MII bus idle, carrier sense high"; `01` as the beginning of the preamble; and the remaining two values as error indications.

Deassertion is a bit complicated and the notable difference between the two RMII revisions.
In RMII version 1.0, `CRS_DV` will deassert normally at the end of the packet with the last di-bit.
For example, the [example packet from the introduction]({{<ref "2024-10-08-ethernet-intro#ethernet-packets-and-frames-clause-3">}}) (ends with <abbr title="Frame Check Sequence">FCS</abbr> `69 70 39 BB`) would terminate:

SIGNAL    |281|282|283|284|285|286|287|288|...|...|...|...
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`CRS_DV`  |`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`0`|`0`|`0`|`0`
`RXD[1]`  |`0`|`1`|`1`|`0`|`1`|`1`|`1`|`1`|`X`|`X`|`X`|`X`
`RXD[0]`  |`1`|`0`|`1`|`0`|`1`|`0`|`1`|`0`|`X`|`X`|`X`|`X`
{style="font-size:80%;margin:auto"}

However, it was considered a defect that the falling of carrier sense would be delayed until all data was clocked out of the PHY.
So, in RMII revision 1.2, the `CRS_DV` deassertion pattern was changed to distinguish "MII bus active, carrier sense low" by *toggling* the `CRS_DV` line.
For example, if carrier sense were to drop on the last two bytes of the packet:

SIGNAL    |281|282|283|284|285|286|287|288|...|...|...|...
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`CRS_DV`  |`0`|`1`|`0`|`1`|`0`|`1`|`0`|`1`|`0`|`0`|`0`|`0`
`RXD[1]`  |`0`|`1`|`1`|`0`|`1`|`1`|`1`|`1`|`X`|`X`|`X`|`X`
`RXD[0]`  |`1`|`0`|`1`|`0`|`1`|`0`|`1`|`0`|`X`|`X`|`X`|`X`
{style="font-size:80%;margin:auto"}

The specification indicates that the first (low-order) di-bit of an MII nibble is to be low.
The reconciliation layer can consider the *carrierSense* signal to be the logical AND of `CRS_DV` over the past two ticks while `RX_DV` is the logical OR of the two values.

As with the transmit interface, `RXD` is supposed to be zero when then the bus is idle (Clause 9.1).
This is effectively required by the pseudo-asynchronous nature of `CRS_DV`.

### 10 Megabit Operation (Clause 5.3.2, Clause 5.5.2)

As the system clock is running continuously at 50&nbsp;MHz, it cannot be reduced for 10 megabit operation.
Instead, the system will simply hold the bus for ten cycles to provide a 10x reduction in datarate.
For example, to send the value `B` (`1011`):

SIGNAL    |...|  1|  2|  3|  4|  5|  6|  7|  8|  9| 10| 11| 12| 13| 14| 15| 16| 17| 18| 19| 20|...
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`RXD[1]`  |...|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|...
`RXD[0]`  |...|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|...
{style="font-size:80%;margin:auto"}

This also applies to the alternation of `CRS_DV` at the end of a packet in RMII revision 1.2.

SIGNAL    |...|  1|  2|  3|  4|  5|  6|  7|  8|  9| 10| 11| 12| 13| 14| 15| 16| 17| 18| 19| 20|...
:---------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:
`CRS_DV`  |...|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`0`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|`1`|...
{style="font-size:80%;margin:auto"}

Neither peer is required to align itself to the beginning of a packet.
It is considered acceptable to simply sample every tenth cycle and ignore the other nine.

## Clocking (Clause 5.1, Clause 7.4)

<abbr title="Reduced Media Independent Interface">RMII</abbr> uses a single, system synchronous clock domain.
This clock is specified as 50&nbsp;MHz &plusmn; 50&nbsp;ppm (20&nbsp;ns period) with a duty cycle between 35% and 65%.
Clause 7.4 specifies a setup of 4&nbsp;ns and hold of 2&nbsp;ns for a total valid window of 6&nbsp;ns (30% of the period), measured at the inputs of each component.
All specifications are relative to the rising edge.

<figure>
<svg viewBox="20 -5 280 160" style="display:block;margin:auto;max-width:500px;">
  <title>RMII Signal Timing</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="12">
    <text x="25" y="25" font-size="15">REF_CLK</text>
    <text x="25" y="105">CRS_DV *</text>
    <text x="25" y="120">RXD[1:0]</text>
    <text x="25" y="135">TX_EN</text>
    <text x="25" y="150">TXD[1:0]</text>
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
  <g dominant-baseline="middle" font-size="12">
    <text x="117.5" y="87.5" text-anchor="end">Tsu = 4&nbsp;ns</text>
    <text x="152.5" y="77.5" text-anchor="start">Thold = 2&nbsp;ns</text>
  </g>
  <!-- Validity -->
  <g dominant-baseline="middle" text-anchor="middle" font-size="8">
    <text x="135" y="125" class="caption">VALID</text>
    <text x="175" y="125" class="caption">INVALID</text>
    <text x="215" y="125" class="caption">VALID</text>
    <text x="255" y="125" class="caption">INVALID</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr>RMII</abbr> Signal Timing</figcaption>
</figure>

The RMII specification expects that `REF_CLK` is generated by the MAC or a shared system clock; however, some PHYs provide modes where the PHY will generate the reference clock.
The later is generally intended for embedded applications where RMII is chosen to keep the pin count minimized.
An example <abbr title="Synopsys Design Constraint">SDC</abbr> would be:

```tcl
# Requirements from RMII 1.2
set refclk_period 20
set rmii_setup 4
set rmii_hold 2

# Routing latencies of REF_CLK and the data signals
# TODO: Update these for your PCB
# - REF_CLK source to PHY (0 if sourced by PHY)
set refclk_phy_min 0
set refclk_phy_max 0
# - REF_CLK source to MAC (0 if sourced by MAC)
set refclk_mac_min 0
set refclk_mac_max 0
# - Routing from MAC to/from PHY
set rmii_min 0
set rmii_max 0

# Select Appropriate Clock Source
if $REFCLK_SYSTEM {
  # External Source (e.g. System, PHY)
  create_clock -name REF_CLK -period $refclk_period [get_ports REF_CLK]
  create_clock -name REF_CLK_sys -period $refclk_period
} else if $REFCLK_LOCAL {
  # Generated Locally
  # TODO: Update source and division to match logic
  create_generated_clock -name REF_CLK_sys [get_ports REF_CLK] \
      -source [get_pins */REF_CLK_GEN/C] -divide_by 1
}

# Input Constraints
set_input_delay -clock REF_CLK_sys \
    -min [expr {$rmii_min + $refclk_phy_min - $refclk_mac_max + $rmii_hold}] \
    [get_ports {CRS_DV RXD[*]}]
set_input_delay -clock REF_CLK_sys \
    -max [expr {$rmii_max + $refclk_phy_max - $refclk_mac_min - $rmii_setup + $rmii_period}] \
    [get_ports {CRS_DV RXD[*]}]

# Output Constraints
set_output_delay -clock REF_CLK_sys \
    -min [expr {$rmii_min + $refclk_mac_min - $refclk_phy_max - $rmii_hold}] \
    [get_ports {TX_EN TXD[*]}]
set_output_delay -clock REF_CLK_sys \
    -max [expr {$rmii_max + $refclk_mac_max - $refclk_phy_min + $rmii_setup}] \
    [get_ports {TX_EN TXD[*]}]
```

## Data Errors (Clause 5.5.3, Clause 5.7)

RMII does not have any equivalent to `TX_ER`.
This means that the <abbr title="Media Access Controller">MAC</abbr> cannot spoil a packet except to explicitly corrupt its <abbr title="Frame Check Sequence">FCS</abbr>.
It also means that transmitting control codes (e.g. <abbr title="Low Power Idle">LPI</abbr>, <abbr title="Physical Link Collision Avoidance">PLCA</abbr>) is impossible.

It does, however, provide `RX_ER` to indicate coding errors; however, it treats `RX_ER` as do-not-care when `CRS_DV` is low.
As such, it also should not be used to indicate control controls.

## Half-Duplex

Half-Duplex is the same as ordinary <abbr title="Media Independent Interface">MII</abbr>.
The standard `CRS` signal is derived from `CRS_DV` as per the receive discussion.
The standard `COL` signal is generated from AND'ing that derived `CRS` with `TX_EN`.

## Link Configuration

The fundamental properties when configuring the interface, be it manually or through autonegotiation, are the following:

- *Link Speed*.
  As 10&nbsp;megabit is generated by simply sampling at a reduced rate, it is essential that the <abbr title="Media Access Controller">MAC</abbr> be aware of the negotiated rate.
  Failure to do so will result in complete failure of the link.
- *Link Duplex*.
  Half-duplex requires the implementation of <abbr title="Carrier Sense Multiple Access with Collision Detection">CSMA/CD</abbr> on the part of the <abbr>MAC</abbr>.
- *Energy Efficient Ethernet*.
  Due to the lack of `TX_ER`, <abbr title="Low Power Idle">LPI</abbr> cannot be signaled in-band.
  If an RMII PHY supports LPI (e.g. [TI DP83836](https://www.ti.com/product/DP83826I)), it will be controlled through the management interface.

These properties are not available in-band and need to be accessed through the management interface.

## Crossover

Crossover in this context refers to connecting two devices of the same class (PHY or <abbr title="Media Access Controller">MAC</abbr>) directly.
For example, connecting the TX of one <abbr>MAC</abbr> directly to the RX of a second <abbr>MAC</abbr> without an intervening PHY, or using a pair of PHYs as a media converter.

For MACs using an external clock, crossing them over is fairly straightforward (assuming they follow the same RMII version).
The only difficulty for PHYs is in the combined `CRS_DV` of the receive interface.
This may raise prior to the availability of data and alternates at the end of the packet, both of which lead to a corrupted packet.
Many PHYs, as a result, include a feature where an MII-compliant `RX_DV` can be provided instead.
