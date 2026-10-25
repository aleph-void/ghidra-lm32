> **Ghidra-Rare fork.** This branch adds tested fixes, release builds for the three newest Ghidra
> releases and test suites; see [GHIDRA-RARE.md](GHIDRA-RARE.md) for the test results and
> remaining gaps, and [CREDITS.md](CREDITS.md) for the original authors and every change.
> Prebuilt zips for Ghidra 12.1.3, 12.1.4 and 12.2 are on this fork's
> [Releases page](https://github.com/aleph-void/ghidra-lm32/releases). The original README
> follows; the sections marked *Ghidra-Rare* were added.

# ghidra-lm32

[![Sponsor Aleph Void](https://img.shields.io/badge/Sponsor-Aleph%20Void-EA4AAA?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/aleph-void)

 LM32 processor module for Ghidra. Useful for AMD SMU reverse engineering. 

## Languages (*Ghidra-Rare*)

| Language ID | Use for |
|---|---|
| `lm32:BE:32:default` | LatticeMico32 (big endian, as in hardware and gcc). ELF files select it automatically |
| `lm32:LE:32:default` | The same ISA in little endian. No known hardware uses it |

## Installing (*Ghidra-Rare*)

This branch targets Ghidra 12.1.4 and is built and tested on 12.1.3, 12.1.4 and 12.2.

- **Release zip:** download the zip for your Ghidra version from the
  [Releases page](https://github.com/aleph-void/ghidra-lm32/releases), then in Ghidra use
  *File > Install Extensions*, add the zip, and restart Ghidra.
- **From source:** `GHIDRA_INSTALL_DIR=/path/to/ghidra_12.1.4_PUBLIC gradle buildExtension`,
  then install the zip from `dist/` the same way.

## AMD SMU firmware (*Ghidra-Rare*)

Issue [#1](https://github.com/jevinskie/ghidra-lm32/issues/1) asks which is the most recent AMD
processor with an LM32 SMU. The author's answer: SMUs before Zen are LM32 (family 15h or 16h is
probably the newest); Zen and later use Xtensa.

Ghidra-Rare tested this module on two AMD SMU firmware images with a free license. AMD
published both as C arrays in its AGESA source, under the BSD-3-Clause license, and coreboot
4.11 carries them:

| Firmware | Processors | Load address | Result |
|---|---|---|---|
| `GnbSmuFirmwareTN.h` | Family 15h models 10h-1Fh (Trinity/Richland) | 0x10000 (EBA 0x10100) | 161 functions, 13,486 instructions, 100 % identical to objdump, 0 bad instructions, all functions decompile |
| `GnbSmuFirmwareKB.h` | Family 16h models 00h-0Fh (Kabini/Temash) | 0x20000 (EBA 0x20100) | 350 functions, 23,110 instructions, 100 % identical to objdump, 0 bad instructions, all functions decompile |

`test/fetch-real-samples.sh` downloads them and converts them to raw images, and
`test/real-binaries.sh` checks them.

To load one yourself, import the raw image as `lm32:BE:32:default` at its load address. Then
disassemble the exception vectors at EBA, which are eight 32-byte slots starting with reset.
The first 0x100 bytes are a header, not code. The Kabini firmware keeps a global data pointer
in r24, which its initialisation code at 0x2163c sets to 0x397f8. Setting r24 to that value
over the image lets the decompiler resolve its globals.

The Family 14h (Ontario/Zacate) SMU firmware in AGESA, `F14NbSmuFirmware.h`, is not LM32
code: 36 % of its words are not valid LM32 instructions.

The AMD GPU SMC firmware in linux-firmware (`radeon/*_smc.bin`) was not used: its license
forbids disassembly. Other SMU firmware ships inside vendor BIOS images, which have no license
that permits disassembly.
