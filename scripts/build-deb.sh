#!/usr/bin/env bash
#
# Build one package from packages/<pkg>/.
#
# Each package directory contains:
#   debian/        the Debian packaging
#   get-orig.sh    a script that assembles build/<pkg>_<uver>.orig.tar.gz
#                  (top-level directory inside the tarball MUST be <pkg>-<uver>/)
#
# This driver figures out the upstream version from debian/changelog, makes
# sure the orig tarball exists, unpacks it, drops debian/ in, and runs
# dpkg-buildpackage.  Resulting .deb/.changes land in build/.
#
# Environment knobs:
#   BUILD_BINARY=1   build a binary package (default)
#   BUILD_SOURCE=0   also build a source package (.dsc/.changes for dput)
#
set -euo pipefail

pkg="${1:?usage: build-deb.sh <package>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGDIR="$ROOT/packages/$pkg"

[ -d "$PKGDIR/debian" ] || { echo "no such package: $pkg ($PKGDIR/debian missing)" >&2; exit 1; }

BUILD_BINARY="${BUILD_BINARY:-1}"
BUILD_SOURCE="${BUILD_SOURCE:-0}"

# Full version from changelog (e.g. 1.7-1) and upstream version (e.g. 1.7).
VER_FULL="$(dpkg-parsechangelog -l "$PKGDIR/debian/changelog" -S Version)"
UVER="${VER_FULL%-*}"          # strip the trailing -<debian_revision>
UVER="${UVER#*:}"              # strip a leading epoch if present

export ROOT PKG="$pkg" PKGDIR UVER
export DOWNLOADS="$ROOT/downloads"
export ORIG="$ROOT/build/${pkg}_${UVER}.orig.tar.gz"

mkdir -p "$ROOT/build" "$DOWNLOADS"

# 1. Assemble the upstream orig tarball if we do not have it yet.
if [ ! -f "$ORIG" ]; then
    echo "--- assembling orig tarball for $pkg $UVER"
    bash "$PKGDIR/get-orig.sh"
fi
[ -f "$ORIG" ] || { echo "get-orig.sh did not produce $ORIG" >&2; exit 1; }

# 2. Unpack into a clean source tree and add the packaging.
SRC="$ROOT/build/${pkg}-${UVER}"
rm -rf "$SRC"
tar -C "$ROOT/build" -xpf "$ORIG"
[ -d "$SRC" ] || { echo "orig tarball must contain top-level dir ${pkg}-${UVER}/" >&2; exit 1; }
rm -rf "$SRC/debian"
cp -a "$PKGDIR/debian" "$SRC/debian"

# 3. Build.
args=(-us -uc)
if [ "$BUILD_BINARY" = 1 ] && [ "$BUILD_SOURCE" = 1 ]; then
    args+=(-F)            # full: source + binary
elif [ "$BUILD_SOURCE" = 1 ]; then
    args+=(-S)            # source only
else
    args+=(-b)            # binary only
fi

( cd "$SRC" && dpkg-buildpackage "${args[@]}" )

echo "--- artifacts in $ROOT/build:"
ls -1 "$ROOT/build"/*.deb 2>/dev/null || true
ls -1 "$ROOT/build"/*.changes 2>/dev/null || true
