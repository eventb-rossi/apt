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
