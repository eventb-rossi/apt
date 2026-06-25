#!/usr/bin/env bash
# Assemble the orig tarball for rossi (a Cargo workspace).
#
# rossi is built from source with Cargo.  To keep the actual .deb build offline
# and reproducible, every crate dependency is vendored here (this needs network
# and a recent cargo, like b2program's Gradle build) and the package build then
# runs `cargo build --frozen` against the vendored tree.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

fetch_github_tag
d="$ROOT/build/${PKG}-${UVER}"

# Vendor all crates and point Cargo at the vendored copies, so the build needs
# no network.  cargo writes the source-replacement config stanza to stdout,
# which we append to the project's cargo config.
#
# An upstream tree that already configures a cargo [source.*] (a registry mirror
# or its own vendoring) would collide with the [source.crates-io] cargo vendor
# emits (TOML duplicate key), silently breaking the offline build.  Bail out so a
# future release that does this is handled deliberately rather than shipping a
# broken orig tarball.
for cfg in "$d/.cargo/config.toml" "$d/.cargo/config"; do
    if [ -e "$cfg" ] && grep -q '^\[source\.' "$cfg"; then
        echo "upstream ships $cfg with a [source.*] section; vendoring would conflict" >&2
        exit 1
    fi
done
mkdir -p "$d/.cargo"
( cd "$d" && cargo vendor --locked vendor ) >> "$d/.cargo/config.toml"

pack_orig
