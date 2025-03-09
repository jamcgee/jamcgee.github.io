---
date: 2025-03-08T17:30:00-0800
title: "Ethernet: Reduced Gigabit Media Independent Interface (RGMII)"
series: ethernet
series_weight: 350
slug: ethernet-rgmii
tags:
  - embedded
  - ethernet
  - hardware
  - network
---

Even worse than the original <abbr title="Media Independent Interface">MII</abbr>, <abbr title="Gigabit Media Independent Interface">GMII</abbr> used too many pins.
For full tri-mode (10/100/1000) operation, a full 25 were required.
This is becoming problematic not only for switches, but ordinary processors and <abbr title="Field Programmable Gate Array">FPGA</abbr>s.

As when the RMII Consortium formed to produce <abbr title="Reduced Media Independent Interface">RMII</abbr>, a group of silicon makers got together to produce a Reduced *Gigabit* Media Independent Interface (RGMII).
Since this was performed external to the ethernet working group, this interface will not be found in <abbr title="Institute of Electrical and Electronic Engineers">IEEE</abbr> 802.3.
The standard needs to be sourced separately.
With distribution largely unrestricted, copies of the standard are mirrored locally:
RGMII [Version 1.3](rgmii_1_3.pdf "RGMII Version 1.3"), [Version 2.0](rgmii_2_0.pdf "RGMII Version 2.0").

> **Note:** There is no relationship between RMII and RGMII.
> Implementations and concepts from one will not translate to the other.

## Signaling (Clause 3) {id="signaling"}

Broadly speaking, <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> is a <abbr title="Double Data Rate">DDR</abbr> version of <abbr title="Gigabit Media Independent Interface">GMII</abbr>.
Each direction has six signals: a source-synchronous clock (`RXC`/`TXC`), a control signal (`RX_CTL`/`TX_CTL`), and a four-bit data bus (`RD`/`TD`), for a total of twelve signals.
The half-duplex signals, `CRS` and `COL`, are jettisoned entirely and need to be reconstructed from the other signals if required.

<figure>
<svg viewBox="-5 -15 310 150" style="display:block;margin:auto;max-width:400px;">
  <title>RGMII Signals</title>
  <symbol id="arrow" y="-5">
    <line stroke="black" x1="5" y1="5" x2="100" y2="5"/>
    <polyline fill="black" stroke="none" points="5,2.5 5,7.5 0,5"/>
  </symbol>
  <!-- Top Level Blocks-->
  <g fill="none" stroke="black">
    <rect x="0" y="5" width="100" height="125"/>
    <rect x="200" y="5" width="100" height="125"/>
    <line x1="0" x2="100" y1="70" y2="70"/>
    <line x1="200" x2="300" y1="70" y2="70"/>
  </g>
  <g font-size="15" text-anchor="middle">
    <text x="50">MAC</text>
    <text x="250">PHY</text>
  </g>
  <g dominant-baseline="middle" font-size="15" text-anchor="middle">
    <text x="50" y="40">RX</text>
    <text x="50" y="100">TX</text>
    <text x="250" y="40">RX</text>
    <text x="250" y="100">TX</text>
  </g>
  <!-- Buses -->
  <g font-size="12">
    <!-- Receive Bus -->
    <use href="#arrow" x="100" y="20"/>
    <text x="110" y="15">RXC</text>
    <use href="#arrow" x="100" y="40"/>
    <text x="110" y="35">RX_CTL</text>
    <use href="#arrow" x="100" y="60"/>
    <text x="110" y="55">RD[3:0]</text>
    <!-- Transmit Bus -->
    <use href="#arrow" x="-200" y="-80" transform="rotate(180)"/>
    <text x="110" y="75">TXC</text>
    <use href="#arrow" x="-200" y="-100" transform="rotate(180)"/>
    <text x="110" y="95">TX_CTL</text>
    <use href="#arrow" x="-200" y="-120" transform="rotate(180)"/>
    <text x="110" y="115">TXD[3:0]</text>
  </g>
</svg>
<figcaption style="text-align:center"><abbr title="Gigabit Media Independent Interface">RGMII</abbr> Signals</figcaption>
</figure>

These signals map directly to the GMII signals.
The rising edge of the clock captures the GMII enable/valid signal (`RX_DV`/`TX_EN`) and the lower four data bits.
The falling edge of the clock captures the GMII error signal (`RX_ER`/`TX_ER`) and the upper four data bits with one caveat.
As the error signal is usually low, this would result in increased EMI and power consumption during packet transmission from the constant switching.
To reduce this, the falling edge actually holds the *exclusive-or* (XOR) of the valid and error signals (called `RXERR`/`TXERR` in the specification).

RGMII    | Rising Edge | Falling Edge
:-------:|:-----------:|:--------------:
`RX_CTL` | `RX_DV`     | `RX_DV ^ RX_ER`
`RD[3]`  | `RXD[3]`    | `RXD[7]`
`RD[2]`  | `RXD[2]`    | `RXD[6]`
`RD[1]`  | `RXD[1]`    | `RXD[5]`
`RD[0]`  | `RXD[0]`    | `RXD[4]`
{style="margin:auto;"}

When illustrated as a waveform with a center-aligned clock:

<figure>
<svg viewBox="0 0 400 120" style="display:block;margin:auto;max-width:500px;">
  <title>RGMII Gigabit Encoding</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text x="0" y="15">TXC</text>
    <text x="0" y="45">TX_CTL</text>
    <text x="0" y="75">TD[3:0]</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,24 h20 v-20 h40 v20 h40 v-20 h40 v20 h40 v-20 h40 v20 h40 v-20 h40 v20 h20"/>
    <path d="M70,54 h80 v-20 h120 v20 h80 v-20 h40"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M150,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
    <path d="M190,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
    <path d="M310,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
    <path d="M350,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M70,64 h75 l5,10 l-5,10 h-75"/>
    <path d="M230,74 l5,-10 h70 l5,10 l-5,10 h-70 l-5,-10"/>
  </g>
  <!-- Values -->
  <g dominant-baseline="middle" font-size="8" text-anchor="middle">
    <text x="110" y="75" font-size="12">XX</text>
    <text x="170" y="75">TXD[3:0]</text>
    <text x="210" y="75">TXD[7:4]</text>
    <text x="270" y="75" font-size="12">XX</text>
    <text x="330" y="75">TXD[3:0]</text>
    <text x="370" y="75">TXD[7:4]</text>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="150" y1="5" x2="150" y2="100"/>
    <line x1="230" y1="5" x2="230" y2="100"/>
    <line x1="310" y1="5" x2="310" y2="100"/>
  </g>
  <!-- Captions -->
  <g dominant-baseline="middle" font-size="12" text-anchor="middle">
    <text x="110" y="95">Idle</text>
    <text x="190" y="95">Data</text>
    <text x="270" y="95">Error</text>
    <text x="350" y="95">Control</text>
  </g>
</svg>
<figcaption style="text-align:center">RGMII Gigabit Encoding</figcaption>
</figure>

## Clocking (Clause 3.2, 3.3) {id="clocking"}

> **Important:** Timing is the single most difficult aspect of <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr>.
> There are a lot of variables and configuration options.
> Even when using off-the-shelf implementations, one needs to pay close attention to the system design, component selection, and configuration to ensure a reliable link.

All buses in RGMII are source-synchronous.
However, being <abbr title="Double Data Rate">DDR</abbr>, this makes properly meeting setup and hold timings more difficult.
There was a significant revision in RGMII version 2.0 in order to address this.

The clocks are specified as nominal 125&nbsp;MHz (8&nbsp;ns), 25&nbsp;MHz (40&nbsp;ns), and 2.5&nbsp;MHz (400&nbsp;ns) for Gigabit, 100&nbsp;Megabit, and 10&nbsp;Megabit respectively.
Tolerance is specified as the Ethernet standard of 50&nbsp;<abbr title="Parts Per Million">ppm</abbr>; however, it also permits the period to vary by up to 10% from the nominal value (e.g. &plusmn;0.8&nbsp;ns at Gigabit).
The duty cycle for Gigabit is 45% ~ 55%, widening to 40% ~ 60% for 10/100, stricter than both MII and GMII.
The later is convenient if one is doing a divide-by-five from 125 MHz in logic instead of switching clock frequencies internally.
A jitter requirement of 100&nbsp;ps was present in the original version but deleted in Version 1.2.

In the latest version of the standard, the driver on each bus (receive and transmit) provides an *Internal Delay* (RGMII-ID) to produce a center-aligned clock.
At the driver, the device should generate a minimum setup and hold of 1.2&nbsp;ns (*TsetupT*/*TholdT*).
At the receiver, the device should plan for a minimum setup and hold of 1.0&nbsp;ns (*TsetupR*/*TholdR*).
Together, this requires a length match on the PCB to within 200&nbsp;ps.
The standard also gives *nominal* values in addition to *minimum* but as these are equal to the entire half-period, it's not especially useful.

<figure>
<svg viewBox="0 0 500 120" style="display:block;margin:auto;max-width:500px;">
  <title>RGMII Version 2.0 Clocking (RGMII-ID)</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text y="15">TXC</text>
    <text y="65">TX_CTL</text>
    <text y="85">TXD[3:0]</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,24 h20 v-20 h40 v20 h40 v-20 h40 v20 h20"/>
    <path d="M330,24 h20 v-20 h40 v20 h40 v-20 h40 v20 h20"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M80,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M120,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M160,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M200,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M70,64 h5 l5,10 l-5,10 h-5"/>
    <path d="M100,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M140,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M180,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    <path d="M230,64 h-5 l-5,10 l5,10 h5"/>
  </g>
  <g transform="translate(260,0)">
    <g fill="#8F88" stroke="#4F4">
      <path d="M80,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
      <path d="M120,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
      <path d="M160,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
      <path d="M200,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
    </g>
    <g fill="#F888" stroke="#F88">
      <path d="M70,64 h5 l5,10 l-5,10 h-5"/>
      <path d="M100,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
      <path d="M140,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
      <path d="M180,74 l5,-10 h10 l5,10 l-5,10 h-10 l-5,-10"/>
      <path d="M230,64 h-5 l-5,10 l5,10 h5"/>
    </g>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <path d="M90,5 v50 M100,35 v50 M200,35 v50 M210,5 v50"/>
    <path d="M350,5 v50 M360,35 v50 M460,35 v50 M470,5 v50"/>
  </g>
  <!-- Arrows -->
  <g fill="none" stroke="black">
    <path d="M240,14 h75 M240,74 h75"/>
    <path d="M85,37.5 h-7.5 M105,37.5 h7.5"/>
    <path d="M195,52.5 h-7.5 M215,52.5 h7.5"/>
    <path d="M345,37.5 h-7.5 M365,37.5 h7.5"/>
    <path d="M455,52.5 h-7.5 M475,52.5 h7.5"/>
  </g>
  <g fill="black" stroke="none">
    <path d="M320,14 l-5,-2.5 v5 M320,74 l-5,-2.5 v5"/>
    <path d="M90,37.5 l-5,-2.5 v5 M100,37.5 l5,-2.5 v5"/>
    <path d="M200,52.5 l-5,-2.5 v5 M210,52.5 l5,-2.5 v5"/>
    <path d="M350,37.5 l-5,-2.5 v5 M360,37.5 l5,-2.5 v5"/>
    <path d="M460,52.5 l-5,-2.5 v5 M470,52.5 l5,-2.5 v5"/>
  </g>
  <!-- Dimensions -->
  <g dominant-baseline="middle" font-size="12">
    <text x="115" y="37.5">TholdT = 1.2 ns</text>
    <text x="185" y="52.5" text-anchor="end">TsetupT = 1.2 ns</text>
    <text x="375" y="37.5">TholdR = 1.0 ns</text>
    <text x="445" y="52.5" text-anchor="end">TsetupR = 1.0 ns</text>
  </g>
  <!-- Content -->
  <g dominant-baseline="middle" font-size="15" text-anchor="middle">
    <text x="110" y="75">X</text>
    <text x="150" y="75">X</text>
    <text x="190" y="75">X</text>
    <text x="370" y="75">X</text>
    <text x="410" y="75">X</text>
    <text x="450" y="75">X</text>
  </g>
  <!-- Captions -->
  <g dominant-baseline="middle" font-size="15" text-anchor="middle">
    <text x="150" y="105">MAC Output</text>
    <text x="280" y="105">PCB Routing</text>
    <text x="410" y="105">PHY Input</text>
  </g>
</svg>
<figcaption style="text-align:center">RGMII Version 2.0 Clocking (RGMII-ID)</figcaption>
</figure>

There are multiple viable options to create the delay.
Delay lines, such as Xilinx's `ODELAY`, are an option and used within Xilinx's soft cores.
The nuclear option is to simply run the internal logic faster and drive the clock and data on different cycles.
The most common technique is to emit clocks of different phase from the on-board PLL:
the clock generating `TXC` is delayed 90&deg; from that driving the data.
This guarantees the widest setup and hold timings across all operating frequencies.

Prior to version 2.0, it was specified that the bus driver would output the data edge-aligned with the clock (within &plusmn;500&nbsp;ps, *TskewT*).
However, it also specified that the receiver should expect the clock to be skewed 1.0&nbsp;ns ~ 2.6&nbsp;ns (*TskewR*), consistent with the setup and hold timings of RGMII-ID.
This requires the board designer add additional length to the clock trace relative to the control and data lines to produce the skew.
Combining the worst cases leads to a target 1.5&nbsp;ns ~ 2.0&nbsp;ns of external delay on the clock (1.8&nbsp;ns nominal), roughly a foot (30&nbsp;cm) of extra line length on a standard FR-4.

<figure>
<svg viewBox="0 0 500 120" style="display:block;margin:auto;max-width:500px;">
  <title>RGMII Version 1.3 Clocking</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text y="15">TXC</text>
    <text y="65">TX_CTL</text>
    <text y="85">TXD[3:0]</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,24 h20 v-20 h40 v20 h40 v-20 h40 v20 h20"/>
    <path d="M330,24 h35 v-20 h40 v20 h40 v-20 h40 v20 h5"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M70,64 h7.5 l5,10 l-5,10 h-7.5"/>
    <path d="M97.5,74 l5,-10 h15 l5,10 l-5,10 h-15 l-5,-10"/>
    <path d="M137.5,74 l5,-10 h15 l5,10 l-5,10 h-15 l-5,-10"/>
    <path d="M177.5,74 l5,-10 h15 l5,10 l-5,10 h-15 l-5,-10"/>
    <path d="M230,64 h-7.5 l-5,10 l5,10 h7.5"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M82.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
    <path d="M122.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
    <path d="M162.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
    <path d="M202.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
  </g>
  <g transform="translate(260,0)">
    <g fill="#8F88" stroke="#4F4">
      <path d="M70,64 h7.5 l5,10 l-5,10 h-7.5"/>
      <path d="M97.5,74 l5,-10 h15 l5,10 l-5,10 h-15 l-5,-10"/>
      <path d="M137.5,74 l5,-10 h15 l5,10 l-5,10 h-15 l-5,-10"/>
      <path d="M177.5,74 l5,-10 h15 l5,10 l-5,10 h-15 l-5,-10"/>
      <path d="M230,64 h-7.5 l-5,10 l5,10 h7.5"/>
    </g>
    <g fill="#F888" stroke="#F88">
      <path d="M82.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
      <path d="M122.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
      <path d="M162.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
      <path d="M202.5,74 l5,-10 h5 l5,10 l-5,10 h-5 l-5,-10"/>
    </g>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <path d="M90,5 v50 M97.5,35 v50 M202.5,35 v50 M210,5 v50"/>
    <path d="M357.5,35 v50 M365,5 v37.5 M462.5,35 v50 M485,5 v50"/>
  </g>
  <!-- Arrows -->
  <g fill="none" stroke="black">
    <path d="M240,14 h10 q5,0,5,-5 t5,-5 5,5 v10 q0,5,5,5 t5,-5 v-10 q0,-5,5,-5 t5,5 v10 q0,5,5,5 t5,-5 v-10 q0,-5,5,-5 t5,5 t5,5 h5"/>
    <path d="M85,37.5 h-7.5 M102.5,37.5 h7.5"/>
    <path d="M197.5,52.5 h-7.5 M215,52.5 h7.5"/>
    <path d="M240,74 h75"/>
    <path d="M352.5,37.5 h-10 M370,37.5 h10"/>
    <path d="M457.5,52.5 h-10 M490,52.5 h10"/>
  </g>
  <g fill="black" stroke="none">
    <path d="M320,14 l-5,-2.5 v5 M320,74 l-5,-2.5 v5"/>
    <path d="M90,37.5 l-5,-2.5 v5 M97.5,37.5 l5,-2.5 v5"/>
    <path d="M202.5,52.5 l-5,-2.5 v5 M210,52.5 l5,-2.5 v5"/>
    <path d="M357.5,37.5 l-5,-2.5 v5 M365,37.5 l5,-2.5 v5"/>
    <path d="M462.5,52.5 l-5,-2.5 v5 M485,52.5 l5,-2.5 v5"/>
  </g>
  <!-- Dimensions -->
  <g dominant-baseline="middle" font-size="12">
    <text x="112.5" y="37.5">TskewT &le; 0.5 ns</text>
    <text x="187.5" y="52.5" text-anchor="end">TskewT &ge; -0.5 ns</text>
    <text x="382.5" y="37.5">TskewR &ge; 1 ns</text>
    <text x="445.5" y="52.5" text-anchor="end">TskewR &le; 2.6 ns</text>
  </g>
  <!-- Captions -->
  <g dominant-baseline="middle" font-size="15" text-anchor="middle">
    <text x="150" y="105">MAC Output</text>
    <text x="280" y="105">PCB Routing</text>
    <text x="410" y="105">PHY Input</text>
  </g>
</svg>
<figcaption style="text-align:center">RGMII Version 1.3 Clocking</figcaption>
</figure>

> **Note:** Effectively all PHYs in the wild conform to RGMII Version 2.0 with an internal delay on the output clock enabled by default (RGMII-ID).
> Given all the difficulty and confusion regarding clock phasing, most will also provide a programmable internal delay for both the receive and transmit clocks, accessible through the management interface.
> This can be convenient for <abbr title="Field Programmable Gate Array">FPGA</abbr> designs, where the generation and reception of edge-aligned buses are frequently more straightforward.

### Synopsis Design Constraints (SDC) {id="constraints"}

Compared to previous incarnations of <abbr title="Media Independent Interface">xMII</abbr>, the constraints for <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> are much more complicated.
Not only do we need to deal with <abbr title="Double Data Rate">DDR</abbr> signaling, we need to also deal with the two versions of RGMII and the configuration options present in most PHYs.

First, we'll start by defining our clocks, which are the same in all configurations.
It's important to use the minimum period so that we don't miss timing at the extreme.

```tcl
# From RGMII Specification, Version 2.0
set rgmii_period_min 7.2
set rgmii_period_nom 8.0

# Output (Transmit) Clock
# TODO: Update source and division to match logic
create_generated_clock -name TXC [get_ports TXC] \
    -source [get_pins */TXC_gen/C] -divide_by 1

# Input (Receive) Clock
create_clock -name RXC -period $rgmii_period_min [get_ports RXC]
create_clock -name RXC_virt -period $rgmii_period_min
```

For output delays, it's best to formulate the constraints using the RGMII-ID (Version 2.0) model.
We define the setup and hold in terms of the *receiver* and then adjust `TXC` latency to reflect any routing mismatch or input delay configured at the PHY.
In the case of a fully complaint RGMII-ID device, this means `TXC` uncertainty is bounded at &plusmn;0.2&nbsp;ns (increasing the required *output* setup and hold to 1.2&nbsp;ns).
If we're adding external delay in keeping with RGMII Version 1.3 design guidelines, we'd set the `TXC` delay to 1.5&nbsp;ns ~ 2.1&nbsp;ns.
Additionally, if the PHY we're using has more tolerant specifications, we can update the setup and hold to reflect the device's datasheet (e.g. 0.8&nbsp;ns in the case of the [Microchip LAN8830](https://www.microchip.com/en-us/product/LAN8830)).

```tcl
# From RGMII Specification, Version 2.0
# TODO: Update to datasheet values from selected PHY.
set rgmii_setuprx 1
set rgmii_holdrx 1
# TODO: Update to reflect actual design.  These values reflect the standard.
set rgmii_txc_min -0.2
set rgmii_txc_max +0.2

# Output (Transmit) Constraints (RGMII-ID v2)
set_output_delay -clock TXC \
    -min [expr {-$rgmii_holdrx - $rgmii_txc_max}] \
    [get_ports {TX_CTL TD[*]}]
set_output_delay -clock TXC -clock_fall -add_delay \
    -min [expr {-$rgmii_holdrx - $rgmii_txc_max}] \
    [get_ports {TX_CTL TD[*]}]
set_output_delay -clock TXC \
    -max [expr {$rgmii_setuprx - $rgmii_txc_min}] \
    [get_ports {TX_CTL TD[*]}]
set_output_delay -clock TXC -clock_fall -add_delay \
    -max [expr {$rgmii_setuprx - $rgmii_txc_min}] \
    [get_ports {TX_CTL TD[*]}]
```

For input delays, it's best to stick with a formulation consistent with how the device is configured, which is almost invariably RGMII-ID (Version 2.0).
Here, setup and hold are reversed from the previous block:
we define setup and hold in terms of the *transmitter* and then adjust `RXC` latency to reflect the routing mismatch.
In the case of a fully complaint RGMII-ID device, this means `RXC` uncertainty is bounded at &plusmn;0.2&nbsp;ns as before (reducing the required *input* setup and hold to 1.0&nbsp;ns).
The integrated delay (~*Tcyc*/2) is already considered by the nature of the formulation.
If the PHY we're using has more tolerant specifications, we can update the setup and hold to reflect the device's datasheet (e.g. 1.4&nbsp;ns in the case of the [Microchip LAN8830](https://www.microchip.com/en-us/product/LAN8830)).

```tcl
# From RGMII Specification, Version 2.0
# TODO: Update to datasheet values from selected PHY.
set rgmii_setuptx 1.2
set rgmii_holdtx 1.2
# TODO: Update to reflect actual design.  These values reflect the standard.
set rgmii_rxc_min -0.2
set rgmii_rxc_max +0.2

# Input (Receive) Constraints (RGMII-ID v2)
set_input_delay -clock RXC_virt \
    -min [expr {$rgmii_holdtx - $rgmii_rxc_max}] \
    [get_ports {RX_CTL RD[*]}]
set_input_delay -clock RXC_virt -clock_fall -add_delay \
    -min [expr {$rgmii_holdtx - $rgmii_rxc_max}] \
    [get_ports {RX_CTL RD[*]}]
set_input_delay -clock RXC_virt \
    -max [expr {$rgmii_period_min / 2 - $rgmii_setuptx - $rgmii_rxc_min}] \
    [get_ports {RX_CTL RD[*]}]
set_input_delay -clock RXC_virt -clock_fall -add_delay \
    -max [expr {$rgmii_period_min / 2 - $rgmii_setuptx - $rgmii_rxc_min}] \
    [get_ports {RX_CTL RD[*]}]
```

In the case of a Version 1.3 peer, we need to define everything in terms of skew.
As we did previously, we define the skew in terms of the *transmitter* and then adjust `RXC` latency to reflect the routing mismatch.
For a fully compliant implementation, this would be the specified delay of 1.5&nbsp;ns ~ 2.1&nbsp;ns; however, in an actual design this may be absent if an internal delay is added to the input clock instead (e.g. a Xilinx `IDELAY`) or the intrinsic latency added by the clock network is sufficient.
In the later case, one might want to set the `RXC` latency to &plusmn;0.2&nbsp;ns, in keeping with the RGMII-ID routing uncertainty.

```tcl
# From RGMII Specification, Version 1.3
set rgmii_skewtx_min -0.5
set rgmii_skewtx_max +0.5
# TODO: Update to reflect actual design.  These values reflect the standard.
set rgmii_rxc_min 1.5
set rgmii_rxc_max 2.1

# Input (Receive) Constraints (RGMII v1.3)
set_input_delay -clock RXC_virt \
    -min [expr {$rgmii_period_min / 2 + $rgmii_skewtx_min - $rgmii_rxc_max}] \
    [get_ports {RX_CTL RD[*]}]
set_input_delay -clock RXC_virt -clock_fall -add_delay \
    -min [expr {$rgmii_period_min / 2 + $rgmii_skewtx_min - $rgmii_rxc_max}] \
    [get_ports {RX_CTL RD[*]}]
set_input_delay -clock RXC_virt \
    -max [expr {$rgmii_period_min / 2 + $rgmii_skewtx_max - $rgmii_rxc_min}] \
    [get_ports {RX_CTL RD[*]}]
set_input_delay -clock RXC_virt -clock_fall -add_delay \
    -max [expr {$rgmii_period_min / 2 + $rgmii_skewtx_max - $rgmii_rxc_min}] \
    [get_ports {RX_CTL RD[*]}]
```

## Control Sequences (Clause 3.4) {id="control"}

The control sequences (`RX_DV`/`TX_EN` low, `RX_ER`/`TX_ER` high) are broadly the [same as <abbr title="Gigabit Media Independent Interface">GMII</abbr>]({{<ref "2025-02-24-ethernet-gmii.md#control">}}).
The standard defines four sequences, three of which are identical to GMII:

Value | Transmit             | Receive
:----:|:---------------------|:------------------
`0E`  | Reserved             | False Carrier
`0F`  | Carrier Extend       | Carrier Extend
`1F`  | Carrier Extend Error | Carrier Extend Error
`FF`  | Reserved             | Carrier Sense
{style="margin:auto"}

Notable differences:

- The receive path will not generate `00` for inter-frame.
  This reserved unlike 802.3 Clause 35, which permits this behavior.
- *Assert LPI* (`01`) has not been assigned.
  The RGMII specification predates <abbr title="Energy Efficient Ethernet">EEE</abbr> so this code was not yet standard.
  It is expected that PHYs supporting <abbr title="Low Power Idle">LPI</abbr> will simply use the standard GMII code.
- The receive path will generate `FF` when it needs to assert `CRS` without asseting `RX_DV`.
  This is only relevant for half-duplex operation.

## In-Band Link Status (Clause 3.4) {id="inband-status"}

Unlike previous specifications for <abbr title="Media Independent Interface">xMII</abbr>, <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> includes an *optional* in-band link status.
During idle, when `RX_DV` and `RX_ER` are both low, the data lines encode the autonegotiation results.
This means that many applications can autoconfigure without needing to access the management interface, convenient for FPGA applications.

<table style="margin:auto">
<tr><th>RGMII</th><th>Function</th><th>Values</th></tr>
<tr><td rowspan="2"><code>RD[3]</code></td><td rowspan="2">Duplex</td><td><code>1</code> - Full Duplex</td></tr>
<tr><td><code>0</code> - Half Duplex</td></tr>
<tr><td rowspan="2"><code>RD[2]</code></td><td rowspan="4">Speed</td><td><code>11</code> - Reserved</td></tr>
<tr><td><code>10</code> - 1000 Mbps</td></tr>
<tr><td rowspan="2"><code>RD[1]</code></td><td><code>01</code> - 100 Mbps</td></tr>
<tr><td><code>00</code> - 10 Mbps</td></tr>
<tr><td rowspan="2"><code>RD[0]</code></td><td rowspan="2">Link</td><td><code>1</code> - Link Up</td></tr>
<tr><td><code>0</code> - Link Down</td></tr>
</table>

For example, the `RD[3:0]` lines when a Gigabit connection is active will be `0xD` (`1101`), indicating Full-Duplex, 1000 Mbps, and Link Up.
A normal 100Base-TX connection will report `0xB` (`1011`) for Full-Duplex, 100 Mbps, and Link Up.

It should be emphasized that this feature is *optional*.
The PHY is not required to provide it so be sure to consult your PHY's datasheet.
That said, I've yet to see a PHY that does not implement it.

## Tri-Mode Operation (Clause 5) {id="trimode"}

In reduced bitrates (10/100), the clock rate will reduce to the appropriate <abbr title="Medium Independent Interface">MII</abbr> clock (25&nbsp;MHz or 2.5&nbsp;MHz) and the data bus will only transmit four bits per clock cycle instead of eight.
However, unlike MII, the transmit clock remains source-synchronous and the control signals (`RX_CTL`/`TX_CTL`) remain unchanged.

The values for `TD[3:0]` and `RD[3:0]` on the falling clock edge are technically left undefined (the standard uses the word *may*) but it is near-universal to duplicate the same data on both edges if no other reason than reducing EMI and switching energy.

<figure>
<svg viewBox="0 0 400 120" style="display:block;margin:auto;max-width:500px;">
  <title>RGMII 10/100 Encoding</title>
  <!-- Labels -->
  <g dominant-baseline="middle" font-size="15">
    <text y="15">TXC</text>
    <text y="45">TX_CTL</text>
    <text y="75">TD[3:0]</text>
  </g>
  <!-- Waveforms -->
  <g fill="none" stroke="black">
    <path d="M70,24 h20 v-20 h40 v20 h40 v-20 h40 v20 h40 v-20 h40 v20 h40 v-20 h40 v20 h20"/>
    <path d="M70,54 h80 v-20 h120 v20 h80 v-20 h40"/>
  </g>
  <g fill="#8F88" stroke="#4F4">
    <path d="M150,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
    <path d="M310,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
  </g>
  <g fill="#F888" stroke="#F88">
    <path d="M70,64 h75 l5,10 l-5,10 h-75"/>
    <path d="M190,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
    <path d="M230,74 l5,-10 h70 l5,10 l-5,10 h-70 l-5,-10"/>
    <path d="M350,74 l5,-10 h30 l5,10 l-5,10 h-30 l-5,-10"/>
  </g>
  <!-- Values -->
  <g dominant-baseline="middle" font-size="12" text-anchor="middle">
    <text x="110" y="75">XX</text>
    <text x="170" y="75" font-size="8">TXD[3:0]</text>
    <text x="210" y="75">XX</text>
    <text x="270" y="75">XX</text>
    <text x="330" y="75" font-size="8">TXD[3:0]</text>
    <text x="370" y="75">XX</text>
  </g>
  <!-- Divisions -->
  <g stroke="black" stroke-dasharray="3,3">
    <line x1="150" y1="5" x2="150" y2="100"/>
    <line x1="230" y1="5" x2="230" y2="100"/>
    <line x1="310" y1="5" x2="310" y2="100"/>
  </g>
  <!-- Captions -->
  <g dominant-baseline="middle" font-size="12" text-anchor="middle">
    <text x="110" y="95">Idle</text>
    <text x="190" y="95">Data</text>
    <text x="270" y="95">Error</text>
    <text x="350" y="95">Control</text>
  </g>
</svg>
<figcaption style="text-align:center">RGMII 10/100 Encoding</figcaption>
</figure>

When shifting speeds (e.g. in response to <a href="#inband-status">in-band status</a>), it is important that the <abbr title="Media Access Controller">MAC</abbr> hold `TX_CTL` low until `TXC` has been established at the correct clock speed.
The PHY will do the same with `RX_CTL` and `RXC`.
While stretching the high or low periods is permissible, the introduction of clock glitches is not.

It is expected that the <a href="#control">control sequences</a> are also truncated to four bits, consistent with [MII]({{<ref "2025-02-14-ethernet-mii.md#control">}}), but this is not *explicitly* stated in the standard nor is a list of updated control sequences provided.
This is the position taken by PHYs such as the [Microchip LAN8830](https://www.microchip.com/en-us/product/LAN8830).

## Crossover

Crossover in this context refers to connecting two devices of the same class (PHY or <abbr title="Media Access Controller">MAC</abbr>) directly.
For example, connecting the TX of one <abbr>MAC</abbr> directly to the RX of a second <abbr>MAC</abbr> without an intervening PHY, or using a pair of PHYs as a media converter.

As both sides of the link are source-synchronous and largely identical in their operation, direct crossover is broadly compatible.
The only complication would be possible truncation of the preamble in a PHY-to-PHY crossover.
There are no expected complications in a MAC-to-MAC crossover.

## Energy Efficient Ethernet {id="eee"}

The <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> specification predates *Energy Efficient Ethernet* (<abbr>EEE</abbr>).
As such, guidance is not covered in the official specification.
It is expected that it will largely follow the [rules of GMII]({{<ref "2025-02-24-ethernet-gmii.md#eee">}}) (including clock stoppage); however, one should consult their PHY datasheet for more specific guidance.

The [Microchip LAN8830](https://www.microchip.com/en-us/product/LAN8830), for example, uses `01` for Gigabit *Assert LPI* (consistent with GMII) and `11` for 100&nbsp;Megabit *Assert LPI* (consistent with MII's four-bit encoding).
It additionally supports the suspension of `TXC` after nine clock pulses, as with GMII and unlike [MII]({{<ref "2025-02-14-ethernet-mii.md#eee">}}).
However, as a consideration for <abbr title="Double Data Rate">DDR</abbr> signaling, it does not continue to drive (or expect) *Assert LPI* while the clocks are halted.
Instead, the data lines are typically zeroed until resuming ordinary idle.
It will, however, drive *Assert LPI* for one cycle on the receive bus when the peer leaves LPI, consistent with GMII.

## Half-Duplex (Clause 3.4.2) {id="duplex"}

Half-duplex is much the same as [<abbr title="Media Independent Interface">MII</abbr>]({{<ref "2025-02-14-ethernet-mii.md#duplex">}}) and [<abbr title="Gigabit Media Independent Interface">GMII</abbr>]({{<ref "2025-02-24-ethernet-gmii.md#duplex">}}).
The primary difference is that the control signals, `CRS` and `COL`, need to be derived from the in-band information.

*Carrier Sense*, `CRS`, is asserted when either of these two conditions are true:

1. `RX_DV` is asserted
2. `RX_ER` is asserted and `RXD[7:0]` contains one of the following values:
   - *False Carrier*, `0E` (Gigabit) or `E` (10/100&nbsp;Mbps)
   - *Carrier Extend*, `0F` (Gigabit Only)
   - *Carrier Extend Error*, `1F` (Gigabit Only)
   - *Carrier Sense*, `FF` (Gigabit) or `F` (10/100&nbsp;Mbps)

*Collision Detected*, `COL`, is asserted when both of the following conditions are true:

1. *Carrier Sense*, `CRS`, is asserted
2. *Transmit Enable*, `TX_EN`, is asserted

While not covered by Clause 3.4.2, it is assumed that (2) should also include the transmission of *Carrier Extend* and *Carrier Extend Error*.
However, this is rather academic as it only applies to the broadly nonexistent Gigabit Ethernet.

Like the original version of <abbr title="Reduced Media Independent Interface">RMII</abbr> and unlike RMII 1.2, there is no mechanism to drop *Carrier Sense* prior to clocking the last byte of a packet.

## Reduced Ten Bit Interface (Clause 3) {id="rtbi"}

[As with <abbr title="Gigabit Media Independent Interface">GMII</abbr>]({{<ref "2025-02-24-ethernet-gmii.md#tbi">}}), <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> addresses the *Ten Bit Interface* (<abbr>TBI</abbr>) for transfer of the 1000Base-X <abbr title="Physical Coding Sublayer">PCS</abbr>.
However, this encoding is distinct from a direct mapping of GMII.
Instead, the control pins (`RX_CTL`/`TX_CTL`) become the fifth bit of the data bus and is clocked directly.

RTBI     | Rising Edge | Falling Edge
:-------:|:-----------:|:------------:
`RX_CTL` | `RXD[4]`    | `RXD[9]`
`RD[3]`  | `RXD[3]`    | `RXD[8]`
`RD[2]`  | `RXD[2]`    | `RXD[7]`
`RD[1]`  | `RXD[1]`    | `RXD[6]`
`RD[0]`  | `RXD[0]`    | `RXD[5]`
{style="margin:auto;margin-bottom:1em;"}
