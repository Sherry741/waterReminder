#!/bin/bash
# 构建喝水提醒.app
# 用法: ./build.sh && open dist/WaterReminder.app
set -euo pipefail
cd "$(dirname "$0")"

ARCH="$(uname -m)"
SDK="$(xcrun --show-sdk-path)"
APP="dist/WaterReminder.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -swift-version 5 -O -sdk "$SDK" \
  -target "${ARCH}-apple-macosx14.0" \
  -framework AppKit \
  -framework SwiftUI \
  -framework UserNotifications \
  Sources/Theme.swift \
  Sources/AppModel.swift \
  Sources/ReminderNotifier.swift \
  Sources/OnboardingView.swift \
  Sources/SelfTest.swift \
  Sources/FloatingView.swift \
  Sources/SettingsView.swift \
  Sources/StatsView.swift \
  Sources/ResizeBorder.swift \
  Sources/AppDelegate.swift \
  Sources/main.swift \
  -o "$APP/Contents/MacOS/WaterReminder"

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/default-reward-bg.jpg "$APP/Contents/Resources/default-reward-bg.jpg"
codesign --force --sign - "$APP"
xattr -cr "$APP" || true
echo "Built $(pwd)/$APP"
