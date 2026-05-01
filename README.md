# PDFTrenner

PDFTrenner ist ein JavaFX-basiertes Tool zum interaktiven Aufteilen von PDF-Dateien. Es zeigt die PDF-Seiten an und erlaubt das Markieren von Bereichen, die als separate PDFs gespeichert werden.

## Features

- Interaktives Blättern durch PDF-Seiten mit Pfeiltasten
- Markieren von Start- (`F`) und Endseite (`L`) für Extraktion
- Automatische Titel-Erkennung via Tesseract OCR (obere 10% der ersten Seite)
- Zustands-Speicherung: Merkt sich die letzte Position pro PDF
- Native Installer für macOS, Windows und Linux

## Voraussetzungen

- **Java 17+** (mit `jpackage` für native Builds)
- **Tesseract OCR** installiert (für Titel-Erkennung)
  - macOS: `brew install tesseract tesseract-lang`
  - Windows: [Installer](https://github.com/UB-Mannheim/tesseract/wiki)
  - Linux: `sudo apt install tesseract-ocr tesseract-ocr-deu`

## Schnellstart (Entwicklung)

```bash
./gradlew installDist
./run.sh [DATEI.pdf]
```

Steuerung:
- `← / →` — Seite vor/zurück
- `F` — Startseite setzen
- `L` — Endseite setzen & Dialog zur Eingabe des Dateinamens

## Native Builds

Das Projekt nutzt `jpackage` (im JDK enthalten), um eigenständige Anwendungen zu erstellen. **Cross-Compile ist nicht möglich — jeder Build muss auf der Zielplattform erfolgen.**

### macOS

```bash
# Eigenständige .app-Anwendung
./gradlew jpackageMac

# DMG-Installer
./gradlew jpackageMacDmg
```

Ergebnis: `build/distributions/PDFTrenner.app`

### Windows

Auf einem Windows-Rechner mit installiertem JDK 17+ und Gradle:

```bash
# Eigenständiges Verzeichnis
gradlew.bat jpackageWin

# MSI-Installer
gradlew.bat jpackageWinMsi
```

Ergebnis: `build\distributions\PDFTrenner\`

### Linux

```bash
# Eigenständiges Verzeichnis
./gradlew jpackageLinux

# .deb-Paket (Debian/Ubuntu)
./gradlew jpackageLinuxDeb
```

Ergebnis: `build/distributions/PDFTrenner/`

### Automatisch (plattformabhängig)

```bash
./gradlew jpackageAuto
```

Erkennt das Betriebssystem automatisch und erstellt das passende Paket.

## Icons (optional)

Lege Icons unter `src/main/resources/` ab:
- `icon.icns` — macOS
- `icon.ico` — Windows
- `icon.png` — Linux (mindestens 32x32 px)

Wenn keine Icons vorhanden sind, werden Standard-Icons verwendet.

## Projektstruktur

```
src/
  main/
    java/de/posy/pdftrenner/
      Launcher.java      — Einstiegspunkt (JavaFX-Start)
      PdfSplitterApp.java — Hauptanwendung
    resources/
      icon.*             — Anwendungs-Icons (optional)
build.gradle             — Gradle-Konfiguration
run.sh                   — Entwicklungs-Startskript (macOS/Linux)
```

## Hinweise

- Tesseract muss im `PATH` verfügbar sein (`tesseract --version`)
- Die Zustandsdateien (`.pdftrenner.state`) werden neben der jeweiligen PDF angelegt
- `Manual_Splits/` — Ausgabeverzeichnis für extrahierte Seitenbereiche
