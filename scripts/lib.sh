#!/usr/bin/env bash
# Shared helpers for the packaging scripts.
#
# fetch/fetch_rodin_bundle/pack_orig are used by the per-package get-orig.sh
# scripts, which run under build-deb.sh with ROOT/PKG/UVER/ORIG/DOWNLOADS
# exported.
# changelog_distribution is shared by build-deb.sh and make-repo.sh.

# fetch URL DEST -- download URL to DEST atomically, skipping if DEST already
# exists.  Writing to DEST.part first and renaming on success means an
# interrupted download is never left behind and mistaken for a cached file.
fetch() {
    local url="$1" dst="$2"
    [ -f "$dst" ] || { wget -qO "$dst.part" "$url" && mv "$dst.part" "$dst"; }
}

# fetch_github_tag -- download eventb-rossi/<PKG>'s "v<UVER>" source tarball and
# extract it into build/<PKG>-<UVER>/.  GitHub's tag tarball already unpacks to
# that top-level directory, which is exactly what build-deb.sh expects, so we
# extract straight into build/.  Shared by the get-orig.sh scripts of packages
# released as plain GitHub tags (rodin-headless, rossi).
fetch_github_tag() {
    local src="$DOWNLOADS/${PKG}-${UVER}.tar.gz"
    fetch "https://github.com/eventb-rossi/${PKG}/archive/refs/tags/v${UVER}.tar.gz" "$src"
    local d="$ROOT/build/${PKG}-${UVER}"
    rm -rf "$d"
    tar -C "$ROOT/build" -xzf "$src"
    [ -d "$d" ] || { echo "tarball did not yield $d" >&2; exit 1; }
}

# fetch_rodin_bundle -- download the Linux x86_64 archive of the eventb-rossi
# Rodin Bundle release that <UVER> names, verify it against the release's
# SHA256SUMS, and print its local path.  Shared by rodin and rodin-rc.
#
# The Debian upstream version maps one-to-one onto the release tag:
#   3.10.0+2611 -> v3.10.0-2611,  3.10.0+2609.2 -> v3.10.0-2609.2,
#   3.10.0+2611~rc1 -> v3.10.0-2611-rc1
# ("+" and "~rc" keep the Debian ordering right: above vanilla 3.10, and a
# candidate below its final release).  The asset name embeds an opaque build
# qualifier (commit date + hash) that the tag cannot reconstruct, so it is read
# from SHA256SUMS -- which also gives the checksum to verify the download with.
fetch_rodin_bundle() {
    local tag="v${UVER/+/-}"
    tag="${tag/\~rc/-rc}"
    local base="https://github.com/eventb-rossi/Rodin-Bundle/releases/download/${tag}"
    local sums="$DOWNLOADS/rodin-bundle-${tag}.SHA256SUMS"
    # Errors are returned explicitly: callers use this in a command substitution,
    # where bash does not apply set -e.
    fetch "$base/SHA256SUMS" "$sums" || { echo "cannot fetch $base/SHA256SUMS" >&2; return 1; }

    local line sum asset
    line="$(grep -E '^[0-9a-f]{64}  rodin-[^ /]+-rossi-linux\.gtk\.x86_64\.tar\.gz$' "$sums")" || {
        echo "no Linux x86_64 archive listed in $tag's SHA256SUMS" >&2; return 1; }
    [ "$(wc -l <<<"$line")" -eq 1 ] || {
        echo "several Linux x86_64 archives listed in $tag's SHA256SUMS" >&2; return 1; }
    sum="${line%% *}"
    asset="${line##* }"

    fetch "$base/$asset" "$DOWNLOADS/$asset" || { echo "cannot fetch $base/$asset" >&2; return 1; }
    (cd "$DOWNLOADS" && sha256sum --quiet -c - <<<"$sum  $asset") >&2 || {
        echo "checksum mismatch for $asset" >&2; rm -f "$DOWNLOADS/$asset"; return 1; }
    echo "$DOWNLOADS/$asset"
}

# pack_orig -- pack build/<PKG>-<UVER>/ into the orig tarball deterministically
# (root-owned) and remove the staging tree.
pack_orig() {
    tar -C "$ROOT/build" --owner=root --group=root -czf "$ORIG" "${PKG}-${UVER}"
    rm -rf "$ROOT/build/${PKG}-${UVER}"
}

# changelog_distribution FILE -- the target series (the Distribution field) from
# the top stanza of a debian/changelog, e.g. "noble".  Pure awk so it also works
# in the publish job, which installs only reprepro+gnupg (no dpkg-dev).
changelog_distribution() {
    awk 'NR==1 { sub(/^[^(]*\([^)]*\)[[:space:]]*/, ""); sub(/[[:space:]]*;.*/, ""); print $1; exit }' "$1"
}
