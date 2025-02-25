---
date: 2024-10-08T23:25:00-0700
title: "Ethernet: Fundamentals"
series: ethernet
series_weight: 100
slug: ethernet-intro
tags:
  - embedded
  - ethernet
  - hardware
  - network
---

Much of my recent professional development has focused on Ethernet, making it a convenient target for technical essays.
Unlike much of the Internet, this series of essays will focus on practical implementation of Ethernet from an FPGA or ASIC perspective.
This means the necessary waveforms and encodings to generate ethernet packets when directly connected to a PHY or medium.

The essays will be making extensive references to IEEE 802.3-2022 and every effort will be made to specify the exact clauses for further research by the reader.
I will not be using the amendment names (e.g. 802.3z for Gigabit Ethernet) because they are not not useful for finding content within the actual standard and any given clause may have been modified by multiple amendments.

In this first essay, the focus will be on the fundamentals of Ethernet.
Much of the information will be conceptual but referenced repeatedly when discussing specific protocols.

> **Note:** The most recent version of the 802 standards are available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68) at no cost.
> It is highly advised that anyone working with Ethernet download a copy of 802.3 (Wired Ethernet).

## Architecture (Clause 1.1)

Before we start diving into the specifics, it's useful to get a model for visualizing the components of Ethernet.
When discussing networking, one frequently starts with the OSI model but given that it's based on a *software* model of networking, it's woefully inadequate for describing the hardware.
It simply brushes everything into a single box called "Physical Layer".
Compare that to <abbr title="HyperText Transfer Protocol">HTTP</abbr>, which gets smeared out over the top three layers despite having a fraction of the complexity.

<figure>
<svg viewBox="-5 -5 510 250" style="display:block;margin:auto;max-width:500px;">
  <title>Basic Ethernet Layer Model</title>
  <!-- Outlines -->
  <g fill="none" stroke="black">
    <!-- OSI Model -->
    <rect width="150" height="30"/>
    <rect width="150" height="30" y="30"/>
    <rect width="150" height="30" y="60"/>
    <rect width="150" height="30" y="90"/>
    <rect width="150" height="30" y="120"/>
    <rect width="150" height="30" y="150"/>
    <rect width="150" height="30" y="180"/>
    <!-- Lines -->
    <g stroke-dasharray="3,3">
      <line x1="150" y1="150" x2="200" y2="0"/>
      <line x1="150" y1="180" x2="200" y2="60"/>
      <line x1="150" y1="210" x2="225" y2="210"/>
    </g>
    <!-- Ethernet Model -->
    <rect x="200" width="300" height="30"/>
    <rect x="200" width="300" height="30" y="30"/>
    <rect x="225" width="250" height="30" y="60"/>
    <rect x="340" width="20" height="30" y="90"/>
    <rect x="300" width="100" height="20" y="120"/>
    <rect x="300" width="100" height="20" y="140"/>
    <rect x="300" width="100" height="20" y="160"/>
    <rect x="340" width="20" height="30" y="180"/>
    <rect x="225" width="250" height="30" y="210"/>
    <!-- Pointers -->
    <polyline points="390,109 385,105 390,101"/>
    <line x1="386" y1="105" x2="415" y2="105"/>
    <path d="M 405,120 a 5 5 0 0 1 5 5 v 20 a 5 5 0 0 0 5 5 a 5 5 0 0 0 -5 5 v 20 a 5 5 0 0 1 -5 5"/>
    <polyline points="390,199 385,195 390,191"/>
    <line x1="386" y1="195" x2="415" y2="195"/>
  </g>
  <!-- Labels -->
  <g dominant-baseline="central" text-anchor="middle">
    <!-- OSI Model -->
    <text x="75" y="15">Application</text>
    <text x="75" y="45">Presentation</text>
    <text x="75" y="75">Session</text>
    <text x="75" y="105">Transport</text>
    <text x="75" y="135">Network</text>
    <text x="75" y="165">Data Link</text>
    <text x="75" y="195">Physical</text>
    <!-- Ethernet Model -->
    <text x="350" y="15">LLC - Logical Link Control</text>
    <text x="350" y="45">MAC - Media Access Controller</text>
    <text x="350" y="75">Reconciliation</text>
    <text x="435" y="105">xMII</text>
    <g font-size="15px">
      <text x="350" y="130">PCS</text>
      <text x="350" y="150">PMA</text>
      <text x="350" y="170">PMD</text>
    </g>
    <text x="435" y="150">PHY</text>
    <text x="435" y="195">MDI</text>
    <text x="350" y="225">Media</text>
  </g>
</svg>
<figcaption style="text-align:center">Mapping of Ethernet to the OSI Networking Model</figcaption>
</figure>

For 802.3, we largely concern ourselves with the Physical Layer (Layer 1) and the lower half of the Data Link Layer (Layer 2).
For most people working with embedded systems, this consists of the Media Access Controller (<abbr>MAC</abbr>) in Layer 2 and the <abbr title="Physical Layer Device">PHY</abbr> comprising most of Layer 1.
These components typically communicate using some variant of the Media Independent Interface (<abbr>xMII</abbr>) and the <abbr>PHY</abbr> interfaces with the physical medium using a Medium Dependent Interface (<abbr>MDI</abbr>).
The <abbr>MDI</abbr> and medium roughly corresponds to what people think of as "Ethernet", e.g. 100Base-TX, 1000Base-T, 10GBase-SR, etc.

The PHY itself contains three sublayers:
- The Physical Coding Sublayer (<abbr>PCS</abbr>) is responsible for converting the generic encoding of <abbr>xMII</abbr> into the actual encoding of the medium.
- The Physical Medium Dependent (<abbr>PMD</abbr>) sublayer is responsible for directly interfacing with the medium, which can be the <abbr title="Analog-To-Digital Converter">ADC</abbr>s and <abbr title="Digital-To-Analog Converter">DAC</abbr>s of a 1000BaseT transceiver, or the laser diode and photodiode of a fiber transceiver.
- The Physical Medium Attachment (<abbr>PMA</abbr>) sublayer glues the two layers together, containing serializers, deserializers, clock recovery, and other logic.

Older standards, such as 10Base-T, have a different breakdown and additional sublayers may appear in more sophisticated circumstances but this is fairly consistent for modern standards.

The original Media Independent Interface was introduced with Fast Ethernet (100 Megabit) in Clause 22, where it was intended as a standard interface between Line Replaceable Units (LRU) but this usage is generally extinct.
Today, it is primarily used as a chip-to-chip or on-chip interface.
Each subsequent Ethernet revision tends to introduce a new variant of <abbr>xMII</abbr> and many of the dominant interfaces are external to the 802.3 process.

The split between a processor-based MAC and a discrete PHY chip breaks down when considering higher-speed protocols like 10 Gigabit.
An <abbr title="Small Form-factor Pluggable">SFP</abbr> module, for example, contains only the <abbr>PMD</abbr>.
The <abbr>PCS</abbr> and <abbr>PMA</abbr> sublayers are usually colocated with the <abbr>MAC</abbr> on the processor.

## Endian

Ethernet has a confusing concept of endian.

The physical interfaces group the bitstream into bundles of different sizes, from <abbr title="Reduced Media Independent Interface">RMII</abbr> with two bits to 10GBase-R with 64 bits.
Within each bundle, the least significant bit is transmitted first (i.e. little endian).
For example, the byte `0x83` would be transmitted `1 1 0 0 0 0 0 1` bit-at-a-time or loaded onto <abbr>RMII</abbr> as `11 00 00 10`.
This extends to computation and transmission of the <abbr title="Frame Check Sequence">FCS</abbr> (discussed later).

However, protocol fields such as sizes, types, and addresses are generally loaded most-significant byte first (i.e. big endian).
For example, an Ethernet frame of length `0x157` would load its length field as the bytes `01 57`, which would then be presented to <abbr title="Media Independent Interface">MII</abbr> nibble-at-a-time as `1 0 7 5` due to the treatment of endian at the byte level.

This discrepancy can sometimes lead to confusion between numerical representation and transmit order.
I will endeavour to provide explicit examples in these cases to help clear the ambiguity.

## Ethernet Packets and Frames (Clause 3)

In 802.3 parlance, an Ethernet *packet* is the entire structure from the preamble through the FCS and any extension while the Ethernet *frame* begins with the destination address and ends with the <abbr title="Frame Check Sequence">FCS</abbr>.

To assist with verification, an example *packet* containing an <abbr title="Address Resolution Protocol">ARP</abbr> *frame* captured from a local network is illustrated.
To minimize the probability of error, this packet was captured off my home network using a [Xilinx <abbr title="Integrated Logic Analyzer">ILA</abbr>](https://www.xilinx.com/products/intellectual-property/ila.html) attached to an <abbr title="Reduced Gigabit Media Independent Interface">RGMII</abbr> <abbr title="Physical Layer Device">PHY</abbr>.
The <abbr title="Cyclic Redundancy Check">CRC</abbr> was independently verified and the packet is presented unmodified (excluding a simulated extension).

<p style="font-family: monospace;"><span
 style="background: #F888; border: 1px solid #F88; border-radius: 2px;" title="Preamble"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">55 55 55 55 55 55 55</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #F888; border: 1px solid #F88; border-radius: 2px;" title="Start Frame Delimiter"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">D5</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Destination Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">FF FF FF FF FF FF</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Source Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">F8 B7 E2 04 0C 19</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FE48; border: 1px solid #FD0; border-radius: 2px;" title="Type/Length"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">08 06</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Client Data/Envelope"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 01 08 00 06 04 00 01 F8 B7 E2 04 0C 19 44 0F 43 F1 00 00 00 00 00 00 44 0F 43 FE</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #88F8; border: 1px solid #88F; border-radius: 2px;" title="Padding"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px;" title="Frame Check Sequence"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">69 70 39 BB</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8888; border: 1px solid #888; border-radius: 2px;" title="Extension"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">/R/R/</span></span></p>

### Preamble (Clause 3.2.1)

Example: <code style="background: #F888; border: 1px solid #F88; border-radius: 2px; padding: 0 4px;">55 55 55 55 55 55 55</code>

In communication systems, the purpose of a preamble is to allow the receiver to synchronize with the transmitter.
It provides a regular pattern of repeating symbols to extract a timing reference, perform channel equalization, or complete any other task necessary for reliable reception.
However, with the introduction of Fast Ethernet (100 Megabit), modern protocols transmit continuously in full duplex with the packet delimitated by control words, making the preamble largely vestigial.

The standard preamble is seven bytes of `0x55` (`10101010` in transmit order); however, there are conditions under which the transmitter may intentionally adjust the length of this field.
As a result, receivers should not assume that they will receive exactly seven bytes.
The specific protocol will provide certain guarantees and implementations need to be careful they do not make incorrect assumptions.

### Start Frame Delimiter (Clause 3.2.2)

Example: <code style="background: #F888; border: 1px solid #F88; border-radius: 2px; padding: 0 4px;">D5</code>

The last byte of the preamble sequence is the Start Frame Delimiter (SFD), which has the sequence `10101011` in transmit order (`0xD5` numerically).
This immediately proceeds the first byte of the Ethernet *frame*.

### Destination Address (Clause 3.2.4)

Example: <code style="background: #FC88; border: 1px solid #FC0; border-radius: 2px; padding: 0 4px;">FF FF FF FF FF FF</code>

The first 48 bits (six bytes) of the Ethernet *frame* is the destination address.
An Ethernet address, formally an EUI-48 address, has an internal structure that permits the hierarchial delegation of responsibility for assigning addresses but that is largely irrelevant from the perspective of hardware implementation.
Instead, we only care whether the address identifies an individual host or a group.

The least significant bit of the first byte (i.e. the first bit transmitted) is the individual/group bit.
When set, the address is treated as a group (multicast) address.
All ones, as in the above example, represents the standard broadcast address.
Most switches treat all group addresses as broadcast addresses but techniques such as <abbr title="Internet Group Management Protocol">IGMP</abbr> snooping or a simple static configuration can be used to reduce the scope of traffic in a multicast-heavy environment.

### Source Address (Clause 3.2.5)

Example: <code style="background: #FC88; border: 1px solid #FC0; border-radius: 2px; padding: 0 4px;">F8 B7 E2 04 0C 19</code>

The next 48 bits of the frame is the address of the transmitting host.
Unlike the destination address, this should always be an individual address.

### Length/Type (Clause 3.2.6)

Example: <code style="background: #FE48; border: 1px solid #FD0; border-radius: 2px; padding: 0 4px;">08 06</code>

The next 16 bits of the frame can be interpreted as either the length or the type of the frame.
This is sent most significant byte first (although the bit ordering within each byte is still little endian).

1. When 1500 or less (`0x05DC`), it is to be interpreted as the number of bytes in the Client Data field, excluding any padding.
   For example, a payload of 47 bytes (hex `0x002F`) will be transmitted as `00 2F` and include one byte of padding due to the minimum *frame* size of 64 bytes.
2. When 1536 or more (`0x0600`), it is to be interpreted as the *EtherType*.
   For example, the <abbr title="Address Resolution Protocol">ARP</abbr> packet in the example has an EtherType of `0x0806` and will be transmitted as `08 06`.
3. Values in between these two are invalid and should be discarded.

**Note:** There is no mechanism to indicate the length of a jumbo frame.

In practice, lengths are not commonly seen in modern Ethernet.
Instead, standard type values are used (e.g. the `0x0806` in our example represents the <abbr title="Address Resolution Protocol">ARP</abbr> protocol for mapping between IPv4 and Ethernet addresses).
The set of standard values, formally EtherType, are [registered with the IEEE](https://regauth.standards.ieee.org/standards-ra-web/pub/view.html#registries) but a more accessible list of common protocols is [maintained at Wikipedia](https://en.wikipedia.org/wiki/EtherType#Values).

### Client Data (Clause 3.2.7) and Envelope

Example: <code style="background: #8F88; border: 1px solid #4F4; border-radius: 2px; padding: 0 4px;">00 01 08 00 06 04 ...</code>

Between the Length/Type and the FCS is the client data (payload) of the frame.
There are no restrictions on what data this field can contain.

The standard maximum length of the payload is 1500 bytes (for a frame of 1518 bytes) but can be exceeded in one of two ways:

1. An *envelope* frame.  Q-Tagging (802.1Q Clause 9) is the most common example of this, but a variety of standards exist to encapsulate customer data as it transitions a network.
   While a Q-Tag only extends the frame by four bytes (to a maximum of 1522 bytes), other protocols can extend it considerably longer.
   Clause 3.2.7 recommends a maximum of 1982 for the general handling of envelopes (for a total *frame* size of 2000 bytes) but the client data is still limited to 1500 bytes.
2. Jumbo frames, those with a client payload in excess of 1500 bytes, are *not* defined by the 802.3 standard and are, in effect, a nonstandard extension.

**Note:** The ability of the FCS to detect errors decreases as the frame increases in length.
The detection of four bit errors is only guaranteed with a 372 byte frame and three bit errors only being guaranteed up to 11,450 bytes.
Errors can sometimes be detected even if these limits are exceeded but it is dependent on the specific nature of the error sequence.
It is recommended that the higher level protocol (e.g. <abbr title="Internet Protocol">IP</abbr> or <abbr title="Transmission Control Protocol">TCP</abbr>) provide additional error detection capabilities.
Some variants of Ethernet embed Forward Error Correction (<abbr>FEC</abbr>) into the stream to provide further protection.

**Note:** Longer packets require stricter tolerances on the reference clocks and buffering of both peers.
This can become acute for interfaces such as <abbr title="Serial Gigabit Media Independent Interface">SGMII</abbr> where the recovered clock cannot be used for PHY-MAC communications.
Even the standard <abbr title="Maximum Transfer Unit">MTU</abbr> at 10Base-T with standard oscillator tolerances can exceed the buffering capabilities of some <abbr title="Multi-Gigabit Transceivers">MGTs</abbr>.

**Note:** Due to the lack of explicit delimiters in the framing structure, it's possible that additional bytes may be appended to the payload at the receiver interface, such as padding and the <abbr>FCS</abbr>, when the frame uses an EtherType instead of an explicit length.

### Padding (Clause 3.2.8)

Example: <code style="background: #88F8; border: 1px solid #88F; border-radius: 2px; padding: 0 4px;">00 00 00 00 ...</code>

The Ethernet frame must be a minimum of 64 bytes, padded to this minimum by the <abbr>MAC</abbr> if sufficient bits are not included.
The standard leaves the content as explicitly unspecified (Clause 4.2.3.3) but it is near-universal to zero-fill for security reasons.

If a received frame is shorter than this minimum, it is classified as a *runt frame*.
These are frequently the result of collisions (in case of half-duplex operation) or buffer underruns.
They can also erroneously occur in some switch implementations when 802.1Q tags are removed.
Per Clause 4.2.4.2.2, runt frames are to be discarded.

### Frame Check Sequence (Clause 3.2.9)

Example: <code style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px; padding: 0 4px;">69 70 39 BB</code>

At the end of the Ethernet frame is the 32-bit Frame Check Sequence (FCS).
This is a <abbr title="Cyclic Redundancy Check">CRC</abbr> with polynomial:

<math display="block">
<mrow><mi>G</mi><mo>(</mo><mi>x</mi><mo>)</mo></mrow>
<mo>=</mo><msup><mi>x</mi><mn>32</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>26</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>23</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>22</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>16</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>12</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>11</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>10</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>8</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>7</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>5</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>4</mn></msup>
<mo>+</mo><msup><mi>x</mi><mn>2</mn></msup>
<mo>+</mo><mi>x</mi><mo>+</mo><mn>1</mn>
</math>

The shift register is initialized with all ones and the entire frame, starting with the destination address and continuing through the end of the padding, are shifted through in transmit order.
The final register value is inverted before being shifted out to form the last field of the packet.

A common mistake when implementing a <abbr>CRC</abbr> is to view it like a hash: as a function that operates on bytes (or words) at a time.
This leads to confusing nomenclature about bit reversals or reflections, especially for little endian protocols like Ethernet.
Instead, it's best to understand that the <abbr>CRC</abbr> operates bit-at-a-time and shift the register in the same direction as the underlying protocol.

This can be implemented in C as:

```c
#define CRC_POLY UINT32_C(0xEDB88320)

uint32_t crc_ether(const uint8_t *data, size_t len) {
    uint32_t accum = ~UINT32_C(0);
    for (size_t n = 0; n < len; ++len) {
        accum ^= data[n];
        for (int b = 0; b < 8; ++b) {
            if (accum & 1) {
                accum = (accum >> 1) ^ CRC_POLY;
            } else {
                accum >>= 1;
            }
        }
    }
    return ~accum;
}
```

The final value of `crc_ether(data, len)` would then be shifted out least significant byte first without any bit reversals.

On reception, Clause 4.2.4.1.2 states that the receiver is to compute the <abbr>FCS</abbr> in the same manner as transmission and compare it to the value stored in the frame.
While this works, a more common implementation is to send the entire frame, including the <abbr>FCS</abbr>, through the <abbr>CRC</abbr> computation.
This will generate the same residual (`0x2144DF1C` or `1C DF 44 21` in transmit order after inversion) for all valid frames.

**Note:** The example C implementation is focused on algorithmic clarity, not performance, and largely models how it will be approached in HDL.
The lookup tables common in software implementations are not characteristic of hardware implementations.
Many HDL examples of <abbr>CRC</abbr> in the wild have the XOR tree explicitly spelled out.
This is unnecessary as modern synthesis engines can handle the loop unrolling and logic folding without issue.

### Extension (Clause 3.2.10)

Example: <code style="background: #8888; border: 1px solid #888; border-radius: 2px; padding: 0 4px;">/R/R/</code>

The minimum length of a packet was originally designed to exceed the round-trip time of a packet at the maximum segment length in order to facilitate the detection of collisions.
Given the 100 meter maximum segment length specified in 802.3, this corresponds roughly to 10 bits at 10Base-T and 100 bits at 100Base-TX.

However, for 1000Base-T, this increases to 1000 bits (125 bytes), nearly double the minimum length of an Ethernet frame (64 bytes).
This means that a station transmitting the minimum length frame may produce collisions it is unable to detect.
1000Base-T addressed this deficiency by introducing carrier extension, a control word that extends the packet without extending the length of the frame.

As half-duplex 1000Base-T was never commercially available, it is rarely implemented in real hardware.
However, it still exists in a vestigial form in 1000Base-X (Clause 36) and derived interfaces, represented by the token `/R/`.

### Interpacket Gap (Clause 4.2.3.2.2)

Commonly known as the *interframe gap*, the IPG is a period between packets where the medium is idle to provide a buffer for the sublayers forming the physical interface.
This includes the insertion of delimiters to mark the extends of a packet, absorbing the difference in reference frequency between stations, and aligning the frame as required by the underlying encoding.
As a result, the <abbr>IPG</abbr> at the receiving <abbr>MAC</abbr> may differ from what was generated by the transmitter.

The standard <abbr>IPG</abbr> is a minimum of 96 bit periods (12 bytes) and this applies to all normal forms of Ethernet.
Some exotic variants of Ethernet (e.g. those involving SONET or SDH) may have more complex requirements for the interpacket gap.

## Duplex (Clause 4.2.3.2, Annex 4A)

Most modern variants of Ethernet are full-duplex, providing a point-to-point link between two hosts with independent channels in each direction.
Under these conditions, the two hosts can transmit continuously without consideration for the other's activities.
In this mode, the transmit process can begin once data is available from the client and the minimum interpacket gap has been honored.

### Half Duplex (Clause 4.2.3.2)

Older implementations and some specialty variants, such as 10Base-T1S, are based on the concept of a shared medium which is exclusively held by one transmitter at a time.
With exception to 10Base-T1S, this implemented through an algorithm known as <abbr title="Carrier Sense Multiple Access with Collision Detection">CSMA/CD</abbr>.
While largely extinct in the wild, half-duplex mode can still be entered when autonegotiation is disabled or misconfigured.

Failure to provide even a rudimentary implementation of the logic (e.g. *carrier sense*) can lead to severe communication failures when the peer attempts to engage in collision recovery.
The specifics of <abbr>CSMA/CD</abbr> will be discussed in the essays describing each protocol.

### Full Duplex (Annex 4A)

With the near-complete extinction of half duplex, a simplified version of the <abbr title="Media Access Controller">MAC</abbr> specification is provided in Annex 4A, which eliminates all mentions to half duplex operation.

Under Clause 4 and the original definitions of <abbr title="Media Independent Interface">MII</abbr>, the *carrier sense* and *collision* signals becomes *undefined* under full duplex operation.
Most commercial <abbr title="Physical Layer Device">PHY</abbr>s simply continue to operate these signals unchanged between the two modes.
However, Clause 4A allows the option to repurpose them.

There are conditions under which the medium is not ready for transmission, such as when leaving <abbr title="Low Power Idle">LPI</abbr>.
In these cases, the PHY may use the *carrier sense* signal to request deference from the MAC until the situation is resolved.
This is described in Clause 4A.2.3.2.1 and largely amounts to implementing the collision avoidance component of the half duplex logic.
It should be emphasized that this usage of *carrier sense* is not commonly supported in commercial <abbr>PHY</abbr>s and using it on such devices may result in significant transmission delays.

## Autonegotiation

Many Ethernet variants support autonegotiation and it's broadly implemented in the same way:
the PHYs will exchange words describing their capabilities and the link configures itself based on the shared subset.

The specifics of how autonegotiation is implemented and what capabilities it can describe differs significantly between protocols:
For twisted pair (Clause 28), this is a sublayer that sits below the <abbr>PMD</abbr> and exchanges a supported list of speeds.
Whereas for optical standards (e.g. 1000Base-X, Clause 37), autonegotiation is part of the <abbr>PCS</abbr>, indicating duplex and flow control support in addition to fault reporting but speed is fixed.

The specifics of autonegotiation will be presented in the protocol-specific essays.

## Q-Tagging (802.1Q Clause 9)

As mentioned in the Client Data section, the user payload can be wrapped in an envelope for special processing by switches and networking equipment between the source and its destination.
The most common envelope seen in the wild is the Customer VLAN Tag (or C-TAG) described in 802.1Q Clause 9.

The presence of a C-TAG is identified by the Tag Protocol Identifier (<abbr>TPID</abbr>) `0x8100` (`81 00` in transmit order) in place of the EtherType.
The C-TAG extends the frame by four bytes to provide the following additional information about a packet, known as the Tag Control Information (<abbr>TCI</abbr>):

- Priority Code Point (<abbr>PCP</abbr>).
  There are eight priorities identified by numeric value (zero through seven) with zero are the default priority.
  Priorities are mostly in numeric order with seven as the highest priority and *one* as the lowest: 1 0 2 3 4 5 6 7.
  Many networking stacks will synchronize this with the <abbr title="Differentiated Services Code Point">DSCP</abbr> in an <abbr title="Internet Protocol">IP</abbr> packet.
- Drop Eligible Indicator (<abbr>DEI</abbr>).
  As a queue reaches capacity, it may need to discard packets.
  Packets with <abbr>DEI</abbr> are discarded in preference to packets without <abbr>DEI</abbr> set.
- VLAN Identifier (<abbr>VID</abbr>).
  The values 1 through 4094 can be used to specify the target VLAN.
  A zero indicates that no VLAN is specified, identical to the absence of a C-TAG except for the effects of the <abbr>PCP</abbr> and <abbr>DEI</abbr>.
  The maximum value, 4095, is reserved for the switch.

Together, these are inserted between the source address and the EtherType, encoded with the following bitfield (bytes are transmitted bit one first):

<figure>
<svg viewBox="0 0 660 60" style="display:block;margin:auto;"
     dominant-baseline="central" font-size="15px" text-anchor="middle">
  <title>Encoding of 802.1Q C-TAG</title>
  <symbol id="byte" width="170" height="60">
    <!-- Bit Boundaries -->
    <g stroke="black">
      <line x1="20" y1="25" x2="20" y2="40"/>
      <line x1="40" y1="25" x2="40" y2="40"/>
      <line x1="60" y1="25" x2="60" y2="40"/>
      <line x1="80" y1="25" x2="80" y2="40"/>
      <line x1="100" y1="25" x2="100" y2="40"/>
      <line x1="120" y1="25" x2="120" y2="40"/>
      <line x1="140" y1="25" x2="140" y2="40"/>
    </g>
    <!-- Bit Labels -->
    <text x="10" y="50">8</text>
    <text x="30" y="50">7</text>
    <text x="50" y="50">6</text>
    <text x="70" y="50">5</text>
    <text x="90" y="50">4</text>
    <text x="110" y="50">3</text>
    <text x="130" y="50">2</text>
    <text x="150" y="50">1</text>
  </symbol>
  <!-- Outlines -->
  <g stroke="black">
    <!-- Fields -->
    <rect x="10" y="5" width="320" height="35" fill="#F848"/>
    <rect x="330" y="5" width="60" height="35" fill="#FC88"/>
    <rect x="390" y="5" width="20" height="35" fill="#FE48"/>
    <rect x="410" y="5" width="240" height="35" fill="#8F88"/>
    <!-- Byte Boundaries -->
    <g stroke-dasharray="3,3">
      <line x1="170" x2="170" y2="50"/>
      <line x1="330" x2="330" y2="50"/>
      <line x1="490" x2="490" y2="50"/>
    </g>
  </g>
  <!-- Labels -->
  <text x="170" y="15">TPID</text>
  <text x="360" y="15">PCP</text>
  <text transform="translate(400,22.5) rotate(90)">DEI</text>
  <text x="530" y="15">VID</text>
  <!-- Byte Outlines -->
  <line x1="10" y1="0" x2="10" y2="50"/>
  <line x1="10" y1="5" x2="650" y2="5"/>
  <use href="#byte" x="10"/>
  <use href="#byte" x="170"/>
  <use href="#byte" x="330"/>
  <use href="#byte" x="490"/>
  <line x1="10" y1="40" x2="650" y2="40"/>
</svg>
<figcaption style="text-align:center">Encoding of 802.1Q C-TAG</figcaption>
</figure>

If we start with our original example frame:

<p style="font-family: monospace;"><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Destination Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">FF FF FF FF FF FF</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Source Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">F8 B7 E2 04 0C 19</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FE48; border: 1px solid #FD0; border-radius: 2px;" title="Type/Length"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">08 06</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Client Data/Envelope"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 01 08 00 06 04 00 01 F8 B7 E2 04 0C 19 44 0F 43 F1 00 00 00 00 00 00 44 0F 43 FE</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #88F8; border: 1px solid #88F; border-radius: 2px;" title="Padding"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px;" title="Frame Check Sequence"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">69 70 39 BB</span></span></p>

We can place it on VLAN 24 at default priority by adding the C-TAG:

<p style="font-family: monospace;"><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Destination Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">FF FF FF FF FF FF</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Source Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">F8 B7 E2 04 0C 19</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #F848; border: 1px solid #F80; border-radius: 2px;" title="Tag Protocol Identifier"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">81 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #F848; border: 1px solid #F80; border-radius: 2px;" title="Tag Control Information"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 18</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FE48; border: 1px solid #FD0; border-radius: 2px;" title="Type/Length"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">08 06</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Client Data/Envelope"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 01 08 00 06 04 00 01 F8 B7 E2 04 0C 19 44 0F 43 F1 00 00 00 00 00 00 44 0F 43 FE</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #88F8; border: 1px solid #88F; border-radius: 2px;" title="Padding"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 00 00 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px;" title="Frame Check Sequence"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">79 C4 55 07</span></span></p>

Alternatively, we can drop its priority and make it drop eligible, but leave it on the default VLAN:

<p style="font-family: monospace;"><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Destination Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">FF FF FF FF FF FF</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Source Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">F8 B7 E2 04 0C 19</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #F848; border: 1px solid #F80; border-radius: 2px;" title="Tag Protocol Identifier"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">81 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #F848; border: 1px solid #F80; border-radius: 2px;" title="Tag Control Information"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">30 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FE48; border: 1px solid #FD0; border-radius: 2px;" title="Type/Length"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">08 06</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Client Data/Envelope"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 01 08 00 06 04 00 01 F8 B7 E2 04 0C 19 44 0F 43 F1 00 00 00 00 00 00 44 0F 43 FE</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #88F8; border: 1px solid #88F; border-radius: 2px;" title="Padding"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 00 00 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px;" title="Frame Check Sequence"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">8D D0 E8 4A</span></span></p>

As with any envelope, this can also extend the frame past the standard <abbr title="Maximum Transmit Unit">MTU</abbr>.
A packet at the standard <abbr>MTU</abbr> of 1500 would have its frame increased from 1518 to 1522 bytes after the inclusion of a C-TAG.

**Note:** These examples apply the tag *without* extending the length of the frame.
Instead, four bytes are removed from the padding to accommodate the C-TAG while leaving the frame at the minimum size.
This is not required or expected on the part of the sender, but it is valid and was done here to demonstrate an important point:
Should a switch remove the tag when forwarding the frame, it must be prepared to extend the padding to maintain the minimum length or the frame is likely to be discarded by the recipient as a runt.

A nearly identical structure, called the Service VLAN Tag (S-TAG), is also described in in Clause 9.
Instead, it uses a <abbr>TPID</abbr> of `0x88A8` (`88 A8` in transmit order).
It exists to distinguish service provider data planes from those of the customer and, in fact, an S-TAG will regularly carry C-TAGs within its envelope.

> **Note:** As part of the 802 standards, the latest version of 802.1Q is available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68) at no cost.
> Despite its common association with VLAN tags, 802.1Q describes all forms of bridging (e.g. switches).
> Many of the Time Sensitive Networking (<abbr>TSN</abbr>) standards are built on top of the features described in 802.1Q.

## Flow Control (Clause 31, Annex 31B, Annex 31D)

Ethernet does not have an intrinsic concept of flow control.
There is no "ready" or "wait" signal by which the receiver can apply backpressure against the transmitter like exists in a bus such as AXI-Stream.
Instead, the transmitter may send data at full rate and the receiver must either accept or drop the data as it comes.

What 802.3 does provide is an *optional* <abbr title="Media Access Controller">MAC</abbr> Control sublayer, described in Clause 31.
This establishes a control plane using otherwise normal Ethernet frames.
For the purpose of flow control, we are interested in the PAUSE (Annex 31B) and <abbr title="Priority-based Flow Control">PFC</abbr> (Annex 31D) operations.

### PAUSE (Annex 31B)

The PAUSE operation is a fairly simply frame with the following characteristics:
- The destination address is the multicast address `01 80 C2 00 00 01` or the address of the peer.
  Switches are not to forward frames set to this multicast address, regardless of the link characteristics.
- The source address is the individual address of the station generating the PAUSE frame.
- The EtherType for control operations, `0x8808` (`88 08` in transmit order).
- The Control Opcode `0x0001` (`00 01` in transmit order).
- A 16-bit value indicating the requested pause time in units of 512 bit periods (64 bytes), sent most significant byte first.
- The rest of the frame is padded with zeros (reserved).

An example PAUSE frame with a pause time of `0x1234` (4660 pause quanta, aka 298,240 bytes) would look like:

<p style="font-family: monospace;"><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Destination Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">01 80 C2 00 00 01</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Source Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">F8 B7 E2 04 0C 19</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FE48; border: 1px solid #FD0; border-radius: 2px;" title="EtherType"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">88 08</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Opcode"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 01</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Pause Time"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">12 34</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #88F8; border: 1px solid #88F; border-radius: 2px;" title="Padding"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px;" title="Frame Check Sequence"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">C0 77 B2 C3</span></span><span
   style="font-size: 0;"> </span></p>

Upon receiving the frame, the transmitter should complete the current frame (if any) and then pause transmission of normal traffic for the requested time period.
Transmission of MAC Control frames is not affected by a PAUSE operation.

If a second PAUSE frame is received during this period, it will override the previous PAUSE operation.
This facilitates an on-off manner of operation in which a max-duration `0xFFFF` PAUSE is sent when buffers have received capacity followed by a zero-duration PAUSE after they have fallen below the target threshold.

> **Note:** Support for PAUSE needs to be negotiated as part of the protocol's autonegotiation mechanism and only applies to full duplex links.
> PAUSE frames are not used when <abbr title="Priority-based Flow Control">PFC</abbr> is in effect.

### Priority-based Flow Control (Annex 31D, 802.1Q Clause 36)

Using Q-Tags, traffic may be sent at different priorities with different <abbr title="Quality of Service">QoS</abbr> guarantees.
As such, when approaching link capacity, it may be desirable to slow down (pause) lower-priority traffic in order to ensure the timely delivery of higher-priority traffic.
The <abbr title="Priority-based Flow Control">PFC</abbr> operation permits the specification of separate durations for each of the eight priorities permitted by a Q-Tag.

The structure is similar to the PAUSE frame:
- The destination address is the same multicast address as a PAUSE frame (`01 80 C2 00 00 01`).
  The state diagram for the <abbr>PFC</abbr> opcode does not permit the station's individual address as it does for PAUSE.
- The source address is the individual address of the station generating the PFC frame.
- The same EtherType (`0x8808`) as all <abbr>MAC</abbr> Control sublayer frames.
- The Control Opcode `0x0101`.
- A 16-bit bitmask indicating which priorities the frame is configuring, sent most significant byte first.
  As there are only eight priorities, the high-order byte is always zero.
  The remaining bit positions correspond to each priority.
  For example, configuring priority zero would set the least significant bit (`0x0001` or `00 01` in transmit order).
- Eight 16-bit fields, named `time[n]`, starting from zero, corresponding to each priority in order.
  All eight properties are present, even if the specific priority has been masked out by the enable vector.
  Like the PAUSE frame, these indicate the requested inhibit time in units of 512 bit periods (64 bytes) and are sent most significant byte first.
- The rest of the frame is padded with zeros (reserved).

An example <abbr>PFC</abbr> frame requesting a pause time of `0x1234` on priority two and a pause time of `0x5678` on priority one would look like:

<p style="font-family: monospace;"><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Destination Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">01 80 C2 00 00 01</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FC88; border: 1px solid #FC0; border-radius: 2px;" title="Source Address"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">F8 B7 E2 04 0C 19</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #FE48; border: 1px solid #FD0; border-radius: 2px;" title="EtherType"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">88 08</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Opcode"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">01 01</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Priority Enable Vector"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 06</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #8F88; border: 1px solid #4F4; border-radius: 2px;" title="Time Vector"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 56 78 12 34 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #88F8; border: 1px solid #88F; border-radius: 2px;" title="Padding"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00</span></span><span
   style="font-size: 0;"> </span><span
 style="background: #C8F8; border: 1px solid #C8F; border-radius: 2px;" title="Frame Check Sequence"><span
  style="padding: 0 4px; box-decoration-break: clone; -webkit-box-decoration-break: clone;">74 B3 B9 76</span></span><span
   style="font-size: 0;"> </span></p>

> **Note:** Like PAUSE, support for <abbr>PFC</abbr> needs to be enabled.
> Unlike <abbr>PFC</abbr>, this is not handled by standard in-band autonegotiation mechanisms.
> Audio Video Bridging (802.1BA) makes use of <abbr>PFC</abbr>.

> **Note:** As part of the 802 standards, the latest versions of 802.1Q and 802.1BA are available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68) at no cost.

## Energy Efficient Ethernet (Clause 78)

With the exception of half-duplex operation and 10Base-T, modern Ethernet transmits continuously.
This can result in a considerable power expense, especially at higher signalling rates.
Energy Efficient Ethernet (<abbr>EEE</abbr>) is a mechanism by which the <abbr title="Physical Layer Device">PHY</abbr> can disable its transmitter during periods of low activity to save power, known as Low Power Idle (<abbr>LPI</abbr>).
In addition to disabling the transmitter, the interface between the <abbr title="Media Access Controller">MAC</abbr> and <abbr title="Physical Layer Device">PHY</abbr> can also be disabled, reducing power even further.

The implementation of <abbr>LPI</abbr> is specific to the interface, but generally involves three phases:
a sleep signal indicating an intent to enter <abbr>LPI</abbr>, the <abbr>LPI</abbr> state itself (with periodic refreshes to maintain the link), and an idle period to resynchronize the link before resuming transmission.
Many of these steps are managed automatically by a Base-T PHY but more direct handling is required when implementing Base-X or Base-R using the <abbr title="Multi-Gigabit Transceiver">MGT</abbr>s of an FPGA.
The specific handling of <abbr>EEE</abbr> will be described with each protocol.

As 10Base-T does not transmit continuously, it does not implement <abbr>LPI</abbr>.
Instead, 10Base-Te is a cross-compatible variant of 10Base-T with reduced signal amplitude introduced at the same time as <abbr>EEE</abbr>.

## Precision Time Protocol (802.1AS or 1588)

The Precision Time Protocol (PTP) is a hardware-assisted time synchronization protocol capable of sub-microsecond accuracy.
The timestamp point for PTP packets is the transition from the last symbol of the SFD to the first symbol of the destination address.
While this can be captured by the MAC in its interface with the PHY, many PHYs have built-in PTP support and will capture the packet timestamp as it crosses to/from the medium.
When implemented in this fashion, nanosecond-level accuracy is possible.

> **Note:** As part of 802, 802.1AS (<abbr title="Generalized Precision Time Protocol">gPTP</abbr>) is available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68).
> The full <abbr>PTP</abbr> standard ([IEEE 1588](https://standards.ieee.org/ieee/1588/6825/)) is a paid standard.

## Synchronous Ethernet (ITU-T G.8261)

As the transmit pattern in high speed ethernet runs continuously (baring the use of <abbr title="Low Power Idle">LPI</abbr>), the receiver is able to maintain continuous synchronization to the reference clock of its peer as part of its clock recovery circuit.
The <abbr title="International Telecommunication Union">ITU</abbr> exploits this in their Synchronous Ethernet specifications to provide traceable time synchronization through a network.
This is commonly limited to high-speed protocols such as those implemented using Base-X or Base-R which provide a high-precision reference.

> **Note:** I am not personally familiar with the SyncE specifications and have not acquainted myself with the SyncE features of the PHYs I have used.

> **Note:** As with the 802 standards, the ITU-T G.8261 standard is [freely available from the ITU's website](https://www.itu.int/rec/T-REC-G.8261).

## Definitions

### Carrier

In radio, "carrier" frequently refers to a sinusoid that is mixed into a modulated signal to facilitate its transmission and permit sharing of the physical medium.
With exception to optical Ethernet, where the wavelength of the laser would qualify, wired Ethernet does not have a carrier in this traditional sense.
The "Base" in something like 10GBase-T refers to *baseband* (i.e. the absence of a carrier signal).

In the context of 802.3, "carrier" (as part of *carrier sense*) refers to the condition when the medium is nonidle (e.g. Clause 22.2.2.11).
It should not be interpreted as describing how the medium itself is being modulated.

### Ethernet

I've seen it debated that certain network protocols (namely fiber) are not *Ethernet*.
That is incorrect.

The name of the IEEE 802.3-2022 standard is *Ethernet* and anything defined by that standard is also called *Ethernet*.
This includes fiber protocols like 10GBase-SR (Clause 52), backplane protocols like 10GBase-KR (Clause 72), and strange diversions like 10GBase-CX4 (Clause 54) in addition to classic twisted pair like 100Base-TX (Clause 25).
