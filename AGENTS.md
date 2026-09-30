# AGENTS.md

给在本仓库工作的 AI agent 的说明。**本文件取代了原先的 `CLAUDE.md`**（已于 2026-09-16 删除）。

## 项目是什么

`rss_reader` —— Flutter 编写的跨平台 RSS/Atom 阅读器。数据全部本地存储（SharedPreferences），无后端、无账号、无同步。

## 当前状态（2026-09-29）

项目停更了 7 个月后被重新拉起，已完成五轮工作：

1. 从零装好 Flutter 3.47.4（原来机器上没装），核实并修掉 16 个缺陷，建立测试地基
2. 文档校对：删除 `CLAUDE.md`，改写为 `AGENTS.md`；修正了旧文档大量声称但未实现的功能
3. 渲染引擎从停更的 `flutter_html` 迁到 `flutter_widget_from_html_core`
4. 拆解上帝组件 + `StorageService` 改为 `ChangeNotifier`（详见 `TODO.md` 的里程碑）
5. macOS 桌面端打通：补齐 Xcode 27 + CocoaPods，`flutter build macos` 通过，
   并实测抓到了真实 RSS 源（这正是 Web 端做不到的事）

当前：`flutter analyze` **0 issues**，`flutter test` 93 个单测/组件测试通过，
macOS 端可构建可运行、能抓真实订阅源，且**完整链路 e2e 已自动化**
（`./tool/run_macos_e2e.sh`：6 个集成测试 + fixture 请求日志校验）；
Web 端 e2e 已验证。

**平台优先级（已定）**：**macOS → Android → iOS**。
Web 保留为 UI 演示。iOS 是**有意排后面**，不是放弃 —— 详见下方平台现状。

**下一步优先级**（完整清单在 [`TODO.md`](TODO.md)）：

1. **把 macOS 打磨到真正可用** —— 构建与链路都通了，接下来是桌面体验：
   应用图标、窗口默认位置（现在开在屏幕左下角）、红绿灯适配、正文图片居中、
   窗口 `minSize`、系统菜单栏、需翻墙源的代理设置，
   以及把原生对话框那几项人工点一遍（见「测试」）
2. 补 Android SDK（缺 cmdline-tools + license），打通第二个平台
3. 存储层改造 —— 现在每次落盘都重新序列化全部文章，Web 的 localStorage 有 ~5MB 上限
4. 清 `analysis_options.yaml` 的 `deprecated_member_use: ignore`（`surfaceVariant` ×4、
   `MaterialStateTextStyle` ×2），并统一宽屏适配走 `ResponsiveLayout`

已核实但未修的问题都在 [`docs/known-issues.md`](docs/known-issues.md)，每条附证据。
**动手前先看它**，避免重复踩已踩过的坑。

## 平台现状（重要，别被 "跨平台" 误导）

代码有 Android / iOS / macOS / Windows / Linux / Web 六个目录，
**当前开发机上只有 macOS 和 Web 能跑**：

| 目标 | 优先级 | 状态 | 阻塞原因 |
|---|---|---|---|
| **macOS** | 1️⃣ | ✅ 可编译可运行，**能抓真实 RSS**，链路 e2e 已自动化 | 无功能阻塞（未签名/未公证不影响自用） |
| **Android** | 2️⃣ | ❌ | SDK 装了一部分（`flutter doctor`：Android SDK version 36.0.0），但缺 cmdline-tools、license 未接受 |
| **iOS** | 3️⃣ | ⏸ 有意搁置 | ① `xcode-select` 未切到 Xcode ② 无 Development Team。见下方专节 |
| Web | — | ✅ 可编译可运行 | **抓不到订阅源** —— 见陷阱 1。保留作 UI 演示 |
| Windows / Linux | — | — | 需在对应系统上构建 |

想正经用这个 App，**跑 macOS 端**：`flutter run -d macos`。

### iOS 为什么还不能编（已定位，暂不修）

2026-09-29 实测，两层阻塞都已确认到根因：

1. **`xcode-select -p` 仍指向 `/Library/Developer/CommandLineTools`**，而 CLT
   有 macOS SDK、没有 iPhoneOS SDK。修法是 `sudo xcode-select --switch`，见陷阱 6。
   （macOS 端不受影响，所以这个问题会伪装成「iOS 独有」）
2. iOS 真机部署还**需要一个 Development Team**（Apple ID），得在 Xcode 的
   Signing & Capabilities 里选，非命令行可代劳。

已经修掉的部分：`ios/Podfile` 补了 `use_modular_headers!`，否则
`file_picker → DKPhotoGallery → SDWebImage` 会让 `pod install` 直接失败。
`pod install` 之后 Xcode 本身编得过去（实测 16.6s）。

注意 **Xcode 27 / Flutter 3.47 已为 `ios/` 与 `macos/` 工程自动迁移**
（UIScene、SPM 集成、macOS deployment target 10.15 → 12.0），
改动是构建时自动写进仓库的，不是手写的。

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

### Xcode / CocoaPods（macOS 端已装好，2026-09-29）

| 组件 | 版本 | 位置 |
|---|---|---|
| Xcode | 27.0（27A266a） | `/Applications/Xcode.app` |
| CocoaPods | 1.17.0 | `/opt/homebrew/bin/pod`（brew 装的） |

装 CocoaPods 有个坑：**USTC 镜像没有 macOS 27 的 bottle**（报 `no bottle available`）。
得临时换回官方源并挂代理：

```bash
http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 \
HOMEBREW_BOTTLE_DOMAIN=https://ghcr.io/v2/homebrew/core \
HOMEBREW_API_DOMAIN=https://formulae.brew.sh/api \
brew install cocoapods
```

**`xcode-select` 目前仍指向 CommandLineTools** —— macOS 构建无视它，iOS 构建会死，
详见陷阱 6。

### 包名与数据位置

bundle id / applicationId 全部是 **`org.ross.rssReader`**（2026-09-29 从模板默认的
`com.example.*` 改过来）。macOS 是沙盒应用，**数据按 bundle id 分目录**：

```
~/Library/Containers/org.ross.rssReader/Data/Library/Preferences/org.ross.rssReader.plist
```

里面是 SharedPreferences 的三个 key：`flutter.feeds` / `flutter.articles` /
`flutter.config`（值是 plist array，每个元素是一段 JSON 字符串）。
调试时想直接看数据：

```bash
python3 -c "import plistlib,json,sys; d=plistlib.load(open(sys.argv[1],'rb')); \
print([json.loads(x)['title'] for x in d['flutter.feeds']])" \
~/Library/Containers/org.ross.rssReader/Data/Library/Preferences/org.ross.rssReader.plist
```

> 别用 `plutil -extract flutter.feeds`，它会把 key 里的 `.` 当路径分隔符。

**再改包名会丢数据** —— 新容器是空的，要手动迁移（旧容器在
`~/Library/Containers/<旧 bundle id>/`，拷过去并把 plist 重命名，然后
`killall cfprefsd` 清缓存）。

## 常用命令

```bash
flutter pub get                 # 拉依赖
flutter analyze                 # 静态分析（必须 0 error）
flutter test                    # 单元测试
./tool/run_macos_e2e.sh         # macOS 完整链路 e2e（集成测试 + fixture 日志校验）
flutter run -d macos            # 开发模式跑 macOS（首选目标）
flutter build macos --release   # 构建 macOS
./tool/build_macos_dmg.sh       # 打成 DMG 安装包 → build/dist/
flutter build web --release     # 构建 Web
flutter run -d chrome           # 开发模式跑 Web
```

macOS 端目前**需要能看到 Xcode**（`xcode-select` 还指着 CLT）：不设 `DEVELOPER_DIR`
时 `flutter build macos` / `flutter test -d macos` 会直接报 “Xcode not installed”。
`./tool/run_macos_e2e.sh` 与 `./tool/build_macos_dmg.sh` 会自动带上，手动跑时先看陷阱 6。

### macOS 安装包

```bash
./tool/build_macos_dmg.sh
# → build/dist/RSS-Reader-1.0.0-universal.dmg（22MB，含 x86_64 + arm64）
```

拖进 Applications 即安装。**未做公证** —— 本机没有 Developer ID 证书，
工程里是 `CODE_SIGN_IDENTITY = "-"`（ad-hoc）。所以 `spctl -a -t exec` 会返回
`rejected`：只影响**下载来的**包（带 quarantine 位才被 Gatekeeper 拦），
自己构建自己装的没事 —— 实测从只读 DMG 卷直接启动也能跑。

#### 签名：三条路的区别（别选错）

| 做法 | 下载者能不能直接双击打开 | 成本 |
|---|---|---|
| **ad-hoc**（`CODE_SIGN_IDENTITY = "-"`，现在就是这个） | ❌ 仍被拦 | 0 |
| **自签名证书**（自己生成、导入钥匙串） | ❌ **仍被拦** | 0 |
| **Developer ID + 公证**（Apple 签发） | ✅ | 99 USD/年 |

**自签名证书解决不了分发问题** —— 证书不在别人的信任库里，下载者那边一样被拦，
只是提示语不同。它只对「导入了并信任了该证书的那台机器」有效。
所以本仓库和 [openOTP](https://github.com/yuefeiduzi/openOTP) 都选了
**ad-hoc + 文档 + 校验和**，而不是去买证书。放行说明在 `docs/UNSIGNED.md`，
同一个文件会被放进 DMG、也会作为每个 Release 正文的开头。

## 发布

推一个 `v*` tag 即自动出包。详见 [`.github/workflows/release.yml`](.github/workflows/release.yml)。

```bash
# 1. 改 pubspec.yaml 的 version（唯一一处版本号），跑一遍门槛
flutter analyze --no-fatal-infos && flutter test
# 2. 提交后打 tag 并推送（推送由你操作）
git commit -am "chore(release): v1.0.0"
git tag v1.0.0 && git push origin main v1.0.0
# 3. Actions → Release 跑完，到 Releases 检查**草稿**，确认后再 Publish
```

| Job | 做什么 |
|---|---|
| `tests` | 直接调用 `ci.yml`，保证 tag 指向的提交与 main 一样绿 |
| `version` | tag 去 `v` 后必须等于 `pubspec.yaml` 的版本，否则直接失败、不构建、不发布 |
| `dmg` | 调 `./tool/build_macos_dmg.sh`（与本地同一个脚本），存 artifact，建草稿 Release |

Release 正文 = `docs/UNSIGNED.md`（放行 + 校验）+ 由 `git log` 生成的提交列表。
只建**草稿**，对外不可见，你确认后手动 Publish。

> 仓库还没有 `CHANGELOG.md`，所以发布说明是提交列表。哪天补了，
> 改成切 CHANGELOG 的版本段落就行（openOTP 是那个做法）。

**演练**：Actions → Release → Run workflow（`workflow_dispatch`）只跑检查与构建，
把 DMG 存成 workflow artifact，**不创建任何 Release**。首次打 tag 前先用它验一遍。

### 端到端验证

**macOS 端**分两层：

1. **自动化（首选，可重复）**：`./tool/run_macos_e2e.sh` —— 起 fixture、跑
   `integration_test/macos_e2e_test.dart` 的 6 个用例，再用 fixture 请求日志做
   「不该抓的没抓」校验。详见「测试」一节。
2. **手工补充**：直接添加真实源（没有 CORS 问题，见陷阱 1）看真实站点渲染。
   自动化碰不到的是原生对话框那几项：图片保存、分享、浏览器打开原文。

**Web 端**才需要本地 fixture：它受 CORS 限制抓不到真实 RSS 源。

```bash
flutter build web --release
python3 -m http.server 8099 --directory build/web   # 应用
python3 tool/e2e_fixture/serve.py 8100               # 带 CORS 的测试源
# 在应用里添加 http://127.0.0.1:8100/feed.xml  或  /atom.xml
```

fixture 的每个文件都对应一个已修过的缺陷，改动解析/渲染/图片逻辑后应重跑。
详细说明见 `tool/e2e_fixture/README.md`。

## 架构

没有 ViewModel —— 是 **service + ChangeNotifier + StatefulWidget**。

服务在 `main.dart` 里创建一次，通过 `MultiProvider` 注入；页面用
`context.watch` / `context.read` 自取，不再逐层透传。

```
lib/
├── main.dart                 # 入口：创建服务 + MultiProvider
├── models/                   # Article / Feed / AppConfig，纯数据类 + JSON
├── services/
│   ├── storage_service.dart  # 唯一真相来源：ChangeNotifier + 同步读 + 异步写
│   ├── rss_service.dart      # 抓取 + RSS/Atom 解析（parseFeed/parseArticles 是纯函数）
│   ├── cache_service.dart    # 全文内容缓存（7 天过期）
│   ├── theme_service.dart    # ChangeNotifier，主题 + 两份 ThemeData
│   └── backup_service.dart   # JSON / OPML 备份恢复
├── utils/                    # 纯函数，无 Flutter 依赖，有单测覆盖
│   ├── feed_url.dart         # normalizeFeedUrl
│   ├── opml.dart             # OPML 解析/生成 + XML 实体转义
│   ├── date_format.dart      # formatDate / formatDateTime / formatRelativeDate
│   ├── download_names.dart   # 批量下载图片的文件名推导与去重
│   └── html_content.dart     # extractImageUrls / absolutizeImageUrls
└── ui/
    ├── screens/              # home / article_list / article_detail / settings / features
    └── components/
        ├── feed_list_panel.dart    # 订阅源列表面板（增删改闭环，含唯一一份删除确认）
        ├── feed_list_tile.dart     # 单个订阅源项（手势 / 动画）
        ├── feed_context_menu.dart  # 订阅源右键、长按菜单
        ├── article_card.dart       # 文章卡片
        ├── html_content_view.dart  # 正文 HTML 渲染 + 失败降级视图
        ├── image_gallery.dart      # 全屏图片画廊
        └── add_feed_dialog.dart / edit_feed_dialog.dart / responsive_layout.dart

tool/
└── e2e_fixture/              # 带 CORS 的本地 RSS/Atom 测试源（见其 README）
```

### 数据流约定

`StorageService` 是唯一真相来源，接口约定是：

- **读是同步的**：`feeds` / `articlesOf(id)` / `unreadCountOf(id)` 直接读内存，
  不要 `await`。未读数在内部增量维护，**不要**自己遍历文章去数 —— 那是
  O(源数 × 文章数)。
- **写会立即返回**：状态先在内存生效并通知监听者，落盘在后台按提交顺序排队。
  所以**不要**在写完之后手工刷新界面，没有 `_loadFeeds()` 这种东西了。
- 需要确保落盘完成时（测试、退出前）调 `flush()`。

写新页面时：`context.watch<StorageService>()` 取数据，数据一变界面自动重建。

### 关于 Scaffold

`ArticleListScreen` 与 `ArticleDetailScreen` **不自带 Scaffold / AppBar**，
它们各自提供一条普通横栏（描述 + 操作按钮）；标题栏由 `HomeScreen` 统一提供，
否则窄屏会出现上下两条标题栏。独立推入的 `SettingsScreen` 自带 Scaffold 没问题。

**把纯逻辑放进 `lib/utils/` 并写单测**，不要把可测逻辑埋在 widget 的私有方法里。这是刻意建立的约定。

## 代码约定

- 能用 `const` 就用（`prefer_const_constructors` / `prefer_const_declarations` 已开）
- 禁止 `print()`，用 `debugPrint`
- Material 3
- 模型：简单数据类 + `fromJson` / `toJson` / `copyWith`
- 服务：单例式长生命周期对象，由 `main.dart` 创建后向下传递
- 宽屏适配用 `ResponsiveLayout`

## 陷阱（会真的绊住你）

### 1. Web 端天然抓不到 RSS（CORS）—— 仅限 Web

`RssService` 设了自定义 `User-Agent`，使请求成为非简单请求，触发 CORS 预检；而真实 RSS 服务器不会响应预检，浏览器直接拦截。**这是架构问题，不是 bug，改代码解决不了**，需要 CORS 代理层。

实测：本地起一个带 `Access-Control-Allow-Origin: *` 的 fixture 服务器可以走通全流程，真实站点不行。

**这条只影响 Web。** macOS / Android / iOS 上 dio 不受同源策略约束，macOS 沙盒
的 `com.apple.security.network.client` 也已在 entitlements 里放行
（`codesign -d --entitlements -` 实测为 `true`）。2026-09-29 实抓真实源：

| 源 | 格式 | 结果 |
|---|---|---|
| `https://sspai.com/feed` | RSS | 10 篇，标题/日期/链接均正确 |
| `https://www.ruanyifeng.com/blog/atom.xml` | Atom | 3 篇 |
| `https://coolshell.cn/feed` | RSS | 15 篇 |

所以 macOS 端**不需要** `tool/e2e_fixture/` 这套 CORS 代理。

### 2. `pubspec.yaml` 里的 `dependency_overrides` 是必需的

只有一条，为了绕开上游断裂，**不要顺手删掉**：

```yaml
dependency_overrides:
  # objective_c 9.6.1（2026-09-15 发布）仍引用 code_assets 2.0.0 已删除的
  # Architecture.arm64e，属上游断裂
  objective_c: 9.6.0
```

（历史上还有一条 `html: 0.15.4`，是为了迁就已停更的 `flutter_html` ——
它违规 import 了 `html` 包的私有文件。渲染引擎迁到 `flutter_widget_from_html_core`
后冲突消失，该条已移除。）

若日后又出现 `dependency_overrides`，请在 pubspec 里写清楚是为了什么，
否则下一个人不敢删。

### 3. `dart:io` 在 Web 上能编译但运行时抛异常

`backup_service.dart` 用了 `dart:io` + `path_provider`。Web 构建**不会**因此失败，但调用备份功能会抛 `UnsupportedError`。别指望 Web 端能备份到文件。

### 4. Flutter 大版本迁移改过 API

- `CupertinoPageTransitionsBuilder` 已从 `material.dart` 移到 `cupertino.dart`（PR #179776），需要显式 `import 'package:flutter/cupertino.dart' show ...`
- `WillPopScope` → `PopScope`
- `MaterialStateTextStyle` → `WidgetStateTextStyle`
- `ColorScheme.background/surfaceVariant` 已弃用

`analysis_options.yaml` 里 `deprecated_member_use: ignore` 掩盖了一批存量（`surfaceVariant` ×4、
`MaterialStateTextStyle` ×2），改到相关文件时顺手清。目前 `flutter analyze` 是 0 issues，
那 6 条被 ignore 掩盖的弃用并不报出来。

### 5. `StorageService` 把全部数据存在 SharedPreferences

每次写入都会重新序列化**所有**文章。文章量上来会明显卡顿，且 Web 的 localStorage
有 ~5MB 上限。这是已知的设计债（见 `docs/known-issues.md`）。

注意接口上的对应约定：写操作**不阻塞**、后台排队落盘，所以写入频率不再是
交互性能瓶颈，但存储量本身的问题依旧存在。

| 功能 | 说明 |
|---|---|
| `RssService` 纯函数解析 | `parseFeed` / `parseArticles` 不触网，有单测 |
| `StorageService` | id 用完整 URL（不是 `hashCode`）—— 它会被持久化，哈希实现变了历史数据就对不上 |
| 网络层 | 只放行 2xx。写 `status < 500` 会让 404 错误页被当成正文渲染并缓存 |

### 6. `xcode-select` 指向 CommandLineTools —— macOS 没事，iOS 必挂

**装了 `Xcode.app` 不等于可用。** 只要 `xcode-select -p` 还打印
`/Library/Developer/CommandLineTools`，就会这样：

```bash
xcrun --show-sdk-path --sdk iphoneos   # → error: SDK "iphoneos" cannot be located
xcrun --show-sdk-path --sdk macosx     # → OK（CLT 自带 macOS SDK）
```

于是 **iOS 必挂**，macOS 也编不了 —— flutter_tools 会直接报 “Xcode not installed”
（`tool/build_macos_dmg.sh` 里显式给了 `DEVELOPER_DIR`，所以之前没暴露）。
iOS 的报错则完全指不到病根：
`objective_c` 的 native-assets 构建钩子只会抛 `Bad state: No element`
（`objective_c-9.6.0/hook/build.dart:189` → `xcrun` 返回空 stdout）。

修法（**必须 sudo**）：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**`DEVELOPER_DIR` 能救 macOS，救不了 iOS**（2026-09-30 实测）：

- **macOS**：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter build macos`
  可行 —— flutter_tools 的 `xcodebuild -version` 检查与后续 xcodebuild 都吃这个变量。
  `tool/build_macos_dmg.sh` / `tool/run_macos_e2e.sh` 就是这么绕的。不设它的话，
  连 macOS 都是直接失败，所以那两处 export 是**必需**的，不是备份。
- **iOS**：Xcode 的脚本阶段虽然导出了它，但 flutter_tools 起 native-assets hook
  子进程时不会透传，hook 里的 `xcrun` 照样用全局 developer dir，依旧
  `Bad state: No element`。（已实测：手动给 hook 进程加 `DEVELOPER_DIR` 后它立刻编出
  `-isysroot .../iPhoneOS27.0.sdk -target arm64-apple-ios`，所以这是唯一变量。）

`flutter doctor` 里那句「Xcode installation is incomplete」说的就是这件事。

### 7. 这台机器的网络：包走镜像，GitHub 走代理，且关掉 HTTP/2

- pub / storage / brew 都配了国内镜像（见「环境」），**别给它们套代理**
- 但 `raw.githubusercontent.com` / `github.com` 直连超时 —— brew 取 formula、
  CocoaPods 克隆 pod 全卡在这里，必须挂代理
- 代理跑 HTTP/2 不稳：`git clone` 会报 `LibreSSL SSL_connect: SSL_ERROR_SYSCALL`，
  加 `-c http.version=HTTP/1.1` 就正常

```bash
export http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897
export no_proxy=127.0.0.1,localhost
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.version GIT_CONFIG_VALUE_0=HTTP/1.1
```

**另注**：`dio` 走 dart:io 默认直连，**不读系统代理**。所以 App 本身抓不到需要
翻墙的源（实测 `feeds.bbci.co.uk` 超时，`sspai.com` 正常）。这不是 bug，是已知限制。

### 8. `pubspec.lock` 里记着包源 URL，换个 host 就会被静默改写

`pubspec.lock` 的 99 条记录**全部**写着 `url: "https://pub.flutter-io.cn"` ——
那是本机 `PUB_HOSTED_URL` 的产物，已经提交进仓库了。

后果：**任何没设 `PUB_HOSTED_URL` 的环境（比如 CI、别人新拉的仓库）跑
`flutter pub get`，pub 会认为 lock 与当前 host 不符，静默重新解析并改写 lock**。
不是报错，是无声地把 99 条翻成 `pub.dev`：

```bash
env -u PUB_HOSTED_URL flutter pub get   # 实测："Changed 98 dependencies!"，lock 被改写
```

所以 `.github/workflows/ci.yml` 里也设了这个变量。**若那个镜像在 GitHub runner
上太慢或不通，删掉那一行即可**（退回 pub.dev 重新解析，构建照常成功，
代价只是 CI 不再严格按 lock 构建）。

> 顺带的副作用：谁在没设镜像的机器上跑过 `pub get` 并提交了，谁就会给全仓库
> 制造一个 99 行的 lock diff。看到这种 diff 先想想是不是这个原因。

## 测试

```bash
flutter test                                    # 全部
flutter test test/opml_test.dart                # 单个文件
```

`lib/utils/` 下的模块必须有单测。`test/widget_test.dart` 现在覆盖了「写入后界面
自动更新」这个核心行为，不再只是断言标题。

**单测盖不住的部分要走 e2e**：解析、图片地址、时间显示都有单测，但「真的渲染出来了」
只能靠跑一遍看。历史上多个缺陷（相对图片 404、404 错误页被当成正文）都是 e2e 才看到的。

- **macOS 端**：走 `integration_test/`（自动化，见下）或直接添加真实订阅源
- **Web 端**：走 `tool/e2e_fixture/`（每个 fixture 文件都对应一个已修过的缺陷）

### macOS 集成测试（integration_test/）

`integration_test/macos_e2e_test.dart` 跑的是**真 app、真网络、真文件系统**，
按顺序覆盖 TODO 里的每一项：加 RSS 源 → 列表 → 详情全文抓取 → 收藏/已读/未读数 →
加 Atom 源（只有 `<updated>` 的回归点）→ 菜单删除 → 备份/恢复 + OPML 导出导入 →
图片地址与画廊。跑法：

```bash
./tool/run_macos_e2e.sh     # 起 fixture → 跑测试 → 校验请求日志
```

测试是 **hermetic** 的：`SharedPreferences.setMockInitialValues({})` 换成内存实现，
不碰 `~/Library/Containers/org.ross.rssReader/...plist`（脚本会校验文件哈希没变）。

**光跑 `flutter test` 不够**：单测断言不到的部分由 fixture 服务器日志兜底 ——
`placeholder.png` 一次都不能被请求（`data-src` 回写回归点）、`article2.html`
一次都不能被请求（摘要够长不该抓全文）。这些只有日志能证明，`run_macos_e2e.sh`
已经把这两条固化成脚本里的检查。

**自动化覆盖不到的**（原生对话框，测试一碰就卡）：图片保存到磁盘、系统分享、
浏览器打开原文，以及设置页里点 Backup/Import 选文件。备份/OPML 的读写逻辑
已在集成测试里用服务层直接调用覆盖，缺的只是 file_picker 那一下。

### CI 里跑什么

`.github/workflows/ci.yml` 三个 job，每个 PR / push 到 main 都跑：

| Job | 环境 | 内容 |
|---|---|---|
| `analysis` | ubuntu | `flutter analyze --no-fatal-infos` + `flutter test` |
| `build-web` | ubuntu | `flutter build web --release`（只验构建，不验功能） |
| `build-macos` | macos | `flutter build macos --debug` |

**`--no-fatal-infos` 保留着，但仓库现在已经是 0 issues**（2026-09-30 清完存量）。
这个 flag 现在是防回退的护栏：`flutter analyze` 遇到 info 也会退出 1
（已实测），去掉它就得保证永远不引入任何 info。error 与 warning 依然会让 CI 变红，
这正是「analyze 必须 0 error」那条约定的机器化版本。

单测全部 hermetic（不发网络请求），所以 CI 不需要任何 fixture 服务。
集成测试要真 GUI + fixture 服务器，**暂不进 CI**，本地跑 `./tool/run_macos_e2e.sh`。

## 文档

| 文件 | 用途 |
|---|---|
| `README.md` | 面向使用者/贡献者 |
| `FEATURES.md` | 功能清单，标注真实实现状态 |
| `TODO.md` | 待办路线图 |
| `docs/known-issues.md` | 已核实的问题与技术债（含证据） |
| `docs/UNSIGNED.md` | macOS 首次打开的放行说明（进 DMG，也作为 Release 正文开头） |

写文档时**标注真实状态**。这个仓库的历史文档大量声称未实现的功能（预设订阅源、图片懒加载、`dc:date` 支持、缓存统计等都曾是不实的），别再犯。