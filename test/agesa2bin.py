#!/usr/bin/env python3
# Extract a UINT32 array from an AMD AGESA C header (e.g. the SMU firmware in coreboot's
# src/vendorcode/amd/agesa/.../GnbSmuFirmware*.h) into a big-endian binary, the byte order
# the LatticeMico32 SMU fetches it in.
#   agesa2bin.py <header.h> <array-name> <out.bin>
import re
import struct
import sys

src, name, out = sys.argv[1:4]
text = open(src).read()
m = re.search(r'\b' + re.escape(name) + r'\s*\[\]\s*=\s*\{(.*?)\};', text, re.S)
if not m:
    sys.exit('%s: no array %s' % (src, name))
words = [int(w, 16) for w in re.findall(r'0x[0-9a-fA-F]+', m.group(1))]
with open(out, 'wb') as f:
    f.write(b''.join(struct.pack('>I', w) for w in words))
