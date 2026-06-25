#!/usr/bin/env bash
# Assemble the orig tarball for rodin-headless from the upstream source archive.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

tag="v${UVER}"
src="$DOWNLOADS/rodin-headless-${UVER}.tar.gz"
url="https://github.com/eventb-rossi/rodin-headless/archive/refs/tags/${tag}.tar.gz"
fetch "$url" "$src"

# GitHub's tag tarball already unpacks to rodin-headless-<UVER>/, which is exactly
# the top-level directory build-deb.sh expects, so extract straight into build/.
d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"
tar -C "$ROOT/build" -xzf "$src"
[ -d "$d" ] || { echo "tarball did not yield $d" >&2; exit 1; }

pack_orig
