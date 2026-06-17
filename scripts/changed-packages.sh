#!/usr/bin/env bash
#
# Print, one per line, the packages that need rebuilding for the current change
# set.  Used by CI to build only what changed instead of every package.
#
# A package is "changed" when any file under packages/<pkg>/ changed.  When a
# shared file changes (scripts/, conf/, Makefile, the build workflow) -- or the
# diff range cannot be resolved -- every package is printed (safe full rebuild).
#
# The diff range comes from $RANGE, e.g. "origin/main...HEAD" for a pull request
# or "<before>..<sha>" for a push.  With no $RANGE it falls back to HEAD~1..HEAD.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Fail loudly if the package list is unavailable: a broken toolchain must not be
# mistaken for "nothing changed".  Command substitution (not process
# substitution) so set -e catches a failing make; then assert it is non-empty.
ALL_RAW="$(make -s list)"
mapfile -t ALL <<<"$ALL_RAW"
[ -n "${ALL[0]:-}" ] || {
    echo "changed-packages.sh: 'make -s list' returned no packages" >&2
    exit 1
}
emit_all() { printf '%s\n' "${ALL[@]}"; }

range="${RANGE:-HEAD~1..HEAD}"

# Cannot resolve the range (shallow clone, all-zero base, missing ref): rebuild
# everything rather than risk shipping a stale package.
if ! files="$(git diff --name-only "$range" 2>/dev/null)"; then
    emit_all
    exit 0
fi

# Any shared/infra change can affect every package.
if grep -qE '^(scripts/|conf/|Makefile$|\.github/workflows/build\.yml$)' <<<"$files"; then
    emit_all
    exit 0
fi

declare -A changed=()
while IFS= read -r f; do
    [[ "$f" == packages/*/* ]] || continue
    pkg="${f#packages/}"; pkg="${pkg%%/*}"
    changed["$pkg"]=1
done <<<"$files"

# Print in the canonical PKGS order; the loop over ALL is what filters to real
# packages, so a stray non-package key in `changed` is simply never printed.
for p in "${ALL[@]}"; do
    [ -n "${changed[$p]:-}" ] && echo "$p"
done
exit 0
