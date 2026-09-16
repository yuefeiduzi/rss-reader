# AGENTS.md

给在本仓库工作的 AI agent 的说明。**本文件取代了原先的 `CLAUDE.md`**（已于 2026-09-16 删除）。

## 项目是什么

`rss_reader` —— Flutter 编写的跨平台 RSS/Atom 阅读器。数据全部本地存储（SharedPreferences），无后端、无账号、无同步。

## 平台现状（重要，别被 "跨平台" 误导）

代码有 Android / iOS / macOS / Windows / Linux / Web 六个目录，但**当前开发机只有 Web 能跑**：

| 目标 | 状态 | 阻塞原因 |
|---|---|---|
| **Web** | ✅ 可编译可运行 | **但抓不到订阅源** —— 见下方 CORS 陷阱 |
| macOS / iOS | ❌ | 未安装完整 Xcode（只有 CommandLineTools） |
| Android | ❌ | 未安装 Android SDK |
| Windows / Linux | — | 需在对应系统上构建 |

要正经开发桌面/移动端，先装 Xcode。`flutter doctor` 会告诉你缺什么。

## 环境

已装在 `~/development/flutter`（不是 brew，也不是 PATH 里的默认位置）。
`~/.zshrc` 已配置，新开终端生效：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"          # pub 包走中国镜像
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"  # 引擎产物走中国镜像
```

**这两个镜像变量必须设置。** 直连 `storage.googleapis.com` 只有 ~400KB/s，走镜像 12MB/s。

当前版本：**Flutter 3.47.4 / Dart 3.13.3**。项目是从 2026-01 的版本（约 Dart 3.6）跳过来的，跨了多个大版本。

## 常用命令

```bash
flutter pub get                 # 拉依赖
flutter analyze                 # 静态分析（必须 0 error）
flutter test                    # 单元测试
flutter build web --release     # 构建 Web
flutter run -d chrome           # 开发模式跑 Web
```

本地验证 Web 版：`flutter build web --release` 后把 `build/web/` 用任意静态服务器托管即可。

## 架构

MVVM-like，但没有 ViewModel —— 是 service + StatefulWidget。

```
lib/
├── main.dart                 # 入口：初始化 3 个 service 后注入 HomeScreen
├── models/                   # Article / Feed / AppConfig，纯数据类 + JSON
├── services/
│   ├── rss_service.dart      # 抓取 + RSS/Atom 解析（含 parseArticles 等纯函数，可单测）
│   ├── storage_service.dart  # SharedPreferences 持久化，持有 feeds/articles/config 规范状态
│   ├── cache_service.dart    # 全文内容缓存（7 天过期）
│   ├── theme_service.dart    # ChangeNotifier，主题 + 两份 ThemeData
│   ── backup_service.dart   # JSON / OPML 备份恢复
├── utils/                    # 纯函数，无 Flutter 依赖，有单测覆盖
│   ├── feed_url.dart         # normalizeFeedUrl
│   ├── opml.dart             # OPML 解析/生成 + XML 实体转义
│   ├── date_format.dart      # formatDate / formatDateTime / formatRelativeDate
│   ── html_content.dart     # extractImageUrls / absolutizeImageUrls
└── ui/
    ├── screens/              # home / article_list / article_detail / settings / features
    ── components/           # add_feed_dialog / edit_feed_dialog / feed_list_tile / responsive_layout
```

**把纯逻辑放进 `lib/utils/` 并写单测**，不要把可测逻辑埋在 widget 的私有方法里。这是刻意建立的约定。

## 代码约定

- 能用 `const` 就用（`prefer_const_constructors` / `prefer_const_declarations` 已开）
- 禁止 `print()`，用 `debugPrint`
- Material 3
- 模型：简单数据类 + `fromJson` / `toJson` / `copyWith`
- 服务：单例式长生命周期对象，由 `main.dart` 创建后向下传递
- 宽屏适配用 `ResponsiveLayout`

## 陷阱（会真的绊住你）

### 1. Web 端天然抓不到 RSS（CORS）

`RssService` 设了自定义 `User-Agent`，使请求成为非简单请求，触发 CORS 预检；而真实 RSS 服务器不会响应预检，浏览器直接拦截。**这是架构问题，不是 bug，改代码解决不了**，需要 CORS 代理层。

实测：本地起一个带 `Access-Control-Allow-Origin: *` 的 fixture 服务器可以走通全流程，真实站点不行。

### 2. `pubspec.yaml` 里的 `dependency_overrides` 是必需的

两条都是为了绕开上游断裂，**不要顺手删掉**：

```yaml
dependency_overrides:
  html: 0.15.4      # flutter_html 3.0.0 违规 import 了 html 包的私有文件
                    # package:html/src/query_selector.dart；html 0.15.5 起
                    # matches 由顶层函数改为类方法 → 编译失败
  objective_c: 9.6.0 # 9.6.1 引用了 code_assets 2.0.0 已删除的 Architecture.arm64e
```

`flutter_html` 已停更（3.0.0 是 2025-03 的版本），长期方案是迁移到 `flutter_widget_from_html`。

### 3. `dart:io` 在 Web 上能编译但运行时抛异常

`backup_service.dart` 用了 `dart:io` + `path_provider`。Web 构建**不会**因此失败，但调用备份功能会抛 `UnsupportedError`。别指望 Web 端能备份到文件。

### 4. Flutter 大版本迁移改过 API

- `CupertinoPageTransitionsBuilder` 已从 `material.dart` 移到 `cupertino.dart`（PR #179776），需要显式 `import 'package:flutter/cupertino.dart' show ...`
- `WillPopScope` → `PopScope`
- `MaterialStateTextStyle` → `WidgetStateTextStyle`
- `ColorScheme.background/surfaceVariant` 已弃用

`analysis_options.yaml` 里 `deprecated_member_use: ignore` 掩盖了一批存量，改到相关文件时顺手清。

### 5. `StorageService` 把全部数据存在 SharedPreferences

每次写入都会重新序列化**所有**文章。文章量上来会明显卡顿，且 Web 的 localStorage 有 ~5MB 上限。这是已知的设计债（见 `docs/known-issues.md`）。

## 测试

```bash
flutter test                                    # 全部
flutter test test/opml_test.dart                # 单个文件
```

`lib/utils/` 下的模块必须有单测。`test/widget_test.dart` 目前只断言标题，是占位性质。

## 文档

| 文件 | 用途 |
|---|---|
| `README.md` | 面向使用者/贡献者 |
| `FEATURES.md` | 功能清单，标注真实实现状态 |
| `TODO.md` | 待办路线图 |
| `docs/known-issues.md` | 已核实的问题与技术债（含证据） |

写文档时**标注真实状态**。这个仓库的历史文档大量声称未实现的功能（预设订阅源、图片懒加载、`dc:date` 支持、缓存统计等都曾是不实的），别再犯。