#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
CONFIG=${1:-debug}
CLANG_MODULE_CACHE_PATH="$ROOT/build/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/build/module-cache" \
swift build --disable-sandbox --cache-path build/swiftpm-cache -c "$CONFIG" \
  --product Calabel --build-path build/swift-build
APP="$ROOT/build/Calabel.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/build/swift-build/$CONFIG/Calabel" "$APP/Contents/MacOS/Calabel"
cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Calabel</string>
<key>CFBundleIdentifier</key><string>local.calabel.app</string>
<key>CFBundleName</key><string>Calabel</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSCalendarsFullAccessUsageDescription</key><string>선택한 캘린더의 일정을 메뉴 막대에 표시합니다.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$APP"
