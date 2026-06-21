#!/usr/bin/env bash
#
# Create an sbuild chroot for a target Ubuntu series, used to build packages that
# target a newer series than the host runner (rossi -> resolute, for rustc >=
# 1.85).  Uses sbuild's unshare backend with mmdebstrap, so it needs no root,
# schroot, or persistent setup -- it just drops a rootfs tarball where sbuild
# looks for it.  Idempotent: a no-op if the tarball already exists.
#
# Building inside this chroot mirrors Launchpad: Build-Depends (rustc/cargo) are
# installed from the series' archive, then debian/rules runs `cargo build
# --frozen` offline against the vendored crates in the orig tarball.
#
set -euo pipefail

DIST="${1:?usage: make-chroot.sh <ubuntu-series>}"
ARCH="$(dpkg --print-architecture)"
# sbuild --chroot-mode=unshare looks here by convention.
TARBALL="${HOME}/.cache/sbuild/${DIST}-${ARCH}.tar.zst"

if [ -f "$TARBALL" ]; then
    echo "chroot for $DIST/$ARCH already present: $TARBALL"
    exit 0
fi

mkdir -p "$(dirname "$TARBALL")"

# universe holds the versioned rustc/cargo packages rossi build-depends on.
# --variant=buildd gives a minimal build environment (build-essential only).
mmdebstrap \
    --variant=buildd \
    --arch="$ARCH" \
    --components="main,universe" \
    --include="ca-certificates" \
    "$DIST" "$TARBALL" \
    "http://archive.ubuntu.com/ubuntu"

echo "created sbuild chroot: $TARBALL"
