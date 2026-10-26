#!/bin/bash
# Build the FMS bridge plugin (plugins/b747_fms_bridge/src) into
# plugins/b747_fms_bridge/64/win.xpl with MinGW-w64 (w64devkit) and the
# X-Plane SDK 4.3.0 (docs/overhaul/notes/ATA-34-61-FMC.md §23).
#   bash docs/overhaul/tools/build_fms_bridge.sh
# GCC and SDK default to this PC's (C:\Users\gakug\tools); give others with
# W64DEVKIT and XPSDK, another output with OUT. X-Plane must not have the
# plugin loaded (Windows keeps a loaded .xpl locked). The image base is
# fixed: the same source gives the same bytes wherever it is built.
set -euo pipefail
cd "$(dirname "$0")/../../.."
W64DEVKIT=${W64DEVKIT:-/c/Users/gakug/tools/w64devkit}
XPSDK=${XPSDK:-/c/Users/gakug/tools/XPSDK430/SDK}
OUT=${OUT:-plugins/b747_fms_bridge/64/win.xpl}
mkdir -p "$(dirname "$OUT")"
"$W64DEVKIT/bin/gcc" -shared -O2 -Wall -Wextra -std=c99 \
    -DIBM=1 -DXPLM200=1 -DXPLM210=1 -DXPLM300=1 -DXPLM301=1 -DXPLM400=1 -DXPLM410=1 \
    -I"$XPSDK/CHeaders/XPLM" \
    -o "$OUT" plugins/b747_fms_bridge/src/b747_fms_bridge.c \
    "$XPSDK/Libraries/Win/XPLM_64.lib" -static-libgcc -s -Wl,--disable-auto-image-base
ls -l "$OUT"
