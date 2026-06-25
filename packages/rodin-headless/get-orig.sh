#!/usr/bin/env bash
# Assemble the orig tarball for rodin-headless from the upstream source archive.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

fetch_github_tag
pack_orig
