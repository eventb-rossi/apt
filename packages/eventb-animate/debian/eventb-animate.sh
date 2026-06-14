#!/bin/sh
# Launcher for eventb-animate.
#
# On JDK 23+ the bundled ProB/Guice code triggers a sun.misc.Unsafe memory
# access deprecation warning; --sun-misc-unsafe-memory-access=allow silences it.
# The option is unknown to JDK <23, so add it only when the JRE is new enough.
JAVA=/usr/bin/java
opts=
major=$("$JAVA" -version 2>&1 | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -1)
if [ "${major:-0}" -ge 23 ] 2>/dev/null; then
    opts="--sun-misc-unsafe-memory-access=allow"
fi
exec "$JAVA" $opts -jar /usr/share/java/eventb-animate/eventb-animate.jar "$@"
