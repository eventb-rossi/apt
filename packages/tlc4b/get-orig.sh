#!/usr/bin/env bash
# Assemble the orig tarball for tlc4b: the tlc4b jar plus its full runtime
# dependency closure, fetched from Maven Central via Maven.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"; mkdir -p "$d/jars"

work=$(mktemp -d)
cat > "$work/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>local</groupId>
  <artifactId>tlc4b-deps</artifactId>
  <version>0</version>
  <packaging>pom</packaging>
  <dependencies>
    <dependency>
      <groupId>de.hhu.stups</groupId>
      <artifactId>tlc4b</artifactId>
      <version>${UVER}</version>
    </dependency>
  </dependencies>
</project>
EOF

mvn -q -B -f "$work/pom.xml" \
    org.apache.maven.plugins:maven-dependency-plugin:3.6.1:copy-dependencies \
    -DincludeScope=runtime -DoutputDirectory="$d/jars"
rm -rf "$work"

[ -n "$(ls -A "$d/jars")" ] || { echo "no jars resolved for tlc4b" >&2; exit 1; }

pack_orig
