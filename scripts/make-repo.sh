#!/usr/bin/env bash
#
# Assemble an APT repository under repo/ from the .deb (and optional source)
# packages in build/, using reprepro.
#
# Signing:
#   Set REPO_GPG_KEY to the key id/fingerprint/email of a secret key to sign
#   the repository (recommended).  The matching public key is exported to
#   repo/KEY.gpg for users to import.  If REPO_GPG_KEY is unset the repository
#   is left unsigned (apt then needs "[trusted=yes]"); a warning is printed.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$ROOT/repo"
# The codename reprepro publishes under is defined once, in conf/distributions;
# read it back so the includedeb suite cannot drift from the repo config.
CODENAME="$(awk -F': *' '/^Codename:/ {print $2; exit}' "$ROOT/conf/distributions")"
[ -n "$CODENAME" ] || { echo "no Codename: in conf/distributions" >&2; exit 1; }

shopt -s nullglob
debs=("$ROOT"/build/*.deb)
dscs=("$ROOT"/build/*.dsc)
if [ ${#debs[@]} -eq 0 ] && [ ${#dscs[@]} -eq 0 ]; then
    echo "nothing to publish: no .deb/.dsc in build/ (run 'make build-all' first)" >&2
    exit 1
fi

rm -rf "$REPO"
mkdir -p "$REPO/conf"
cp "$ROOT/conf/distributions" "$REPO/conf/distributions"

if [ -n "${REPO_GPG_KEY:-}" ]; then
    echo "SignWith: $REPO_GPG_KEY" >> "$REPO/conf/distributions"
    gpg --armor --export "$REPO_GPG_KEY" > "$REPO/KEY.gpg"
    echo "exported public key to $REPO/KEY.gpg"
else
    echo "WARNING: REPO_GPG_KEY not set -- building an UNSIGNED repository." >&2
    echo "         Users will need 'deb [trusted=yes] ...' to use it." >&2
fi

for d in "${debs[@]}"; do
    echo "+ includedeb $d"
    reprepro -b "$REPO" includedeb "$CODENAME" "$d"
done
for s in "${dscs[@]}"; do
    echo "+ includedsc $s"
    reprepro -b "$REPO" includedsc "$CODENAME" "$s"
done

echo
echo "APT repository ready under: $REPO"
reprepro -b "$REPO" list "$CODENAME" || true
