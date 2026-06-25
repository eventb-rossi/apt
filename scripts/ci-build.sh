#!/usr/bin/env bash
#
# Build the packages needed for the current change set, leaving the .deb files
# in build/.  Driven by CI but runnable locally for testing.
#
# Inputs (environment):
#   EVENT_TYPE   "pull_request" builds only the changed packages (fast PR
#                feedback); anything else builds the full set so a published
#                repo stays complete.  Default: full set.
#   RANGE        git diff range, passed through to changed-packages.sh and used
#                to pick which cached orig tarballs to invalidate.  Default:
#                HEAD~1..HEAD.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build

all="$(make -s list)"
changed="$(scripts/changed-packages.sh)"
echo "Changed packages:"; echo "${changed:-  (none)}"

# Invalidate cached orig tarballs only where the orig *content* can actually
# differ.  An orig depends on its package's get-orig.sh, on the shared assembly
# helper scripts/lib.sh, and on the upstream version -- never on Makefile, conf/
# or the workflow, even though those force a full *binary* rebuild via
# changed-packages.sh.  So invalidate on the orig's real inputs, not on the
# build-set signal (else adding a package, which must edit the Makefile, would
# wrongly drop -- and force regeneration of -- every other package's orig):
#   * a version bump self-heals -- the orig filename changes, so build-deb.sh
#     regenerates it without any deletion here;
#   * a changed packages/<pkg>/get-orig.sh -> drop just that package's orig;
#   * a changed scripts/lib.sh -> drop every orig (it can change any of them);
#   * an unresolvable range -> drop every orig to stay safe.
# These inputs (get-orig.sh, scripts/lib.sh) mirror the orig cache key in
# .github/workflows/build.yml -- keep the two in sync if the input set changes.
range="${RANGE:-HEAD~1..HEAD}"
if ! diff_files="$(git diff --name-only "$range" 2>/dev/null)" \
   || grep -qE '^scripts/lib\.sh$' <<<"$diff_files"; then
    rm -f build/*.orig.tar.gz
else
    while IFS= read -r f; do
        [[ "$f" == packages/*/get-orig.sh ]] || continue
        p="${f#packages/}"; rm -f "build/${p%%/*}"_*.orig.tar.gz
    done <<<"$diff_files"
fi

if [ "${EVENT_TYPE:-}" = "pull_request" ]; then
    to_build="$changed"
else
    to_build="$all"
fi

if [ -z "$to_build" ]; then
    echo "No packages to build."
    exit 0
fi
for p in $to_build; do
    echo "=== building $p ==="
    make "build-$p"
done
