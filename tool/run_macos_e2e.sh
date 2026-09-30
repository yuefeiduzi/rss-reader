#!/usr/bin/env bash
#
# macOS 端完整链路 e2e 一键跑。
#
# 做三件事：
#   1. 起 tool/e2e_fixture/ 的本地订阅源（已在跑就复用）
#   2. flutter test integration_test/macos_e2e_test.dart -d macos
#   3. 用 fixture 服务器的请求日志做**负面**校验（单测和 UI 断言看不到的部分）：
#      · placeholder.png 一次都不该被请求（data-src 回写回归点）
#      · article2.html 一次都不该被请求（摘要够长就不该抓全文）
#      · article3.html / article1.html / img2.png 必须被请求到
#
# 集成测试本身不碰用户数据（SharedPreferences 被 mock 成内存实现，见测试文件头），
# 本脚本会顺手校验真实 plist 没被改动。
#
# 用法：./tool/run_macos_e2e.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT=8100
FIXTURE_LOG="$(mktemp -t rss_fixture.XXXXXX)"
SERVER_PID=""
OWN_LOG=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# 1. Xcode
#
# xcode-select 还指向 CommandLineTools 时（见 AGENTS.md 陷阱 6），
# flutter_tools 会因为 `xcodebuild -version` 失败而直接报
# "Xcode not installed"，连 macOS 构建都过不去。临时用 DEVELOPER_DIR 绕过；
# 不写进系统设置是因为那一步要 sudo。tool/build_macos_dmg.sh 里同样这么做。
# ---------------------------------------------------------------------------
if ! xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  echo "[e2e] xcode-select 未指向 Xcode，临时使用 DEVELOPER_DIR=$DEVELOPER_DIR"
fi

# ---------------------------------------------------------------------------
# 2. fixture 服务器
# ---------------------------------------------------------------------------
if curl -sf "http://127.0.0.1:$PORT/feed.xml" >/dev/null 2>&1; then
  echo "[e2e] 复用已在运行的 fixture（:${PORT}）—— 请求日志校验将跳过"
else
  python3 tool/e2e_fixture/serve.py "$PORT" >"$FIXTURE_LOG" 2>&1 &
  SERVER_PID=$!
  for _ in $(seq 1 25); do
    curl -sf "http://127.0.0.1:$PORT/feed.xml" >/dev/null 2>&1 && break
    sleep 0.2
  done
  if ! curl -sf "http://127.0.0.1:$PORT/feed.xml" >/dev/null 2>&1; then
    echo "[e2e] fixture 起不来，日志："
    cat "$FIXTURE_LOG"
    exit 1
  fi
  OWN_LOG="$FIXTURE_LOG"
  echo "[e2e] fixture 已启动（:${PORT}），日志 $FIXTURE_LOG"
fi

# ---------------------------------------------------------------------------
# 3. 跑集成测试
# ---------------------------------------------------------------------------
PREFS="$HOME/Library/Containers/org.ross.rssReader/Data/Library/Preferences/org.ross.rssReader.plist"

# 只比对 flutter.* 三个 key（用户数据）。
# 同一份 plist 里还有应用自己的状态，比如窗口位置存档
# ``NSWindow Frame MainWindow``（改窗口位置时会写进去），那不是用户数据。
prefs_data_hash() {
  python3 - "$PREFS" <<'PY' 2>/dev/null || echo "unavailable"
import hashlib, json, plistlib, sys
try:
    with open(sys.argv[1], 'rb') as fh:
        data = plistlib.load(fh)
except Exception:
    print('missing')
    raise SystemExit
user = {k: data[k] for k in data if k.startswith('flutter.')}
print(hashlib.sha256(json.dumps(user, sort_keys=True, default=str).encode()).hexdigest())
PY
}

PREFS_BEFORE="$(prefs_data_hash)"

echo "[e2e] flutter test integration_test/macos_e2e_test.dart -d macos"
flutter test integration_test/macos_e2e_test.dart -d macos -r expanded
STATUS=$?

# ---------------------------------------------------------------------------
# 4. 校验
# ---------------------------------------------------------------------------
if [ -n "$PREFS_BEFORE" ]; then
  PREFS_AFTER="$(prefs_data_hash)"
  if [ "$PREFS_BEFORE" != "$PREFS_AFTER" ]; then
    echo "[e2e] ⚠️  用户数据（flutter.* 三个 key）被改动了。测试本应完全 hermetic，请检查 SharedPreferences mock。"
    STATUS=1
  else
    echo "[e2e] ✓ 用户数据未被动过（flutter.* 三个 key 未变）"
  fi
fi

if [ -n "$OWN_LOG" ] && [ "$STATUS" -eq 0 ]; then
  echo "[e2e] 请求日志校验（fixture 侧证据）"
  CHECK_FAILED=0

  must_hit() {
    if grep -q "GET /$1" "$OWN_LOG"; then
      echo "[e2e] ✓ 请求过 /$1"
    else
      echo "[e2e] ✗ 从未请求 /$1 —— $2"
      CHECK_FAILED=1
    fi
  }
  must_not_hit() {
    if grep -q "GET /$1" "$OWN_LOG"; then
      echo "[e2e] ✗ 不应请求 /$1 却请求了 —— $2"
      grep "GET /$1" "$OWN_LOG" | head -3
      CHECK_FAILED=1
    else
      echo "[e2e] ✓ 未请求 /$1"
    fi
  }

  must_hit article3.html '摘要不足 200 字符时必须抓全文'
  must_hit article1.html '富文本文章的正文也应被抓取'
  must_hit img2.png '懒加载图片的真实地址应被写回 src 后取到'
  must_not_hit placeholder.png 'data-src 回写若回归就会去取占位图'
  must_not_hit article2.html '摘要够长时不该抓全文（过度抓取回归点）'

  if [ "$CHECK_FAILED" -ne 0 ]; then
    STATUS=1
  fi
fi

exit "$STATUS"