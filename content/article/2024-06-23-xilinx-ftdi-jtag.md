---
date: 2024-06-23T16:20:00-0700
title: Xilinx JTAG Support on FTDI
slug: xilinx-ftdi-jtag
tags:
  - amd
  - embedded
  - firmware
  - fpga
  - ftdi
  - hardware
  - xilinx
---

For many industrial embedded projects, embedding debugging support (e.g. JTAG) into the design can be immensely useful.
This can be for the convenience of integrated debugging or specialized needs, such as galvanic isolation.
The [FTDI family of High-Speed USB-Serial transceivers](https://ftdichip.com/product-category/products/ic/usb-high-speed-series-ics/) are commonly used for this purpose.
FTDI's [Multi-Protocol Synchronous Serial Engine (MPSSE)](https://www.ftdichip.com/Documents/AppNotes/AN_135_MPSSE_Basics.pdf) can offload the JTAG state machine and achieve clock speeds as high as 30 MHz.
Software like [OpenOCD](https://openocd.org/) provides a solid basis for manipulating microcontrollers but the situation is very different when it comes to FPGAs.

Classically, FTDI was not supported by Xilinx development software (e.g. Vivado, Vitis) unless using one of the [modules from Digilent](https://digilent.com/reference/programmers/).
However, in 2018, Xilinx released the [VCU128 Evaluation Board](https://www.xilinx.com/products/boards-and-kits/vcu128.html), which sports an [FTDI FT4232HL](https://ftdichip.com/products/ft4232hl/) without any special features.
At some point, the use of FTDI devices became officially supported by Vivado.
Unfortunately, despite this support, the [documentation](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Programming-FTDI-Devices-for-Vivado-Hardware-Manager-Support) remains poor and occasionally nonfunctional.
In this article, I will attempt to provide more complete design assistance.

## Hardware Configuration

Officially, the [FT232H](https://ftdichip.com/wp-content/uploads/2023/09/DS_FT232H.pdf), [FT2232H](https://ftdichip.com/wp-content/uploads/2024/05/DS_FT2232H.pdf), and [FT4232H](https://ftdichip.com/wp-content/uploads/2024/05/DS_FT4232H.pdf) are supported (QFN or QFP).
All known Xilinx reference designs use the FT4232HL.
It is untested whether the [automotive version](https://ftdichip.com/wp-content/uploads/2022/03/DS_FT4232HA.pdf) or [power delivery series](https://ftdichip.com/product-category/products/ic/usb-power-delivery-series-ics/) will function if appropriately programmed.

All Xilinx reference designs use the [93LC56B](https://ww1.microchip.com/downloads/aemDocuments/documents/MPD/ProductDocuments/DataSheets/93AA56X-93LC56X-93C56X-2-Kbit-Microwire-Compatible-Serial-EEPROM-Data-Sheet.pdf) (2kbit) memory.
The 93LC46B (1kbit) memory has a different layout that works under Windows but fails to be properly detected by Vivado under Linux.
Use of the 93LC66B (4kbit) memory has not been tested.

**Note:** The second port on an FT2232H or three remaining ports on a FT4232H can be used for normal UART or bit-bang.
On the FT4232H, only the second port can be used as an additional MPSSE channel whereas the second port on the FT2232H is largely equivalent to the first.

### Pin Assignments

All JTAG connections use `ADBUS0-7`, which corresponds to the first port on the FT2232H and FT4232H.
These assignments are fixed and summarized in the following table:

Pin      | Name      | Dir | Description
:--------|:----------|:---:|:------------
`ADBUS0` | `TCK`     | OUT | JTAG Clock
`ADBUS1` | `TDI`     | OUT | JTAG Data Input
`ADBUS2` | `TDO`     | IN  | JTAG Data Output
`ADBUS3` | `TMS`     | OUT | JTAG Mode Select
`ADBUS4` | `VCCO_ON` | IN  | Target Detect (Active High)
`ADBUS5` | `OE_B`    | OUT | JTAG Output Enable (Active Low)
`ADBUS6` | `POR_B`   | OUT | Power-On-Reset (Active Low)
`ADBUS7` | `SRST_B`  | OUT | System Reset (Active Low)

`ADBUS0-3` are defined by the MPSSE engine.
These are connected to the matching ports on the Xilinx FPGA after any necessary level conversion.

`ADBUS4` (`VCCO_ON`) is used to detect the presence of the target device and is used in every design except for the SP701.
When High, the target device is present and powered.
When Low, the target device is missing or unpowered.

`ADBUS5` (`OE_B`) is an optional active-low output that can be used to control the JTAG level converters, allowing them to be disconnected when Vivado is not actively driving the bus.
It is High to float the JTAG lines and Low to enable the drivers.

`ADBUS6` (`POR_B`) is an output that connects to the `PS_POR_B` signal on Zynq parts or `POR_B` on Versal parts.
It must be buffered with an open-collector buffer to ensure that wired-OR functions properly.
This is only used with the MPSoCs and is left disconnected for the pure FPGAs.

`ADBUS7` (`SRST_B`) is an output that connects to the `PS_SRST_B` signal on Zynq parts.
Like `POR_B`, this must be buffered with an open-collector output.
This is only used with Zynq parts and is left disconnected for the Versal parts and pure FPGAs.

The remaining ports are unused and can be freely allocated for other purposes.

### Level Conversion

The FTDI parts use strictly 3V3 I/O, requiring level conversion when the configuration bank is set for another voltage, such as 1V8.
Even when the FPGA is using 3V3, it is recommended that voltage translators be used since the components are on separate power supplies.

The JTAG signals are unidirectional, with three outgoing and one incoming connection.
The reference designs use multiple [SN74AVC2T245](https://www.ti.com/lit/ds/symlink/sn74avc2t245.pdf) or [SN74AVC4T245](https://www.ti.com/lit/ds/symlink/sn74avc4t245.pdf); however, these do not provide the necessary 3/1 ratio.
Unidirectional level conversion ICs, such as the [74AVC4T3144](https://assets.nexperia.com/documents/data-sheet/74AVC4T3144.pdf), provide a reliable single chip solution.

The `POR_B` and `SRST_B` outputs are meant to be wired-OR and should use open-collector outputs.
The Zynq reference designs use the two-channel [NC7WZ07](https://www.onsemi.com/pdf/datasheet/nc7wz07-d.pdf) while the Versal uses a six-channel [SN74LVC07A](https://www.ti.com/lit/ds/symlink/sn74lvc07a.pdf) for combining multiple POR reset sources.

### Evaluation Kits

The following table lists the Xilinx reference kits where the FTDI JTAG interface is used and which pins are in use:

Kit | Device | VCCO_ON | OE_B | POR_B | SRST_B
:---|:-------|:-------:|:----:|:-----:|:------:
[KR260](https://www.amd.com/en/products/system-on-modules/kria/k26/kr260-robotics-starter-kit.html) | Kria K26 | X (1) | X | X | X
[KV260](https://www.amd.com/en/products/system-on-modules/kria/k26/kv260-vision-starter-kit.html) | Kria K26 | X (1) | X | X | X
[SP701](https://www.xilinx.com/products/boards-and-kits/sp701.html) | Spartan-7 | (2) | X | | X (3)
[VCK190](https://www.xilinx.com/products/boards-and-kits/vck190.html) | Versal | X (4) | | X |
[VCU128](https://www.xilinx.com/products/boards-and-kits/vcu128.html) | Virtex-7 | X (4) | | |
[ZCU216](https://www.xilinx.com/products/boards-and-kits/zcu216.html) | Zynq UltraScale+ RFSoC | X (4) | | X | X

1. These evaluation kits simply use one input of the SN74AVC4T245 directly connected to the MIO power rail.
2. The SP701 does not include a VCCO test input.
   The FT4232H has internal pull-ups that will read as if the FPGA is always powered.
3. The SP701 ties the `SRST_B` signal to the MSP430 reset line.
   It has no direct connection to the FPGA.
4. These evaluation kits compare the MIO/VCCO_0 supply voltage to 1/3 the FTDI 3V3 supply (1.1 Volts).

## Device Programming

The official instructions are to use the `program_ftdi` script included with Vivado.
The minimum usage is:

```sh
program_ftdi -write -ftdi=<ftdi_part> -serial=<serial_number>
```

These parameters are used to discover the specific part to program.
Additional parameters, such as `-vendor`, `-board`, and `-desc`, are used to configure additional metadata.

The USB manufacturer string will always be `"Xilinx"` but the description string is that specified by `-desc`.
By contrast, the `-vendor` and `-board` strings are stored into the Xilinx-specific data area.
While I have yet to discover any use of the `-vendor` string, the `-board` string is included in the `hw_server` connection string.

Unfortunately, the script is limited and rather brittle.
In Vivado 2024.1, it's completely broken, being linked against tcl 8.5 while Vivado ship tcl 8.6.

**Note:** Despite what the official Xilinx instructions say, the use of `FT_PROG` is destructive to the Xilinx-specific configuration and the `program_ftdi` script does not honor existing port configuration.
It is impossible to alter the default configuration the remaining ports of an FT2232H or FT4232H without repeating the functionality of the Xilinx script.

### EEPROM Layout

Xilinx includes the underlying source files, namely `/tools/Xilinx/Vivado/2024.1/scripts/program_ftdi/ftdieeprom.tcl`, making it trivial to reverse engineer the EEPROM structure.

The core FTDI configuration is left at its defaults with the following exceptions:
- The manufacturer string is set to `"Xilinx"`.
  It is untested whether this is required for successful detection by Vivado.
- Serial port emulation (VCP) is disabled for Port A.

**Note:** It is untested whether Vivado will correctly enumerate FTDI devices using custom VID/PID combinations.

Most of the magic is in the [*user area*](https://www.ftdichip.com/Documents/AppNotes/AN_121_FTDI_Device_EEPROM_User_Area_Usage.pdf), the remainder of the EEPROM after the main configuration.
Sadly, the user area is poorly supported in many FTDI libraries and tools.
For best results, it is recommended to use the official [D2XX API](https://ftdichip.com/drivers/d2xx-drivers/).

The basic format of the user area is:
1. 32-Bit Signature (Little Endian)
   - FT232H: `0x584A0002` (May work with FT232HPQ, untested)
   - FT2232H: `0x584A0003` (May work with FT2232HPQ, untested)
   - FT4232H: `0x584A0004` (May work with FT4232HAQ/HPQ, untested)
2. Vendor String (UTF-8, `NUL` Terminated)
3. Product String (UTF-8, `NUL` Terminated)

For example, an FT4232H with vendor `"Acme"` and product `"JTAG"` would be:

```
04 00 4A 58 41 63 6D 65 00 4A 54 41 47 00
```

**Note:** It is unclear if there is internal structure to the signature which could be used to modify `hw_server`'s behavior.

### Example Program

Using the official D2XX API, a complete imaging would look something like this (ignoring initial connection and error handling):

```c
// Write out configuration
FT_PROGRAM_DATA data = {
    // Common Configuration
    .Signature1 = 0x00000000,
    .Signature2 = 0xFFFFFFFF,
    .Version = 5,         // Support through FT232H
    .VendorId = 0x0403,   // Default Value, FTDI
    .ProductId = 0x6011,  // 0x6014=FT232H, 0x6010=FT2232H, 0x6011=FT4232H
    .Manufacturer = "Xilinx",
    .ManufacturerId = NULL,
    .Description = "whatever you'd use with -desc",
    .SerialNumber = "whatever you'd use with -serial",
    .MaxPower = 100,      // Default Value
    .PnP = 1,             // Default Value
    .SelfPowered = 0,     // Default Value
    .RemoteWakeup = 0,    // Default Value
    // FT2232H Settings
    .SerNumEnable7 = 1,   // Default Value
    .ALDriveCurrent = 4,  // Default Value
    .AHDriveCurrent = 4,  // Default Value
    .BLDriveCurrent = 4,  // Default Value
    .BHDriveCurrent = 4,  // Default Value
    .IFAIsFifo7 = 1,      // Set to MPSSE
    .IFAIsFifoTar7 = 0,   // Set to MPSSE
    .IFAIsFastSer7 = 0,   // Set to MPSSE
    .AIsVCP7 = 0,         // Set to MPSSE
    .IFBIsFifo7 = 0,      // Default Value, Set to VCP
    .IFBIsFifoTar7 = 0,   // Default Value, Set to VCP
    .IFBIsFastSer7 = 0,   // Default Value, Set to VCP
    .BIsVCP7 = 1,         // Default Value, Set to VCP
    // FT4232H Settings
    .SerNumEnable8 = 1,   // Default Value
    .ADriveCurrent = 4,   // Default Value
    .BDriveCurrent = 4,   // Default Value
    .CDriveCurrent = 4,   // Default Value
    .DDriveCurrent = 4,   // Default Value
    .AIsVCP8 = 0,         // Set to MPSSE
    .BIsVCP8 = 1,         // Default Value, Set to VCP
    .CIsVCP8 = 1,         // Default Value, Set to VCP
    .DIsVCP8 = 1,         // Default Value, Set to VCP
    // FT232H Settings
    .SerNumEnableH = 1,   // Default Value
    .ACDriveCurrentH = 4, // Default Value
    .ADDriveCurrentH = 4, // Default Value
    .IsFifoH = 1,         // Set to MPSSE
    .IsVCPH = 0,          // Set to MPSSE
};
FT_EE_Program(ftHandle, &data);

// Write out Signature
// NOTE: First byte is \x02 for FT232H, \x03 for FT2232H, \x04 for FT4232H
uint8_t buffer[] = "\x04\x00\x4A\x58Acme\0JTAG";
FT_EE_UAWrite(ftHandle, buffer, sizeof(buffer));

// Force the driver to reload the configuration
FT_CyclePort(ftHandle);
```

If your application requires a FIFO or second MPSSE, it can be connected to Port B, in which case the associated fields will need to be updated to reflect the new configuration.
Given the use of level converters in most applications, there is probably little need to adjust the slew rates or drive currents.

**Note:** The VCP-related settings are ignored by Linux, instead relying on static configuration of PID/VID pairs inside the `ftdi_sio` driver.
This will lead to an instance of `ttyU` for the JTAG port until released by direct access to the USB interface by Vivado.
