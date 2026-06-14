#!/usr/bin/env bash
# Assemble the orig tarball for Atelier B from the upstream vendor .deb built for
# Ubuntu 24.04 (its dependencies already match this release).
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

url="https://www.atelierb.eu/wp-content/uploads/2024/10/atelierb-free-${UVER}-ubuntu-24.04.deb"
deb="$DOWNLOADS/atelierb-free-${UVER}-ubuntu-24.04.deb"
fetch "$url" "$deb"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
dpkg-deb -x "$deb" "$d"            # extracts the /opt tree under $d

pack_orig
