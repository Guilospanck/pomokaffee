#!/bin/zsh
# Builds build/Pomokaffee.app (menu bar only, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Pomokaffee.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pomokaffee "$APP/Contents/MacOS/Pomokaffee"
mkdir -p "$APP/Contents/Resources"
cp shortcuts/*.shortcut "$APP/Contents/Resources/"
ICONDIR=$(mktemp -d)
swift scripts/make-icon.swift "$ICONDIR"
iconutil -c icns "$ICONDIR/Pomokaffee.iconset" -o "$APP/Contents/Resources/Pomokaffee.icns"
rm -rf "$ICONDIR"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Pomokaffee</string>
  <key>CFBundleIdentifier</key><string>com.guilospanck.pomokaffee</string>
  <key>CFBundleExecutable</key><string>Pomokaffee</string>
  <key>CFBundleIconFile</key><string>Pomokaffee</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
