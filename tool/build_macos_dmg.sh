#!/usr/bin/env bash
#
# 构建 macOS 安装包（.dmg，拖进 Applications 即安装）。
#
#   ./tool/build_macos_dmg.sh
#
# 产物：build/dist/RSS-Reader-<版本>-universal.dmg
#
# 关于签名与公证（2026-09-30 实测）：
#   本机没有 Developer ID 证书（`security find-identity -v -p codesigning` 为 0 个），
#   工程里 CODE_SIGN_IDENTITY = "-"，所以走的是 **ad-hoc 签名**。
#   后果：`spctl -a -t exec` 会返回 rejected。这只影响**从网上下载**的包
#   （下载物带 quarantine 位才会被 Gatekeeper 拦）；本机自己构建、自己装的
#   不受影响，实测从只读 DMG 卷直接启动也能跑。
#   要给别人的话，得买 Developer ID 并做 notarization。

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

APP_NAME="RSS Reader"
DIST="$REPO_ROOT/build/dist"

# Flutter 装在自定义位置，不在 PATH 默认路径里
export PATH="$HOME/development/flutter/bin:/opt/homebrew/bin:$PATH"

# xcode-select 目前仍指向 CommandLineTools（见 AGENTS.md 陷阱 6），
# macOS 构建能忍，但显式给上更保险
if [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')"
DMG="$DIST/RSS-Reader-${VERSION}-universal.dmg"

echo "==> 构建 release"
flutter build macos --release

APP="$REPO_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP" ]; then
  echo "构建产物不存在：$APP" >&2
  exit 1
fi

echo "==> 组装 DMG 内容"
STAGE="$DIST/stage"
rm -rf "$DIST"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
# 拖进这里的 /Applications 就是安装
ln -s /Applications "$STAGE/Applications"
# 清掉复制时带过来的扩展属性，别把 quarantine 位包进 DMG
xattr -cr "$STAGE/$APP_NAME.app"

cat > "$STAGE/安装说明.txt" <<'EOF'
把左侧的「RSS Reader」拖进右侧的 Applications 文件夹即可安装。

首次打开若被 Gatekeeper 拦下（提示「无法验证开发者」），是因为这个包没有做
Apple 公证（公证需要付费的 Developer ID 证书）。任选一种方式放行：

  · 右键点 App → 打开 → 再点一次「打开」
  · 或：系统设置 → 隐私与安全性 → 找到 RSS Reader → 「仍要打开」

数据位置（沙盒应用，按 bundle id 分目录）：
  ~/Library/Containers/org.ross.rssReader/

调试时想直接看里面的订阅源：
  python3 -c "import plistlib,json,sys; d=plistlib.load(open(sys.argv[1],'rb')); \
  print([json.loads(x)['title'] for x in d['flutter.feeds']])" \
  ~/Library/Containers/org.ross.rssReader/Data/Library/Preferences/org.ross.rssReader.plist
EOF

echo "==> 生成 DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO -quiet \
  "$DMG"
rm -rf "$STAGE"

echo
echo "完成：$DMG"
echo "架构：$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")   大小：$(du -h "$DMG" | cut -f1)"
echo "sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"