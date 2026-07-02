#!/usr/bin/env bash
# Assemble the orig tarball for the Rodin platform from the upstream Eclipse RCP
# binary distribution.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

# Upstream embeds an opaque build id (timestamp + git hash) in the filename.
build_id="3.10.0.202607010932-881664d81"

url="https://downloads.sourceforge.net/rodin-b-sharp/Core_Rodin_Platform/${UVER}/rodin-${build_id}-linux.gtk.x86_64.tar.gz"
f="$DOWNLOADS/rodin-${build_id}-linux.gtk.x86_64.tar.gz"
fetch "$url" "$f"

work=$(mktemp -d)
tar --warning=no-unknown-keyword -C "$work" -xzf "$f"   # extracts top-level "rodin"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"
mv "$work/rodin" "$d"
rm -rf "$work"

pack_orig
