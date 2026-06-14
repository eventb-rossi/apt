#!/bin/sh
# Launcher for ProB2-UI.
exec /usr/bin/java --enable-native-access=ALL-UNNAMED \
    -jar /usr/share/java/prob2-ui/prob2-ui.jar "$@"
