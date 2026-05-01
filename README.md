# PDFTrenner

PDFTrenner ist ein JavaFX-basiertes Tool zum interaktiven Aufteilen von PDF-Dateien.
Es zeigt die PDF-Seiten an und erlaubt das Markieren von Bereichen, die als separate
PDFs gespeichert werden.

## Features

- Interaktives Blättern durch PDF-Seiten mit Pfeiltasten
- Markieren von Start- (`F`) und Endseite (`L`) für Extraktion
- Automatische Titel-Erkennung via Tesseract OCR (obere 10% der ersten Seite)
- Zustands-Speicherung: Merkt sich die letzte Position pro PDF
- Native Installer fuer macOS, Windows und Linux (JRE ist enthalten)

## Voraussetzungen

### Zum Entwickeln / Ausfuehren

- **Java 21+** mit `jpackage` (fuer native Builds)
- **Gradle** (Wrapper ist im Projekt enthalten)
- **Tesseract OCR** installiert und im `PATH`
  - macOS: `brew install tesseract`
  - Windows: [UB Mannheim Installer](https://github.com/UB-Mannheim/tesseract/wiki)
  - Linux: `sudo apt install tesseract-ocr tesseract-ocr-deu`

### Zum Betrieb (fertige Installer)

Nur **Tesseract OCR** muss auf dem System installiert sein. Das JRE ist in den
Installern bereits enthalten.

## Schnellstart

### Entwicklung (macOS / Linux)

```bash
./gradlew installDist
./run.sh DATEI.pdf
```

### Entwicklung (Windows)

```cmd
gradlew.bat installDist
gradlew.bat run --args="DATEI.pdf"
```

## Steuerung

| Taste | Aktion |
|-------|--------|
| `←` / `→` | Seite zurueck / vor |
| `F` | Startseite setzen (erste Seite des neuen Teildokuments) |
| `L` | Endseite setzen — oeffnet Dialog mit automatisch erkanntem Titel |

Die extrahierten PDFs landen im Unterordner `Manual_Splits/` neben der
Quell-PDF.

## Native Builds

Das Projekt nutzt `jpackage` (im JDK enthalten), um eigenstaendige Anwendungen
zu erstellen. **Cross-Compile ist nicht moeglich** — jeder Build muss auf der
Zielplattform erfolgen.

### macOS

```bash
# Eigenstaendige .app-Anwendung (JRE enthalten)
./gradlew jpackageMac

# DMG-Installer
./gradlew jpackageMacDmg
```

Ergebnis: `build/distributions/PDFTrenner.app`  
Start: Doppelklick auf `PDFTrenner.app` oder
```bash
open build/distributions/PDFTrenner.app --args DATEI.pdf
```

### Windows

Auf einem Windows-Rechner mit installiertem JDK 21+:

```cmd
:: Eigenstaendiges Verzeichnis (JRE enthalten)
gradlew.bat jpackageWin

:: MSI-Installer
gradlew.bat jpackageWinMsi
```

Ergebnis: `build\distributions\PDFTrenner\PDFTrenner.exe`

### Linux

```bash
# Eigenstaendiges Verzeichnis (JRE enthalten)
./gradlew jpackageLinux

# .deb-Paket (Debian / Ubuntu)
./gradlew jpackageLinuxDeb
```

Ergebnis: `build/distributions/PDFTrenner/bin/PDFTrenner`

### Automatisch (plattformabhaengig)

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
      Launcher.java         — Einstiegspunkt (JavaFX Application.launch)
      PdfSplitterApp.java   — Hauptanwendung mit UI und OCR
    resources/
      icon.*                — Anwendungs-Icons (optional)
build.gradle                — Gradle-Konfiguration mit jpackage-Tasks
run.sh                      — Entwicklungs-Startskript (macOS/Linux)
```

## Hinweise

- **Tesseract** muss im `PATH` verfuegbar sein (`tesseract --version`)
- **Zustandsdateien** (`.pdftrenner.state`) werden neben der jeweiligen PDF
  angelegt und enthalten die zuletzt bearbeitete Startseite
- **Ausgabe:** `Manual_Splits/` — Unterordner neben der Quell-PDF fuer
  extrahierte Seitenbereiche
- **Fenster im Vordergrund:** Auf macOS wird das Fenster nach dem Start aktiv
  in den Vordergrund geholt
