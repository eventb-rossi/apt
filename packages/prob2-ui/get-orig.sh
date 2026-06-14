#!/usr/bin/env bash
# Assemble the orig tarball for prob2-ui from the upstream multi-platform jar.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

jar_url="https://stups.hhu-hosting.de/downloads/prob2/${UVER}/prob2-ui-${UVER}-multi.jar"
lic_url="https://raw.githubusercontent.com/hhu-stups/prob2_ui/v${UVER}/LICENSE"

jar="$DOWNLOADS/prob2-ui-${UVER}-multi.jar"
lic="$DOWNLOADS/prob2-ui-${UVER}.LICENSE"
fetch "$jar_url" "$jar"
fetch "$lic_url" "$lic"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
cp "$jar" "$d/prob2-ui.jar"
cp "$lic" "$d/LICENSE"
unzip -p "$jar" de/prob2/ui/ProB_Icon.png > "$d/prob2-ui.png"

pack_orig
