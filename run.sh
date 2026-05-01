#!/bin/bash
set -e

cd "$(dirname "$0")"

# Baue das Projekt falls nötig
if [ ! -d "build/install/PDFTrenner" ]; then
    ./gradlew installDist
fi

APP_HOME="build/install/PDFTrenner"
LIB_DIR="$APP_HOME/lib"

# JavaFX JARs für den Modulpfad
MODULE_PATH=''
while IFS= read -r -d '' jar; do
    MODULE_PATH="${MODULE_PATH}${jar}:"
done < <(find "$LIB_DIR" -name 'javafx-*.jar' -print0)

# Classpath: alle JARs außer JavaFX
CP_JARS=''
while IFS= read -r -d '' jar; do
    CP_JARS="${CP_JARS}${jar}:"
done < <(find "$LIB_DIR" -name '*.jar' ! -name 'javafx-*.jar' -print0)

# Debug aktivieren mit: PDFTRENNER_DEBUG=1 ./run.sh
if [ -n "$PDFTRENNER_DEBUG" ]; then
  DEBUG_ARG="-Dpdftrenner.debug=true"
  echo "Debug-Modus aktiviert"
else
  DEBUG_ARG=""
fi

# macOS-spezifisches Dock-Icon (kein AWT-Konflikt, wird vor JVM-Start gesetzt)
DOCK_ICON_ARG=""
if [ "$(uname)" = "Darwin" ] && [ -f "src/main/resources/icon.png" ]; then
  DOCK_ICON_ARG="-Xdock:icon=src/main/resources/icon.png"
fi

java \
  $DOCK_ICON_ARG \
  --module-path "$MODULE_PATH" \
  --add-modules javafx.controls,javafx.fxml,javafx.graphics,javafx.swing \
  --enable-native-access=javafx.graphics,javafx.swing \
  -Dprism.verbose=false \
  $DEBUG_ARG \
  -cp "$CP_JARS" \
  de.posy.pdftrenner.Launcher \
  "$@"
