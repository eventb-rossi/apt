#!/usr/bin/env bash
# Assemble the orig tarball for the newest eventb-rossi Rodin Bundle release,
# release candidates included, from its Linux x86_64 Eclipse RCP archive
# (https://github.com/eventb-rossi/Rodin-Bundle/releases).
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

fetch_rodin_bundle
pack_orig
