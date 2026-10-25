#!/usr/bin/env bash
# Download the public real-world LM32 binaries used by test/real-binaries.sh. Nothing is
# committed; the files land in <dest> (default: ./real-samples) and are checked against pinned
# SHA-256 sums.
#
#   test/fetch-real-samples.sh [dest]
#
# Source (pinned): timvideos/HDMI2USB-firmware-prebuilt, commit bf8ee7bf, build
# archive/master/v0.0.4-130-g155c7db: gcc-built LatticeMico32 ELF executables with DWARF for
# LiteX/MiSoC SoCs. The BIOS is LiteX's (BSD-2-Clause); the firmware is HDMI2USB-litex-firmware
# (BSD-2-Clause, with uIP and compiler-rt parts under their BSD/MIT-style licenses). The
# repository's LICENSE is BSD-style.
#   opsis-net-bios.elf               LiteX BIOS, Numato Opsis "net" target
#   opsis-net-firmware.elf           HDMI2USB firmware with Ethernet, Opsis
#   nexys_video-video-firmware.elf   HDMI2USB video firmware, Digilent Nexys Video
#
# AMD SMU firmware (pinned): coreboot 4.11 (commit ab8edda1), AMD AGESA, BSD-3-Clause (the
# license is in each header). The System Management Unit of AMD Family 15h models 10h-1Fh
# (Trinity/Richland, "TN") and Family 16h models 00h-0Fh (Kabini, "KB") is a LatticeMico32.
# AGESA ships its firmware as C arrays; test/agesa2bin.py turns each into a raw big-endian image.
#   amd-smu-tn.bin   GnbSmuFirmwareTN.h FirmwareTN, loaded at 0x10000 (EBA 0x10100)
#   amd-smu-kb.bin   GnbSmuFirmwareKB.h FirmwareKB, loaded at 0x20000 (EBA 0x20100)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-real-samples}
mkdir -p "$DEST"
cd "$DEST"
C=bf8ee7bf8ec3569980b02ab39c9700bf4b9ce5a9
B=https://raw.githubusercontent.com/timvideos/HDMI2USB-firmware-prebuilt/$C/archive/master/v0.0.4-130-g155c7db
fetch() { # path out
	if [[ ! -s $2 ]]; then
		curl -fsSL --retry 3 -o "$2.part" "$B/$1"
		mv "$2.part" "$2"
	fi
}
fetch opsis/net/lm32/software/bios/bios.elf opsis-net-bios.elf
fetch opsis/net/lm32/software/firmware/firmware.elf opsis-net-firmware.elf
fetch nexys_video/video/lm32/software/firmware/firmware.elf nexys_video-video-firmware.elf
CB=https://raw.githubusercontent.com/coreboot/coreboot/ab8edda14a622ab46bdfd01b877d75c7bd385a4d/src/vendorcode/amd/agesa
for h in f15tn/Proc/GNB/Modules/GnbInitTN/GnbSmuFirmwareTN.h f16kb/Proc/GNB/Modules/GnbInitKB/GnbSmuFirmwareKB.h; do
	if [[ ! -s $(basename "$h") ]]; then
		curl -fsSL --retry 3 -o "$(basename "$h").part" "$CB/$h"
		mv "$(basename "$h").part" "$(basename "$h")"
	fi
done

sha256sum -c - <<'EOF2'
335004245d2fa61242a16c766584329f413b12ac0faa1cbcd43307fe69080b17  opsis-net-bios.elf
ee305a4c5e2adcbb35f3a6770598e55564436da1df9ead7559d573553e46c3d6  opsis-net-firmware.elf
60a3a694edd1c4eb8fbf751fd85768787e1057f5d9a8bacf51473bd701699d69  nexys_video-video-firmware.elf
1a9f63995b105c9ef92a4d52248c0b2ed2afa322eab3565c2e040db0569b2c4a  GnbSmuFirmwareTN.h
0ba2bd4759eea859708e9cee209dc59c962bea18db083e63135df9ee649b143d  GnbSmuFirmwareKB.h
EOF2
python3 -I "$HERE/agesa2bin.py" GnbSmuFirmwareTN.h FirmwareTN amd-smu-tn.bin
python3 -I "$HERE/agesa2bin.py" GnbSmuFirmwareKB.h FirmwareKB amd-smu-kb.bin
sha256sum -c - <<'EOF2'
6dc02a5b6b9898a5aae3c295c4cde63811fe73b795ca63118649b3fc84f2c134  amd-smu-tn.bin
672187e2d307f821c67e2bdf684d183c64a3ebd5819bd19aa81d408ea516455d  amd-smu-kb.bin
EOF2
