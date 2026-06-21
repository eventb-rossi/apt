#!/usr/bin/env bash
# Shared helpers for the packaging scripts.
#
# fetch/pack_orig are used by the per-package get-orig.sh scripts, which run
# under build-deb.sh with ROOT/PKG/UVER/ORIG/DOWNLOADS exported.
# changelog_distribution is shared by build-deb.sh and make-repo.sh.

# fetch URL DEST -- download URL to DEST atomically, skipping if DEST already
# exists.  Writing to DEST.part first and renaming on success means an
# interrupted download is never left behind and mistaken for a cached file.
fetch() {
    local url="$1" dst="$2"
    [ -f "$dst" ] || { wget -qO "$dst.part" "$url" && mv "$dst.part" "$dst"; }
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
