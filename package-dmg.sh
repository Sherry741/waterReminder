#!/bin/bash
# 打出可直接安装的 DMG：打开后把 waterReminder.app 拖进 Applications。
# 用法: ./package-dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

APP_NAME="waterReminder"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
STAGE="dist/dmg-stage"
VOL="$APP_NAME"
RW_DMG="dist/${APP_NAME}-rw.dmg"
DMG="dist/${APP_NAME}-${VERSION}.dmg"

rm -rf "$STAGE" "$RW_DMG" "$DMG"
mkdir -p "$STAGE"
ditto "dist/WaterReminder.app" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$RW_DMG" >/dev/null

MOUNT_DIR="/Volumes/${VOL}"
hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" >/dev/null
if [[ ! -d "$MOUNT_DIR" ]]; then
  echo "挂载临时 DMG 失败" >&2
  exit 1
fi

cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  rm -rf "$STAGE" "$RW_DMG"
}
trap cleanup EXIT

# 尽量排成「左边应用、右边应用程序」的安装窗口；没有辅助权限时跳过。
osascript <<EOF >/dev/null 2>&1 || true
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {220, 140, 780, 500}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set position of item "${APP_NAME}.app" of container window to {150, 180}
    set position of item "Applications" of container window to {410, 180}
    close
    open
    update without registering applications
    delay 0.8
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
trap - EXIT
rm -rf "$STAGE" "$RW_DMG"

echo "Created $(pwd)/$DMG"
echo "打开后把 ${APP_NAME}.app 拖到 Applications 即可安装。"
