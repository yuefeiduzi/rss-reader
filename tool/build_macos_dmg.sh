#!/usr/bin/env bash
#
# 构建 macOS 安装包（.dmg，拖进 Applications 即安装）。
#
#   ./tool/build_macos_dmg.sh
#
# 产物（都在 build/dist/ 下，被 .gitignore 覆盖）：
#   RSS-Reader-<版本>-universal.dmg
#   SHA256SUMS.txt
#
# GitHub Actions 里用的是同一个脚本（.github/workflows/release.yml），
# 所以本地和 CI 的产物形态是一致的 —— 改这里就等于改 CI。
#
# ── 关于签名 ──────────────────────────────────────────────────────────────
# 本机没有 Developer ID 证书（`security find-identity -v -p codesigning` 为 0 个），
# 工程里 CODE_SIGN_IDENTITY = "-"，走的是 **ad-hoc 签名**。
#
# 这和 openOTP 的处理方式一致：不买 Apple 证书，改用文档 + 校验和兜住用户体验。
# ad-hoc 的后果是 `spctl -a -t exec` 返回 rejected：
#   · 自己构建、自己装的：不受影响。实测从只读 DMG 卷直接启动也能跑
#   · 别人从网上下载的：会被 Gatekeeper 拦，需要按 docs/UNSIGNED.md 放行一次
#
# 「自签名证书」解决不了分发问题 —— 证书不在别人的信任库里，照样被拦，
# 只是换一条提示。唯一能过的是 Apple 签发的 Developer ID + 公证（99 USD/年）。
# ────────────────────────────────────────────────────────────────────────

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

APP_NAME="RSS Reader"
BUNDLE_ID="org.ross.rssReader"
DIST="$REPO_ROOT/build/dist"

# 本地 Flutter 装在自定义位置，不在 PATH 默认路径里。
# CI 上由 subosito/flutter-action 装好并已在 PATH 中，这两个目录都不存在。
if [ -d "$HOME/development/flutter/bin" ]; then
  PATH="$HOME/development/flutter/bin:$PATH"
fi
if [ -d /opt/homebrew/bin ]; then
  PATH="$PATH:/opt/homebrew/bin"
fi
export PATH

# xcode-select 目前仍指向 CommandLineTools（见 AGENTS.md 陷阱 6）。
# 这里不是「给上更保险」—— 实测不给的话 `flutter build macos` 会直接报
# “Xcode not installed”（flutter_tools 要跑 `xcodebuild -version`），
# 所以这条 export 是**必需**的。CI runner 上 xcode-select 本来就指向 Xcode。
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')"
DMG_NAME="RSS-Reader-${VERSION}-universal.dmg"
DMG="$DIST/$DMG_NAME"

echo "==> 构建 release"
flutter build macos --release

APP="$REPO_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "构建产物不存在：$APP" >&2; exit 1; }

echo "==> 组装 DMG 内容"
STAGE="$DIST/stage"
rm -rf "$DIST"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
# 拖进这里的 /Applications 就是安装
ln -s /Applications "$STAGE/Applications"
# 清掉复制时带过来的扩展属性，别把 quarantine 位包进 DMG
xattr -cr "$STAGE/$APP_NAME.app"

# 放行说明随包带上 —— 每个下载的人第一眼就该看到它，而不是自己上网查
cp "$REPO_ROOT/docs/UNSIGNED.md" "$STAGE/首次打开请看这里.md"

echo "==> 生成 DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO -quiet \
  "$DMG"
rm -rf "$STAGE"

echo "==> 计算校验和"
# 与 openOTP 一致：DMG 和 SHA256SUMS.txt 一起发，下载者能确认传输完整
( cd "$DIST" && shasum -a 256 "$DMG_NAME" > SHA256SUMS.txt )

echo
echo "完成："
echo "  $DMG"
echo "  $DIST/SHA256SUMS.txt"
echo
echo "架构：$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")   大小：$(du -h "$DMG" | cut -f1)"
echo "bundle id：$BUNDLE_ID"
echo "签名：$(codesign -dv "$APP" 2>&1 | grep -o 'adhoc\|Signature=.*' | head -1)"
cat "$DIST/SHA256SUMS.txt"