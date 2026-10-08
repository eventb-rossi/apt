#!/usr/bin/env bash
# Assemble the orig tarball for eventb-animate from the upstream release jar.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

tag="v${UVER}"
# Since 7.1 upstream publishes only per-platform jars; the linux64 one bundles
# just the Linux x86-64 probcli (hence Architecture: amd64).
jar_url="https://github.com/eventb-rossi/eventb-animate/releases/download/${tag}/eventb-animate-${UVER}-linux64.jar"
lic_url="https://raw.githubusercontent.com/eventb-rossi/eventb-animate/${tag}/LICENSE"

jar="$DOWNLOADS/eventb-animate-${UVER}-linux64.jar"
lic="$DOWNLOADS/eventb-animate-${UVER}.LICENSE"
fetch "$jar_url" "$jar"
fetch "$lic_url" "$lic"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
cp "$jar" "$d/eventb-animate.jar"
cp "$lic" "$d/LICENSE"

pack_orig
