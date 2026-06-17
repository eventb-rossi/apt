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

# Invalidate cached orig tarballs only where the orig content can actually
# differ: a changed get-orig.sh.  A version bump already changes the orig
# filename (so it regenerates on its own), and debian/ edits are re-applied by
# dpkg-buildpackage so they never affect the orig.  When changed-packages.sh
# reports everything (shared change or an unresolvable range) invalidate every
# orig to stay safe.
if [ "$changed" = "$all" ]; then
    rm -f build/*.orig.tar.gz
else
    for f in $(git diff --name-only "${RANGE:-HEAD~1..HEAD}" -- 'packages/*/get-orig.sh' 2>/dev/null || true); do
        p="${f#packages/}"; rm -f "build/${p%%/*}"_*.orig.tar.gz
    done
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
