#!/usr/bin/env bash
#
# Assemble an APT repository under repo/ from the .deb (and optional source)
# packages in build/, using reprepro.
#
# Signing:
#   Set REPO_GPG_KEY to the key id/fingerprint/email of a secret key to sign
#   the repository.  The matching public key is exported to repo/KEY.gpg for
#   users to import.  Signing is REQUIRED by default: if REPO_GPG_KEY is unset
#   this script errors out rather than produce an unusable (unsigned) repo.
#   Pass REPO_ALLOW_UNSIGNED=1 to build an unsigned repo (apt then needs
#   "[trusted=yes]") -- for local testing only.
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
    # Fail early if the key isn't actually available to sign with (typo, or the
    # private key was never imported) -- otherwise reprepro fails later, opaquely.
    gpg --list-secret-keys "$REPO_GPG_KEY" >/dev/null 2>&1 || {
        echo "ERROR: no secret key matching REPO_GPG_KEY=$REPO_GPG_KEY in the keyring." >&2
        exit 1
    }
    # SignWith is per-paragraph in reprepro, so add it to every distribution
    # stanza (each has exactly one Codename: line).  A single appended line would
    # sign only the last suite and leave the others (e.g. noble) unsigned.
    awk -v key="$REPO_GPG_KEY" '
        { print }
        /^Codename:/ { print "SignWith: " key }
    ' "$ROOT/conf/distributions" > "$REPO/conf/distributions"
    gpg --armor --export "$REPO_GPG_KEY" > "$REPO/KEY.gpg"
    echo "exported public key to $REPO/KEY.gpg"
elif [ "${REPO_ALLOW_UNSIGNED:-0}" = 1 ]; then
    cp "$ROOT/conf/distributions" "$REPO/conf/distributions"
    echo "WARNING: REPO_GPG_KEY not set -- building an UNSIGNED repository (REPO_ALLOW_UNSIGNED=1)." >&2
    echo "         Users will need 'deb [trusted=yes] ...' to use it." >&2
else
    echo "ERROR: REPO_GPG_KEY not set -- refusing to build an unsigned repository." >&2
    echo "       Set REPO_GPG_KEY to your signing key, or pass REPO_ALLOW_UNSIGNED=1 to override." >&2
    exit 1
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
