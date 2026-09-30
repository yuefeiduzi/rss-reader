# rss_reader

Flutter 编写的跨平台 RSS/Atom 阅读器。数据全部保存在本地（SharedPreferences），无后端、无账号、无云同步。

## 平台支持现状

代码包含 Android / iOS / macOS / Windows / Linux / Web 六个平台的工程目录。
**开发优先级：macOS → Android → iOS**，Web 保留为 UI 演示。

| 平台 | 状态 | 说明 |
|---|---|---|
| **macOS** | ✅ 可运行，**能抓真实订阅源** | 当前唯一「能正经用」的目标，已实测抓到真实 RSS/Atom |
| Web | ⚠️ 可运行，但功能受限 | **无法抓取真实订阅源**，见下方「已知限制」 |
| Android | ❌ 未验证 | 需要 Android SDK |
| iOS | ⏸ 暂缓 | 有意排在 macOS / Android 之后：需先修 `xcode-select` 并选 Development Team |
| Windows / Linux | ❌ 未验证 | 需在对应系统上构建 |

> 想真正用起来，跑 macOS 桌面端：Web 端受浏览器同源策略限制，抓不到 RSS。
> Xcode / CocoaPods 的安装坑记在 [AGENTS.md](AGENTS.md)。

**注意**：macOS 上「能编译、能抓源」已验证，但完整交互链路尚未跑过，
详见 [docs/known-issues.md](docs/known-issues.md) 2.5.4。

## 已知限制

### Web 端抓不到订阅源（架构限制，仅限 Web）

`RssService` 会设置自定义 `User-Agent`，使请求成为「非简单请求」，浏览器因此发起 CORS 预检；而真实世界的 RSS 服务器不会响应预检，请求被浏览器直接拦截。

这不是可以靠改代码绕过的 bug，需要引入 CORS 代理层。本地起一个带 `Access-Control-Allow-Origin` 的测试服务器可以走通全流程，说明解析链路本身是好的。

**macOS / Android / iOS 没有这个问题** —— dio 在原生端不受同源策略约束，
macOS 沙盒的 `com.apple.security.network.client` 也已在 entitlements 里放行。
实测 macOS 上可直接抓：`sspai.com/feed`、`ruanyifeng.com/blog/atom.xml`、
`coolshell.cn/feed`。

> 已知限制：`dio` 用 dart:io 默认直连，**不读系统代理**，所以 App 抓不到需要
> 翻墙的源（实测 `feeds.bbci.co.uk` 超时），国内源正常。

### Web 端备份功能不可用

`BackupService` 依赖 `dart:io` 与 `path_provider`，在 Web 上运行时抛 `UnsupportedError`。

## 功能

见 [FEATURES.md](FEATURES.md)（标注了每个功能的真实实现状态）。

## 快速开始

### 环境要求

- Flutter **3.47.4**（Dart 3.13.3）
- 中国大陆网络建议配置镜像（否则下载引擎产物只有 ~400KB/s）

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

### 安装与运行

```bash
flutter pub get
flutter run -d macos           # 开发模式（推荐）
flutter run -d chrome          # 开发模式（Web）
```

### 构建

```bash
flutter build macos --release  # 产物在 build/macos/Build/Products/Release/
flutter build web --release    # 产物在 build/web/
flutter build apk --release    # 需要 Android SDK
```

### 打包成可安装的 DMG

```bash
./tool/build_macos_dmg.sh
# → build/dist/RSS-Reader-1.0.0-universal.dmg（22MB，x86_64 + arm64）
```

拖进 Applications 即安装。**未做 Apple 公证**（需付费开发者证书）：
本机自己构建自己装不受影响，但如果这个包是从网上下载来的，首次打开会被
Gatekeeper 拦下 —— 按 DMG 里「安装说明.txt」右键打开即可放行。

### 验证

```bash
flutter analyze                # 应为 0 error
flutter test                   # 单元测试
```

端到端验证：**macOS 端直接添加真实源**（无 CORS 问题）；Web 端受 CORS 限制，
需要用仓库自带的本地 fixture：

```bash
flutter build web --release
python3 -m http.server 8099 --directory build/web   # 应用
python3 tool/e2e_fixture/serve.py 8100               # 带 CORS 的测试源
# 打开 http://127.0.0.1:8099/，添加 http://127.0.0.1:8100/feed.xml
```

fixture 的每个文件都对应一个修过的缺陷（相对图片路径、懒加载 `data-src`、
只有 `dc:date` 的源、只有 `<updated>` 的 Atom 源……），改动解析或渲染逻辑后
应该重跑一遍。详见 [tool/e2e_fixture/README.md](tool/e2e_fixture/README.md)。

## 项目结构

```
lib/
├── main.dart                 # 入口：创建服务 + MultiProvider 注入
├── models/                   # Article / Feed / AppConfig
├── services/                 # rss / storage / cache / theme / backup
├── utils/                    # 纯函数（有单测覆盖）
│   ├── feed_url.dart         # URL 规范化
│   ├── opml.dart             # OPML 解析与生成
│   ├── date_format.dart      # 日期格式化（统一处理时区）
│   └── html_content.dart     # 正文图片地址提取与补全
└── ui/
    ├── screens/              # home / article_list / article_detail / settings / features
    └── components/           # 订阅源面板 / 文章卡片 / HTML 渲染 / 图片画廊 等

tool/
└── e2e_fixture/              # 带 CORS 的本地 RSS/Atom 测试源（见其 README）
```

架构与数据流约定见 [AGENTS.md](AGENTS.md)。

## 技术栈

| 类别 | 技术 |
|---|---|
| 框架 | Flutter 3.47.4 |
| SDK | Dart 3.13.3 |
| RSS 解析 | `webfeed_plus`（RSS 2.0 / Atom 1.0） |
| HTTP | `dio` |
| HTML 解析 | `html`（正文抓取）+ `flutter_widget_from_html_core`（渲染） |
| 本地存储 | `shared_preferences` |

> `pubspec.yaml` 里的 `dependency_overrides`（`objective_c`）是**必需的**，
> 用于绕开上游依赖断裂。改动前请先读 [AGENTS.md](AGENTS.md)。

## 文档

| 文件 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 给 AI agent 的开发指南：环境、约定、陷阱 |
| [FEATURES.md](FEATURES.md) | 功能清单与实现状态 |
| [TODO.md](TODO.md) | 待办与路线图 |
| [docs/known-issues.md](docs/known-issues.md) | 已核实的问题与技术债 |
| [tool/build_macos_dmg.sh](tool/build_macos_dmg.sh) | 打 macOS 安装包（DMG） |

## 许可证

MIT，见 [LICENSE](LICENSE)。