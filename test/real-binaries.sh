#!/usr/bin/env bash
# Import real LM32 binaries headless (no -processor: the ELF opinion picks the language),
# run auto-analysis, decompile every function, and diff every instruction Ghidra found against
# objdump at the same address. Raw AMD SMU images (amd-smu-*.bin) are imported as raw binaries
# at their load address as lm32:BE:32:default, with the eight exception vectors at EBA as entry
# points (test/SeedEntries.java), and compared with objdump -D -b binary at the same addresses.
#
#   test/real-binaries.sh [samples-dir] [workdir]        (samples: test/fetch-real-samples.sh)
#
# Environment: GHIDRA_INSTALL_DIR (Ghidra 12.1.x with this module in Ghidra/Processors),
#   OBJDUMP (binutils 2.45 built with lm32), DECOMP_TIMEOUT (seconds per function, default 60)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${GHIDRA_INSTALL_DIR:?set GHIDRA_INSTALL_DIR}"
OBJDUMP=${OBJDUMP:-objdump}
TMO=${DECOMP_TIMEOUT:-60}
SAMPLES=$(readlink -f "${1:-real-samples}")
W=$(readlink -f "${2:-real-work}")
mkdir -p "$W"
[[ -x "$HERE/build-jar.sh" && -d "$HERE/../src" ]] && "$HERE/build-jar.sh"

files=()
for n in opsis-net-bios.elf opsis-net-firmware.elf nexys_video-video-firmware.elf ${EXTRA_SAMPLES:-}; do
	[[ -s $SAMPLES/$n ]] && files+=("$SAMPLES/$n")
done

# raw images: name -> load address (the image's first 0x100 bytes are a header; EBA = base + 0x100)
declare -A RAW_BASE=([amd-smu-tn.bin]=0x10000 [amd-smu-kb.bin]=0x20000)
for n in "${!RAW_BASE[@]}"; do
	[[ -s $SAMPLES/$n ]] && files+=("$SAMPLES/$n")
done

run_one() { # file
	local f=$1 n p imp=()
	n=$(basename "$f")
	p=$(mktemp -d "${TMPDIR:-/tmp}/lm32-real.XXXXXX")
	if [[ -n ${RAW_BASE[$n]:-} ]]; then
		local b=${RAW_BASE[$n]} k seeds=()
		for k in 0 1 2 3 4 5 6 7; do seeds+=("$(printf '0x%x' $((b + 0x100 + 0x20 * k)))"); done
		imp=(-loader BinaryLoader -loader-baseAddr "$b" -processor lm32:BE:32:default
			-preScript SeedEntries.java "${seeds[@]}")
	fi
	"$GHIDRA_INSTALL_DIR/support/analyzeHeadless" "$p" p -import "$f" "${imp[@]}" -scriptPath "$HERE" \
		-postScript RealCheck.java "$W/$n.sum" "$W/$n.lst" "$W/$n.c" "$TMO" \
		-deleteProject >"$W/$n.log" 2>&1 || { tail -20 "$W/$n.log" >&2; }
	rm -rf "$p"
}
echo "== headless import + analysis + decompile (${#files[@]} files, in parallel)"
for f in "${files[@]}"; do run_one "$f" & done
wait

echo "== results"
for f in "${files[@]}"; do
	n=$(basename "$f")
	if [[ -n ${RAW_BASE[$n]:-} ]]; then
		"$OBJDUMP" -D -b binary -m lm32 -EB --adjust-vma="${RAW_BASE[$n]}" "$f" >"$W/$n.od"
		echo "-- $n (raw, base ${RAW_BASE[$n]})"
		grep -E "^(language|functions|instructions|fallthrough|bad-instruction|error bookmarks|decompile|functions whose)" "$W/$n.sum" | sed 's/^/   /'
		python3 "$HERE/compare.py" --listing "$W/$n.lst" "$W/$n.od" 10 >"$W/$n.cmp"
		echo "   vs objdump: $(head -1 "$W/$n.cmp")"
		continue
	fi
	etype=$(python3 -I -c 'import sys; h=open(sys.argv[1],"rb").read(18); print(int.from_bytes(h[16:18], "little" if h[5]==1 else "big"))' "$f")
	delta=0
	# Ghidra rebases a shared object (link base 0) to its image base
	[[ $etype == 3 ]] && delta=$(sed -n 's/^image base: //p' "$W/$n.sum")
	"$OBJDUMP" -d "$f" >"$W/$n.od"
	# objdump -d output -> same per-address form; compare.py reads objdump lines directly
	echo "-- $n (e_type $etype)"
	grep -E "^(language|functions|instructions|fallthrough|bad-instruction|error bookmarks|relocations|decompile|functions whose)" "$W/$n.sum" | sed 's/^/   /'
	python3 "$HERE/compare.py" --listing "$W/$n.lst" "$W/$n.od" 10 --delta=$((-delta)) >"$W/$n.cmp"
	echo "   vs objdump: $(head -1 "$W/$n.cmp")"
done
echo "(full outputs: $W/<file>.{sum,lst,c,cmp,log})"
