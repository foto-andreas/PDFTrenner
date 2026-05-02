#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-1.0}"
APP_NAME="PDFTrenner"
BINARY="PDFTrennerSwift"
DMG_NAME="${APP_NAME}Swift-${VERSION}-universal.dmg"

echo "=== Building ${APP_NAME} v${VERSION} (universal) ==="

# Build both architectures
echo "Building arm64..."
swift build -c release --arch arm64

echo "Building x86_64..."
swift build -c release --arch x86_64

# Create universal binary
echo "Creating universal binary..."
mkdir -p .build/universal
lipo -create \
  .build/arm64-apple-macosx/release/${BINARY} \
  .build/x86_64-apple-macosx/release/${BINARY} \
  -output .build/universal/${BINARY}

# Build .app bundle
echo "Building .app bundle..."
APPDIR="${APP_NAME}.app"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS"
mkdir -p "$APPDIR/Contents/Resources"

cp .build/universal/${BINARY} "$APPDIR/Contents/MacOS/${BINARY}"

cat > "$APPDIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>de</string>
    <key>CFBundleExecutable</key>
    <string>${BINARY}</string>
    <key>CFBundleIdentifier</key>
    <string>de.posy.pdftrenner.swift</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo -n "APPL????" > "$APPDIR/Contents/PkgInfo"
cp -R ${BINARY}/Assets.xcassets "$APPDIR/Contents/Resources/"

# Generate icon
# Generate macOS-style icon (rounded corners + padding)
echo "Generating macOS icon..."
ORIG_ICON="icon_orig_512.png"
ORIG_ICON_PATH="${BINARY}/Assets.xcassets/AppIcon.appiconset/${ORIG_ICON}"
if [ ! -f "$ORIG_ICON_PATH" ]; then
    ORIG_ICON="icon_512x512.png"
    ORIG_ICON_PATH="${BINARY}/Assets.xcassets/AppIcon.appiconset/${ORIG_ICON}"
fi

ICON_MASTER="/tmp/pdftrenner_icon_master.png"
python3 - "$ORIG_ICON_PATH" "$ICON_MASTER" << 'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageChops

CANVAS = 1024
INSET = 0.178
CORNER_RATIO = 0.2235

src = Image.open(sys.argv[1]).convert("RGBA")
sw, sh = src.size
content_size = int(CANVAS * (1 - 2 * INSET))
corner_radius = int(CANVAS * CORNER_RATIO)

scale = content_size / max(sw, sh)
new_w, new_h = int(sw * scale), int(sh * scale)
src = src.resize((new_w, new_h), Image.LANCZOS)

canvas = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
draw = ImageDraw.Draw(canvas)
draw.rounded_rectangle([0, 0, CANVAS - 1, CANVAS - 1], radius=corner_radius, fill=(255, 255, 255, 255))

content = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
x, y = (CANVAS - new_w) // 2, (CANVAS - new_h) // 2
content.paste(src, (x, y), src)

mask = Image.new('L', (CANVAS, CANVAS), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, CANVAS - 1, CANVAS - 1], radius=corner_radius, fill=255)
content_alpha = content.split()[3]
masked_alpha = ImageChops.multiply(content_alpha, mask)
content.putalpha(masked_alpha)

result = Image.alpha_composite(canvas, content)
border = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
ImageDraw.Draw(border).rounded_rectangle([0, 0, CANVAS - 1, CANVAS - 1], radius=corner_radius, outline=(0, 0, 0, 40), width=2)
result = Image.alpha_composite(result, border)
result.save(sys.argv[2], 'PNG')
PYEOF

ICON_SRC="$ICON_MASTER"
ICONSET_DIR="/tmp/PDFtrenner.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png" -s format png &>/dev/null
sips -z 32 32 "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" -s format png &>/dev/null
sips -z 32 32 "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png" -s format png &>/dev/null
sips -z 64 64 "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" -s format png &>/dev/null
sips -z 128 128 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png" -s format png &>/dev/null
sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" -s format png &>/dev/null
sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png" -s format png &>/dev/null
sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" -s format png &>/dev/null
sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png" -s format png &>/dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png" -s format png &>/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APPDIR/Contents/Resources/AppIcon.icns"

# Build DMG
echo "Building DMG..."
DMG_DIR=".build/dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APPDIR" "$DMG_DIR/${APP_NAME}.app"
ln -s /Applications "$DMG_DIR/Applications"

rm -f "$DMG_NAME"
hdiutil create -volname "${APP_NAME}" \
  -srcfolder "$DMG_DIR" \
  -ov -format UDZO \
  "$DMG_NAME" 2>&1

rm -rf "$DMG_DIR"

echo "=== Done ==="
echo "App:     ${APPDIR}"
echo "Binary:  $(lipo -info "$APPDIR/Contents/MacOS/${BINARY}")"
echo "DMG:     $(ls -lh "$DMG_NAME" | awk '{print $5, $NF}')"