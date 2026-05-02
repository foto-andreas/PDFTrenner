# PDFTrenner

PDFTrenner ist ein Tool zum interaktiven Aufteilen von PDF-Dateien.
Es zeigt die PDF-Seiten an und erlaubt das Markieren von Bereichen, die als separate
PDFs gespeichert werden.

Es gibt drei Varianten:

| Variante | Plattform | Sprache | OCR |
|----------|-----------|---------|-----|
| **JavaFX** | macOS, Windows, Linux | Java 21+ | Tesseract |
| **Swift** | macOS 12+ (ARM + Intel) | SwiftUI | Vision-Framework |
| **iOS** | iOS 16+ (iPhone + iPad) | SwiftUI | Vision-Framework |

## Features (alle Varianten)

- Interaktives Blättern durch PDF-Seiten
- Markieren der Startseite (`F` / Button) öffnet Titeleingabe mit OCR-Vorschlag
- Endseite setzen (`L` / Button) speichert den Abschnitt sofort
- Automatische Titel-Erkennung (obere 10% der Startseite)
- Zustands-Speicherung: Merkt sich die letzte Position pro PDF
- Umlaut-Konvertierung in Dateinamen (ä→ae, ö→oe, ü→ue, ß→ss)

---

## JavaFX-Variante

### Voraussetzungen

#### Zum Entwickeln / Ausfuehren

- **Java 21+** mit `jpackage` (fuer native Builds)
- **Gradle** (Wrapper ist im Projekt enthalten)
- **Tesseract OCR** installiert und im `PATH`
  - macOS: `brew install tesseract`
  - Windows: [UB Mannheim Installer](https://github.com/UB-Mannheim/tesseract/wiki)
  - Linux: `sudo apt install tesseract-ocr tesseract-ocr-deu`

#### Zum Betrieb (fertige Installer)

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
| `F` | Startseite setzen — öffnet Titeleingabe-Dialog (Titel wird per OCR vorausgefüllt) |
| `Seite` | Seitennummer eingeben und direkt zur Seite springen |
| `L` | Endseite setzen und Abschnitt sofort speichern |

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
Start: Doppelklick auf `PDFTrenner.app` bedient den FileChooser-Dialog.
Per Terminal:
```bash
open build/distributions/PDFTrenner.app
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

---

## Swift-Variante (macOS)

Native macOS-Anwendung mit SwiftUI und PDFKit. Keine externen Abhaengigkeiten —
OCR laeuft ueber das im System enthaltene Vision-Framework.

### Voraussetzungen

- **macOS 12+** (Monterey)
- **Xcode Command Line Tools** (`xcode-select --install`)
- Kein Tesseract erforderlich

### Schnellstart

```bash
cd PDFTrennerSwift
swift build -c release
.build/release/PDFTrennerSwift DATEI.pdf
```

### DMG erstellen

```bash
cd PDFTrennerSwift
./build_dmg.sh              # Universal Binary (ARM + Intel) + DMG
```

Ergebnis: `PDFTrennerSwift-1.0-universal.dmg`

### Projektstruktur

```
PDFTrennerSwift/
├── Package.swift                    # Swift-Package, macOS 12+
├── build_dmg.sh                     # Build-Skript (Universal Binary + DMG)
└── PDFTrennerSwift/
    ├── PDFTrennerApp.swift          # @main App-Einstieg, AppDelegate
    ├── ContentView.swift            # UI + ViewModel + TitlePanelController
    ├── OCRHelper.swift              # Vision-basierte OCR-Titelerkennung
    ├── PDFDocumentHelper.swift      # PDF-Seitenextraktion
    ├── StateHelper.swift            # Persistenz des Bearbeitungsstatus
    └── Assets.xcassets/            # App-Icon (macOS-Stil)
```

### Unterschiede zur JavaFX-Variante

| Aspekt | JavaFX | Swift |
|--------|--------|-------|
| OCR | Tesseract (extern) | Vision-Framework (System) |
| Titeleingabe | Modaler Dialog | NSPanel rechts neben dem Fenster |
| Beenden | Menu / Strg+C | Fenster schließen beendet die App |
| Installation | JRE + Installer | DMG oder `swift build` |

---

## iOS-Variante (iPhone / iPad)

Native iOS-App mit SwiftUI. Gleiche Funktionalitaet wie die macOS-Version,
aber mit touch-optimierter UI (Sheet statt NSPanel).

### Voraussetzungen

- **iOS 16+**
- **Xcode** (fuer Build und Deployment)
- **Apple ID** (kostenlos moeglich, 7-Tage-Provisioning)

### Build & Deployment

1. `PDFTrenneriOS/PDFTrenneriOS.xcodeproj` in Xcode öffnen
2. Unter *Signing & Capabilities* die persönliche Apple ID als Team auswaehlen
3. iPhone/iPad per USB anschließen
4. Build & Run auf dem Geraet

Ohne bezahlten Developer-Account verfaengt das Profil nach 7 Tagen.
Neu signieren via Xcode verlaengert es.

### Projektstruktur

```
PDFTrenneriOS/
└── PDFTrenneriOS/
    ├── PDFTrennerApp.swift          # @main App-Einstieg
    ├── ContentView.swift            # UI + ViewModel (Sheet-basiert)
    ├── OCRHelper.swift              # Vision-OCR (identisch zur macOS-Version)
    ├── PDFDocumentHelper.swift      # PDF-Seitenextraktion
    ├── StateHelper.swift            # Persistenz
    └── Assets.xcassets/            # App-Icon
```

### Unterschiede zur macOS-Variante

| Aspekt | macOS | iOS |
|--------|-------|-----|
| Titeleingabe | NSPanel (.floating) rechts neben Fenster | SwiftUI .sheet (.medium detent) |
| Dateiauswahl | NSOpenPanel | UIDocumentPickerViewController |
| Tastaturkuerzel | F, L, Pfeiltasten | Buttons in der UI |
| Seitensprung | Button `Seite` mit Eingabedialog | Button `Seite` mit Sheet |
| PDF-Anzeige | PDFView (AppKit) | PDFView (UIKit) |

---

## Dokumentation

- **PDFTrennerSwift/BENUTZERDOKU.md** — Benutzerdokumentation (rein fachlich, deutsch)
- **PDFTrennerSwift/SYSTEMDOKU.md** — Systemdokumentation (technisch, deutsch)
- Beide auch als `.html` und `.pdf` verfuegbar
