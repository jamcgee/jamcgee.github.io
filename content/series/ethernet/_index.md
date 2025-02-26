---
title: Ethernet
---

Much of my recent professional development has focused on Ethernet, making it a convenient target for technical articles.
Unlike much of the Internet, this series of articles will focus on practical implementation of an Ethernet <abbr title="Media Access Controller">MAC</abbr> from an <abbr title="Field Programmable Gate Array">FPGA</abbr> or <abbr title="Application-Specific Integrated Circuit">ASIC</abbr> perspective.
This means the necessary waveforms and encodings to generate ethernet packets when directly connected to a PHY or medium.

The articles will be making extensive references to [<abbr title="Institute for Electrical and Electronic Engineers">IEEE</abbr> 802.3-2022](https://ieeexplore.ieee.org/document/9844436) and every effort will be made to specify the exact clauses for followup by the reader.
I will not be using the amendment names (e.g. 802.3z for Gigabit Ethernet) because they are not not useful for finding content within the actual standard and any given clause may have been modified by multiple amendments.

> **Note:** The most recent version of the 802 standards are available from the [IEEE Get program](https://ieeexplore.ieee.org/browse/standards/get-program/page/series?id=68) at no cost.
> It is highly advised that anyone working with Ethernet download copies of 802.1Q (Bridges) and 802.3 (Wired Ethernet).
