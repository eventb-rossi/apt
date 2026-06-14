#!/bin/sh
# Launcher for eventb-checker.
exec /usr/bin/java --enable-native-access=ALL-UNNAMED \
    -jar /usr/share/java/eventb-checker/eventb-checker.jar "$@"
