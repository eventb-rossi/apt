#!/usr/bin/env bash
# Assemble the orig tarball for the eventb-rossi Rodin Bundle from its Linux
# x86_64 Eclipse RCP archive (https://github.com/eventb-rossi/Rodin-Bundle/releases).
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

# ${UVER} names the release tag; the build qualifier in the asset name is
# resolved (and the download verified) through the release's SHA256SUMS.
f="$(fetch_rodin_bundle)"

work=$(mktemp -d)
tar --warning=no-unknown-keyword -C "$work" -xzf "$f"   # extracts top-level "rodin"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"
mv "$work/rodin" "$d"
rm -rf "$work"

pack_orig
