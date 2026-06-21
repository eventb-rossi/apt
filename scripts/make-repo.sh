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
source "$ROOT/scripts/lib.sh"
REPO="$ROOT/repo"
# The codenames reprepro publishes under are defined once, in conf/distributions;
# read them back so the suites here cannot drift from the repo config.  The first
# is the default for any package that does not pin a series.
mapfile -t CODENAMES < <(awk -F': *' '/^Codename:/ {print $2}' "$ROOT/conf/distributions")
[ "${#CODENAMES[@]}" -gt 0 ] || { echo "no Codename: in conf/distributions" >&2; exit 1; }
DEFAULT_CODENAME="${CODENAMES[0]}"

# suite_for <artifact> -- the reprepro suite a built .deb/.dsc belongs in.  Each
# package pins its target series in debian/changelog (e.g. rossi -> resolute, for
# rustc >= 1.85); read it back from the source tree so the artifact lands in the
# matching suite.  Falls back to the default codename when the series is absent or
# not one this repo publishes.
suite_for() {
    local base pkg ch dist
    base="$(basename "$1")"
    pkg="${base%%_*}"
    ch="$ROOT/packages/$pkg/debian/changelog"
    dist=""
    [ -f "$ch" ] && dist="$(changelog_distribution "$ch")"
    case " ${CODENAMES[*]} " in
        *" $dist "*) printf '%s\n' "$dist" ;;
        *)           printf '%s\n' "$DEFAULT_CODENAME" ;;
    esac
}

shopt -s nullglob
debs=("$ROOT"/build/*.deb)
dscs=("$ROOT"/build/*.dsc)
if [ ${#debs[@]} -eq 0 ] && [ ${#dscs[@]} -eq 0 ]; then
    echo "nothing to publish: no .deb/.dsc in build/ (run 'make build-all' first)" >&2
    exit 1
fi

rm -rf "$REPO"
mkdir -p "$REPO/conf"

if [ -n "${REPO_GPG_KEY:-}" ]; then
    # SignWith is per-paragraph in reprepro, so add it to every distribution
    # stanza (each has exactly one Codename: line).  A single appended line would
    # sign only the last suite and leave the others (e.g. noble) unsigned.
    awk -v key="$REPO_GPG_KEY" '
        { print }
        /^Codename:/ { print "SignWith: " key }
    ' "$ROOT/conf/distributions" > "$REPO/conf/distributions"
    gpg --armor --export "$REPO_GPG_KEY" > "$REPO/KEY.gpg"
    echo "exported public key to $REPO/KEY.gpg"
else
    cp "$ROOT/conf/distributions" "$REPO/conf/distributions"
    echo "WARNING: REPO_GPG_KEY not set -- building an UNSIGNED repository." >&2
    echo "         Users will need 'deb [trusted=yes] ...' to use it." >&2
fi

for d in "${debs[@]}"; do
    suite="$(suite_for "$d")"
    echo "+ includedeb $suite $d"
    reprepro -b "$REPO" includedeb "$suite" "$d"
done
for s in "${dscs[@]}"; do
    suite="$(suite_for "$s")"
    echo "+ includedsc $suite $s"
    reprepro -b "$REPO" includedsc "$suite" "$s"
done

echo
echo "APT repository ready under: $REPO"
for c in "${CODENAMES[@]}"; do
    reprepro -b "$REPO" list "$c" || true
done
