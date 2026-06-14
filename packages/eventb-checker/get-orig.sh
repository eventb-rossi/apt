#!/usr/bin/env bash
# Assemble the orig tarball for eventb-checker from the upstream release jar.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

tag="v${UVER}"
jar_url="https://github.com/eventb-rossi/eventb-checker/releases/download/${tag}/eventb-checker-${UVER}-all.jar"
lic_url="https://raw.githubusercontent.com/eventb-rossi/eventb-checker/${tag}/LICENSE"

jar="$DOWNLOADS/eventb-checker-${UVER}-all.jar"
lic="$DOWNLOADS/eventb-checker-${UVER}.LICENSE"
fetch "$jar_url" "$jar"
fetch "$lic_url" "$lic"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
cp "$jar" "$d/eventb-checker.jar"
cp "$lic" "$d/LICENSE"

pack_orig
