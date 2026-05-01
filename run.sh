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
MODULE_PATH=$(find "$LIB_DIR" -name 'javafx-*.jar' | tr '\n' ':')

# Classpath: alle JARs außer JavaFX
CP_JARS=$(find "$LIB_DIR" -name '*.jar' ! -name 'javafx-*.jar' | tr '\n' ':')

# Debug aktivieren mit: PDFTRENNER_DEBUG=1 ./run.sh
if [ -n "$PDFTRENNER_DEBUG" ]; then
  DEBUG_ARG="-Dpdftrenner.debug=true"
  echo "Debug-Modus aktiviert"
else
  DEBUG_ARG=""
fi

java \
  --module-path "$MODULE_PATH" \
  --add-modules javafx.controls,javafx.fxml,javafx.graphics,javafx.swing \
  --enable-native-access=javafx.graphics,javafx.swing \
  -Djava.awt.headless=false \
  -Djavafx.verbose=false \
  -Dprism.verbose=false \
  $DEBUG_ARG \
  -cp "$CP_JARS" \
  de.posy.pdftrenner.Launcher \
  "$@"
