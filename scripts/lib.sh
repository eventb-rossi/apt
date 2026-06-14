#!/usr/bin/env bash
# Shared helpers for the per-package get-orig.sh scripts.
#
# Every get-orig.sh runs under build-deb.sh with ROOT/PKG/UVER/ORIG/DOWNLOADS
# exported and sources this file to reuse the common download and pack steps.

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
