#!/usr/bin/env bash
# Assemble the orig tarball for ProB (Tcl/Tk) from the upstream binary tarball.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

url="https://stups.hhu-hosting.de/downloads/prob/tcltk/releases/${UVER}/ProB.linux64.tar.gz"
f="$DOWNLOADS/prob-${UVER}.linux64.tar.gz"
fetch "$url" "$f"

work=$(mktemp -d)
tar -C "$work" -xzf "$f"          # extracts a top-level "ProB" directory

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"
mv "$work/ProB" "$d"
rm -rf "$work"

pack_orig
