#!/usr/bin/env bash
# Assemble the orig tarball for b2program.
#
# Upstream publishes no tagged release and no prebuilt jar, so the fat jar is
# built here once from a pinned commit with the Gradle wrapper (this needs
# network access).  The resulting jar is vendored into the orig tarball, keeping
# the actual .deb build offline and reproducible.
#
# b2program depends on de.hhu.stups:antlr-parser, which upstream only ever
# published as a 0.1.0-SNAPSHOT.  Sonatype expires snapshots that are not
# republished, and that one is now gone from every Maven repository (Central
# releases, Central snapshots and the retired OSSRH host all 404), so the fat jar
# can no longer be built the way upstream builds it.  Its *source* is still
# published, so we build the parser here from a pinned commit first.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

# Pinned upstream commits.  b2program's matches the snapshot date in the Debian
# version; antlr-parser's is the contemporaneous "Update to current ANTLR".
commit=6deb3e17a4cdb97ccc2e2946f7aaafb8e5fa2ba6
parser_commit=2855185e34bceb793ca87a57cfd121c297cbf31e

src="$DOWNLOADS/b2program-${commit}.tar.gz"
url="https://github.com/favu100/b2program/archive/${commit}.tar.gz"
fetch "$url" "$src"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar -C "$work" -xzf "$src"
bdir="$work/b2program-${commit}"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Keep the locally built parser in a build-local Maven repository: a stale copy
# from an earlier run can never be picked up, and nothing is left on the host.
m2="$work/m2"

# Resolve the parser we are about to publish, and skip the signing that
# antlr-parser's publication asks for (it is GPG-signed upstream; we have no key,
# and signing.required=false makes those tasks skip instead of fail).
init="$work/init.gradle"
cat > "$init" <<'GRADLE'
beforeProject { project ->
    project.repositories { mavenLocal() }
    project.plugins.withId("signing") {
        project.extensions.getByName("signing").required = false
    }
}
GRADLE

gradle_opts=(--no-daemon --console=plain "-Dmaven.repo.local=$m2" --init-script "$init")

# 1. antlr-parser -> the build-local Maven repository.
#
# Clone rather than unpack a tarball: antlr-parser's build.gradle stamps the jar
# with `git rev-parse HEAD` at configuration time and aborts when that fails.  A
# tarball carries no .git, and unpacking one inside another git repository would
# silently stamp *that* repository's commit instead, so use a real checkout and
# verify we are on the pinned commit.
pdir="$work/antlr-parser"
git clone --quiet https://github.com/hhu-stups/antlr-parser "$pdir"
git -C "$pdir" checkout --quiet "$parser_commit"
got="$(git -C "$pdir" rev-parse HEAD)"
[ "$got" = "$parser_commit" ] || {
    echo "antlr-parser: pinned commit $parser_commit, but checkout is at $got" >&2
    exit 1
}

( cd "$pdir" && chmod +x gradlew && ./gradlew "${gradle_opts[@]}" publishToMavenLocal )

[ -d "$m2/de/hhu/stups/antlr-parser" ] || {
    echo "antlr-parser: publishToMavenLocal wrote nothing to $m2" >&2
    exit 1
}

# 2. b2program's fat jar, resolving antlr-parser from that local repository.
( cd "$bdir" && chmod +x gradlew && ./gradlew "${gradle_opts[@]}" -x test fatJar )

jar=$(ls "$bdir"/build/libs/*all*.jar 2>/dev/null | head -1)
[ -n "$jar" ] || { echo "fatJar build produced no *-all jar" >&2; exit 1; }

# A fat jar is only useful if the classes actually made it in.  Resolution that
# silently yielded an empty or partial artifact must not ship.  List the jar once
# and check that listing, so an unreadable jar (or a missing unzip) is reported
# as itself instead of being misattributed to a missing package.
listing=$(unzip -Z1 "$jar") || { echo "cannot list $jar" >&2; exit 1; }
for prefix in de/hhu/stups/codegenerator de/prob/parser/antlr org/antlr/v4/runtime; do
    grep -q "^$prefix/" <<<"$listing" || {
        echo "fat jar is missing $prefix/ classes" >&2
        exit 1
    }
done

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d"
cp "$jar" "$d/b2program.jar"
[ -f "$bdir/LICENSE" ] && cp "$bdir/LICENSE" "$d/LICENSE" || true

pack_orig
