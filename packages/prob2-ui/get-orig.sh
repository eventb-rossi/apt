#!/usr/bin/env bash
# Assemble the orig tarball for prob2-ui from the upstream amd64 .deb.  Since
# 1.4.0 upstream no longer publishes a multi-platform jar: Linux gets only a
# jpackage bundle (application jar + private Java runtime) under /opt/prob2-ui.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

url="https://stups.hhu-hosting.de/downloads/prob2/${UVER}/prob2-ui_${UVER}_amd64.deb"
deb="$DOWNLOADS/prob2-ui_${UVER}_amd64.deb"
fetch "$url" "$deb"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
dpkg-deb -x "$deb" "$d"            # extracts the /opt/prob2-ui tree under $d

# debian/rules relies on this layout; fail here if upstream reshapes the bundle.
b="$d/opt/prob2-ui"
for f in bin/ProB2-UI lib/app/ProB2-UI.cfg lib/ProB2-UI.png lib/runtime/release; do
    [ -e "$b/$f" ] || { echo "upstream bundle lacks opt/prob2-ui/$f" >&2; exit 1; }
done

pack_orig
