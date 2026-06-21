#!/usr/bin/env bash
# Install the build toolchain used by the CI jobs (build and publish).
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    dpkg-dev debhelper devscripts fakeroot lintian dh-python \
    python3-all python3-setuptools python3-wheel pybuild-plugin-pyproject \
    build-essential reprepro gnupg \
    desktop-file-utils unzip cpio wget curl ca-certificates xz-utils \
    default-jdk openjdk-25-jre-headless maven \
    sbuild mmdebstrap uidmap zstd

# rossi vendors its crates into the orig tarball during orig assembly
# (get-orig.sh runs `cargo vendor`).  That step runs on the host and needs a
# cargo new enough to parse rossi's Rust 2024 edition manifests (>= 1.85), which
# noble's apt cargo is not, so use the rustup toolchain on the CI runner for it.
# The package *build* uses the target series' archive rustc/cargo instead (see
# rossi's Build-Depends and the sbuild chroot build-deb.sh builds in), not rustup.
if command -v rustup >/dev/null 2>&1; then
    rustup default stable
else
    # Don't fail the whole script (the other packages don't need Rust), but make
    # the missing prerequisite loud so a rossi orig-assembly failure isn't a
    # mystery.
    echo "ci-install-deps: rustup not found -- rossi's orig assembly (cargo vendor)" >&2
    echo "  needs cargo >= 1.85 to parse its Rust 2024 manifests; install it from" >&2
    echo "  https://rustup.rs or 'make build-rossi' will fail at the vendoring step." >&2
fi

# The sbuild tooling above lets build-deb.sh build cross-series packages (rossi
# -> resolute) inside a chroot of their series.  The chroot itself is created on
# demand by build-deb.sh (via scripts/make-chroot.sh) only when such a package is
# actually built, so unrelated PRs don't pay the bootstrap cost.
