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
source "$ROOT/scripts/lib.sh"
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
#
# Most packages build natively on the host runner.  A package whose changelog
# targets a different Ubuntu series than the host (rossi -> resolute, for its
# rustc >= 1.85) is built inside an sbuild chroot of that series, so it compiles
# against that series' archive toolchain exactly as Launchpad will -- no rustup,
# no host toolchain.  Source packages never need a toolchain (they only pack the
# tree), so they always build on the host.
DIST="$(changelog_distribution "$PKGDIR/debian/changelog")"
HOST_DIST="$(. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-}")"
cross=0
case "$DIST" in
    "$HOST_DIST"|unstable|UNRELEASED|"") ;;
    *) cross=1 ;;
esac

# A .dsc is needed whenever a source package is requested, and also as the input
# to sbuild for a cross-series binary build.  -d skips the build-dep check so a
# cross-series package (whose Build-Depends aren't in the host archive) still
# produces its source package on the host.
need_dsc=0
[ "$BUILD_SOURCE" = 1 ] && need_dsc=1
[ "$BUILD_BINARY" = 1 ] && [ "$cross" = 1 ] && need_dsc=1
if [ "$need_dsc" = 1 ]; then
    ( cd "$SRC" && dpkg-buildpackage -S -us -uc -d )
fi

if [ "$BUILD_BINARY" = 1 ]; then
    if [ "$cross" = 1 ]; then
        for t in sbuild mmdebstrap; do
            command -v "$t" >/dev/null 2>&1 || {
                echo "$t is required to build '$pkg' for '$DIST' on a '$HOST_DIST' host." >&2
                echo "Install it:  sudo apt install sbuild mmdebstrap uidmap zstd" >&2
                exit 1
            }
        done
        # Create the target-series chroot on first use (idempotent); the build
        # then runs inside it with that series' archive toolchain.
        "$ROOT/scripts/make-chroot.sh" "$DIST"
        dsc="$ROOT/build/${pkg}_${VER_FULL#*:}.dsc"   # the .dsc just built above (epoch dropped)
        sbuild --chroot-mode=unshare --dist="$DIST" \
            --arch="$(dpkg --print-architecture)" \
            --no-run-lintian --build-dir="$ROOT/build" "$dsc"
    else
        ( cd "$SRC" && dpkg-buildpackage -b -us -uc )
    fi
fi

echo "--- artifacts in $ROOT/build:"
ls -1 "$ROOT/build"/*.deb 2>/dev/null || true
ls -1 "$ROOT/build"/*.changes 2>/dev/null || true
