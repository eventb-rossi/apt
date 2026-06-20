#!/usr/bin/env bash
# Install the build toolchain used by the CI jobs (build and publish).
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    dpkg-dev debhelper devscripts fakeroot lintian dh-python \
    python3-all python3-setuptools python3-wheel pybuild-plugin-pyproject \
    build-essential reprepro gnupg \
    desktop-file-utils unzip cpio wget curl ca-certificates xz-utils \
    default-jdk openjdk-25-jre-headless maven

# rossi is built from source with Cargo.  noble's apt rustc is too old for its
# crate set, so use the recent rustup toolchain shipped on the CI runner (gcc,
# needed by a few -sys crates, already comes from build-essential above).
if command -v rustup >/dev/null 2>&1; then
    rustup default stable
else
    # Don't fail the whole script (the other packages don't need Rust), but make
    # the missing prerequisite loud so a rossi build failure isn't a mystery.
    echo "ci-install-deps: rustup not found -- the rossi package needs a recent" >&2
    echo "  Rust toolchain (noble's apt rustc is too old); install it from" >&2
    echo "  https://rustup.rs or 'make build-rossi' will fail with cargo: not found." >&2
fi
