#!/usr/bin/env bash
# Assemble the orig tarball for eventb-to-txt from its PyPI sdist.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

url=$(python3 - "$UVER" <<'PY'
import json, sys, urllib.request
ver = sys.argv[1]
d = json.load(urllib.request.urlopen(f"https://pypi.org/pypi/eventb-to-txt/{ver}/json"))
print(next(u["url"] for u in d["urls"] if u["packagetype"] == "sdist"))
PY
)

f="$DOWNLOADS/$(basename "$url")"
fetch "$url" "$f"

work=$(mktemp -d)
tar -C "$work" -xzf "$f"
rm -rf "$ROOT/build/${PKG}-${UVER}"
# The sdist unpacks to a single top-level directory; rename it (the glob fails
# fast if the archive layout is unexpectedly different).
mv "$work"/*/ "$ROOT/build/${PKG}-${UVER}"
rm -rf "$work"

pack_orig
