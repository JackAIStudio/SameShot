#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SameShot"
VERSION="0.1.3"
TEAM_ID="92K6CKZ4KM"
SIGN_IDENTITY="Developer ID Application: jieke wu (${TEAM_ID})"
# Local keychain profile name used by notarytool
NOTARY_PROFILE="SameShot-notary"

# Build and sign outside Documents/File Provider to avoid com.apple.provenance detritus
WORK_ROOT="$(mktemp -d /tmp/SameShot-release.XXXXXX)"
cleanup() {
  rm -rf "$WORK_ROOT"
}
trap cleanup EXIT

BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
WORK_APP="$WORK_ROOT/${APP_NAME}.app"
MACOS_DIR="$WORK_APP/Contents/MacOS"
RES_DIR="$WORK_APP/Contents/Resources"
PLIST="$WORK_APP/Contents/Info.plist"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
WORK_DMG="$WORK_ROOT/${APP_NAME}-${VERSION}.dmg"
STAGE_DIR="$WORK_ROOT/dmg-stage"
INSTALL_APP="/Applications/${APP_NAME}.app"
ENTITLEMENTS="$WORK_ROOT/${APP_NAME}.entitlements"

mkdir -p "$DIST_DIR"
swift build -c release

rm -rf "$WORK_APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# App icon（状态栏图标由代码绘制，不依赖资源文件）
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  ditto --norsrc "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

# Copy binary with no resource forks
ditto --norsrc "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>SameShot</string>
  <key>CFBundleIdentifier</key>
  <string>studio.jackai.SameShot</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>SameShot</string>
  <key>CFBundleDisplayName</key>
  <string>SameShot</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.3</string>
  <key>CFBundleVersion</key>
  <string>4</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>SameShot 需要访问摄像头，用于在录制画面中显示人物画中画预览，帮助你在录制时及时发现并避开遮挡。</string>
</dict>
</plist>
PLIST

cat > "$ENTITLEMENTS" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.device.camera</key>
  <true/>
</dict>
</plist>
ENT

xattr -cr "$WORK_APP" || true

codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$MACOS_DIR/$APP_NAME"

codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$WORK_APP"

codesign --verify --deep --strict --verbose=2 "$WORK_APP"

# Stage DMG contents
mkdir -p "$STAGE_DIR"
ditto --norsrc "$WORK_APP" "$STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGE_DIR/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$WORK_DMG" >/dev/null

codesign --force --timestamp --sign "$SIGN_IDENTITY" "$WORK_DMG"

xcrun notarytool submit "$WORK_DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$WORK_DMG"
xcrun stapler validate "$WORK_DMG"
xcrun stapler staple "$WORK_APP" || true
xcrun stapler validate "$WORK_APP" || true

# Publish artifacts back to project dist and Applications
rm -rf "$APP_DIR"
ditto --norsrc "$WORK_APP" "$APP_DIR"
cp -f "$WORK_DMG" "$DMG_PATH"

rm -rf "$INSTALL_APP"
ditto --norsrc "$WORK_APP" "$INSTALL_APP"
xcrun stapler staple "$INSTALL_APP" || true

echo "Built app: $APP_DIR"
echo "Built dmg: $DMG_PATH"
echo "Installed app: $INSTALL_APP"
echo "Signed with: $SIGN_IDENTITY"
echo "Notarized with profile: $NOTARY_PROFILE"
