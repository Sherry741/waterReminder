#!/bin/bash
# 把 waterReminder 装到「应用程序」，去掉浏览器隔离标记后打开。
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/waterReminder.app"
DEST="/Applications/waterReminder.app"

if [[ ! -d "$SRC" ]]; then
  osascript -e 'display alert "找不到 waterReminder.app" message "请在打开的安装盘里运行这个脚本。" as critical'
  exit 1
fi

rm -rf "$DEST"
ditto "$SRC" "$DEST"
xattr -cr "$DEST" || true
open "$DEST"
