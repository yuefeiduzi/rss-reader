# rss_reader

Flutter 编写的跨平台 RSS/Atom 阅读器。数据全部保存在本地（SharedPreferences），无后端、无账号、无云同步。

## 平台支持现状

代码包含 Android / iOS / macOS / Windows / Linux / Web 六个平台的工程目录，但**当前只有 Web 是真正可运行的**：

| 平台 | 状态 | 说明 |
|---|---|---|
| Web | ⚠️ 可运行，但功能受限 | **无法抓取真实订阅源**，见下方「已知限制」 |
| macOS / iOS | ❌ 未验证 | 需要完整安装 Xcode |
| Android | ❌ 未验证 | 需要 Android SDK |
| Windows / Linux | ❌ 未验证 | 需在对应系统上构建 |

> 如果你要真正把这个 App 用起来，优先补 Xcode 跑 macOS 桌面端：Web 端受浏览器同源策略限制，抓不到 RSS。

## 已知限制

### Web 端抓不到订阅源（架构限制）

`RssService` 会设置自定义 `User-Agent`，使请求成为「非简单请求」，浏览器因此发起 CORS 预检；而真实世界的 RSS 服务器不会响应预检，请求被浏览器直接拦截。

这不是可以靠改代码绕过的 bug，需要引入 CORS 代理层。本地起一个带 `Access-Control-Allow-Origin` 的测试服务器可以走通全流程，说明解析链路本身是好的。

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
flutter run -d chrome          # 开发模式
```

### 构建

```bash
flutter build web --release    # 产物在 build/web/
flutter build macos --release  # 需要 Xcode
flutter build apk --release    # 需要 Android SDK
```

### 验证

```bash
flutter analyze                # 应为 0 error
flutter test                   # 单元测试
```

本地跑 Web 版验证：

```bash
flutter build web --release
cd build/web && python3 -m http.server 8099
# 打开 http://127.0.0.1:8099/
```

## 项目结构

```
lib/
├── main.dart                 # 入口：初始化服务并注入 HomeScreen
├── models/                   # Article / Feed / AppConfig
├── services/                 # rss / storage / cache / theme / backup
├── utils/                    # 纯函数（有单测覆盖）
│   ├── feed_url.dart         # URL 规范化
│   ├── opml.dart             # OPML 解析与生成
│   ├── date_format.dart      # 日期格式化（统一处理时区）
│   └── html_content.dart     # 正文图片地址提取与补全
└── ui/
    ├── screens/              # home / article_list / article_detail / settings / features
    └── components/           # 对话框与列表项组件
```

## 技术栈

| 类别 | 技术 |
|---|---|
| 框架 | Flutter 3.47.4 |
| SDK | Dart 3.13.3 |
| RSS 解析 | `webfeed_plus`（RSS 2.0 / Atom 1.0） |
| HTTP | `dio` |
| HTML 解析 | `html`（正文抓取）+ `flutter_html`（渲染） |
| 本地存储 | `shared_preferences` |

> `pubspec.yaml` 里的 `dependency_overrides` 是**必需的**，用于绕开两处上游依赖断裂。改动前请先读 [AGENTS.md](AGENTS.md)。

## 文档

| 文件 | 内容 |
|---|---|
| [AGENTS.md](AGENTS.md) | 给 AI agent 的开发指南：环境、约定、陷阱 |
| [FEATURES.md](FEATURES.md) | 功能清单与实现状态 |
| [TODO.md](TODO.md) | 待办与路线图 |
| [docs/known-issues.md](docs/known-issues.md) | 已核实的问题与技术债 |

## 许可证

MIT，见 [LICENSE](LICENSE)。