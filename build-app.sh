#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="StreamSafeArea"
VERSION="0.1.0"
BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
PLIST="$APP_DIR/Contents/Info.plist"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
STAGE_DIR="$DIST_DIR/dmg-stage"
INSTALL_APP="/Applications/${APP_NAME}.app"

mkdir -p "$DIST_DIR"
swift build -c release
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>StreamSafeArea</string>
  <key>CFBundleIdentifier</key>
  <string>studio.jackai.StreamSafeArea</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>StreamSafeArea</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>StreamSafeArea 需要访问摄像头，用于在悬浮窗中显示人物视频预览，帮助直播时避免遮挡主要内容。</string>
</dict>
</plist>
PLIST

# Create a simple DMG for distribution
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create   -volname "$APP_NAME"   -srcfolder "$STAGE_DIR"   -ov   -format UDZO   "$DMG_PATH" >/dev/null
rm -rf "$STAGE_DIR"

# Install to /Applications for local delivery
rm -rf "$INSTALL_APP"
cp -R "$APP_DIR" "$INSTALL_APP"

echo "Built app: $APP_DIR"
echo "Built dmg: $DMG_PATH"
echo "Installed app: $INSTALL_APP"
