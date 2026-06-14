#!/usr/bin/env bash
# Assemble the orig tarball for evbt from the upstream self-executable jar.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

tag="v${UVER}"
jar_url="https://github.com/viklauverk/EventBTool/releases/download/${tag}/evbt"
lic_url="https://raw.githubusercontent.com/viklauverk/EventBTool/${tag}/LICENSE"

jar="$DOWNLOADS/evbt-${UVER}.jar"
lic="$DOWNLOADS/evbt-${UVER}.LICENSE"
fetch "$jar_url" "$jar"
fetch "$lic_url" "$lic"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
cp "$lic" "$d/LICENSE"

# Upstream ships a self-executable jar: a /bin/sh launcher stub prepended to a
# zip archive. Rebuild it as a plain jar (clean zip) so it is not mistaken for a
# broken shell script; "java -jar" runs it exactly the same way.
python3 - "$jar" "$d/evbt.jar" <<'PY'
import sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    for it in zin.infolist():
        zout.writestr(it, zin.read(it.filename))
PY

pack_orig
