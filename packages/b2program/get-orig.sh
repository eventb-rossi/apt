#!/usr/bin/env bash
# Assemble the orig tarball for b2program.
#
# Upstream publishes no tagged release and no prebuilt jar, so the fat jar is
# built here once from a pinned commit with the Gradle wrapper (this needs
# network access).  The resulting jar is vendored into the orig tarball, keeping
# the actual .deb build offline and reproducible.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

# Pinned upstream commit (matches the snapshot date in the Debian version).
commit=6deb3e17a4cdb97ccc2e2946f7aaafb8e5fa2ba6

src="$DOWNLOADS/b2program-${commit}.tar.gz"
url="https://github.com/favu100/b2program/archive/${commit}.tar.gz"
fetch "$url" "$src"

work=$(mktemp -d)
tar -C "$work" -xzf "$src"
bdir="$work/b2program-${commit}"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
( cd "$bdir" && chmod +x gradlew && ./gradlew --no-daemon --console=plain -x test fatJar )

jar=$(ls "$bdir"/build/libs/*all*.jar 2>/dev/null | head -1)
[ -n "$jar" ] || { echo "fatJar build produced no *-all jar" >&2; exit 1; }

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
cp "$jar" "$d/b2program.jar"
[ -f "$bdir/LICENSE" ] && cp "$bdir/LICENSE" "$d/LICENSE" || true
rm -rf "$work"

pack_orig
