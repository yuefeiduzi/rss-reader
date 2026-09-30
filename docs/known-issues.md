# 已核实的问题与技术债

本文件记录**经过源码核实或实测验证**的问题，每条都附证据。避免记录「听说有问题」这类未验证内容。

最后核对：2026-09-29

---

## 一、已修复（保留记录以便回溯）

| 问题 | 根因 | 证据 |
|---|---|---|
| `CupertinoPageTransitionsBuilder` 编译失败 | Flutter 3.47 起不再由 `material.dart` 导出（PR #179776） | `flutter analyze` |
| Atom 源只有 `<updated>` 时解析崩溃 | `AtomItem.updated` 是 `DateTime?`、`published` 是 `String?`；代码把 DateTime 传进期望 String 的形参 | `test/rss_service_test.dart` |
| `dc:date` 未生效 | RSS 路径写的是 `item.pubDate ?? DateTime.now()`，而 webfeed 不会把 `dc:date` 填进 `pubDate` | 实测：`dc:date`-only 条目 `pubDate` 为 `null` |
| 正文相对图片 404 | 未按文章链接补全，渲染引擎相对应用自身域名解析 | 修复前 `GET /img.png` 打在应用端口 → 404；修复后打在文章域名 → 200 |
| 时间显示差 8 小时 | 两处 `_formatDateTime` 都漏了 `toLocal()` | 修复前 `2026-09-16 00:00`，修复后 `08:00`（源为 `+0800`） |
| OPML 导入基本无法工作 | 导入正则要求 `xmlUrl` 紧跟 `text`，而导出与标准 OPML 都把 `xmlUrl` 放在最后 | `test/opml_test.dart` |
| 导入订阅源数量虚报 | 忽略 `addFeedWithDuplicateCheck` 的返回值，无条件自增 | — |
| `getAllArticles(limit)` 的 limit 失效 | 级联 `..take(limit)` 返回的是接收者，`take` 结果被丢弃 | — |
| 「跟随系统」主题重启后失效 | `init()` 用 `isDarkMode` 算 light/dark，无视 `followSystemTheme` | — |
| 裸域名输入被拒 | 先判 `Uri.isAbsolute`，`example.com/feed` 直接报错，后面的 https 补全是死代码 | `test/feed_url_test.dart` |
| 相对/懒加载头图失败 | 只取 `src`，不解析相对路径、不认 `data-src` | — |
| `getAllFeeds` 泄漏内部列表 | 返回内部可变列表，`home_screen` 在其上原地排序 | — |
| 批量导入 feed id 可能重复 | 用 `millisecondsSinceEpoch` 生成 id | — |
| `async void` 吞异常 | `_deleteFeed` / `_togglePinFeed` 声明为 `void ... async` | — |
| 备份文件列表永远为空 | 扫描 `<docs>/backup/*.json`，实际写入 `<docs>/backup_<时间戳>.zip` | — |
| **feed id 冲突** | `_generateId` 只取 `host + path`，忽略 query 与端口，两个不同的源会算出同一个 id | 实测：`feed.xml` 与 `feed.xml?v=2` 的 id 都是 `109737834` |
| **404 错误页被当成正文** | `validateStatus: (s) => s < 500` 让 404 也算成功，于是错误页被渲染并写进全文缓存 | e2e 实测详情页显示 `Error response / Error code: 404` |
| 删除确认弹两次 | `FeedListTile` 与 `FeedListPanel` 各有一份删除确认 | e2e 实测 |
| 窄屏双层标题栏 | 子页面自带 Scaffold + AppBar，与外层叠加 | e2e 实测（窄屏） |
| 过度刷新 | `_loadArticles` 在打开文章返回、切换收藏时都会触发整源网络刷新 | 日志实测：打开文章会出现完整的刷新 + 保存序列 |
| 添加订阅源重复请求 | 对话框拉一次、调用方再拉一次 | — |

---

## 二、未修复 —— 需要决策

### 2.1 依赖风险

**`flutter_html` 已迁移完成**（原为最高优先级技术债）。

原问题：`flutter_html` 最新版 3.0.0 发布于 2025-03 后停更，且违规 import 了 `html`
包的私有文件 `package:html/src/query_selector.dart`（包内自带 TODO 承认该风险）。
`html` 0.15.5 起 `matches` 由顶层函数改为类方法，直接导致编译失败，当时靠在
pubspec 里锁定 `html: 0.15.4` 绕过。

现况：渲染引擎已换成 `flutter_widget_from_html_core` 0.17.4（活跃维护，且只依赖
csslib / html / logging），`html` 的版本锁定随之移除。实测渲染保真度反而更好
（列表、代码块、标题层级均正确）。渲染逻辑抽出到
`lib/ui/components/html_content_view.dart`，CSS 映射与颜色转换有单测覆盖。

附带收益：正文图片点击 → 全屏画廊终于接线（此前是死代码）。

### 2.2 结构问题

| 问题 | 位置 | 说明 |
|---|---|---|
| 上帝组件 | `article_detail_screen.dart`（约 970 行） | 混合了加载、全文抓取、收藏、分享、图片下载、Overlay toast。HTML 渲染已抽出到 `ui/components/html_content_view.dart` |
| 上帝组件 | `home_screen.dart`（约 750 行） | `_buildFeedList` 与 `_buildFeedListPanel` 几乎完全重复 |
| 上帝组件 | `feed_list_tile.dart`（约 630 行） | 滑动、长按、右键菜单、PopupMenu、头像、徽标、删除确认全在一个文件 |
| 无状态管理 | 全局 | `provider` 声明在 pubspec 但**零使用**；3 个 service 手工传三层，刷新靠 `_loadFeeds()` 和 `onArticleRead` 回调 |
| 主题定义重复 | `theme_service.dart` | light/dark 两份约 190 行的 ThemeData 字面量逐项重复 |
| 日期格式化重复 | 已抽出 | 已统一到 `utils/date_format.dart` |

### 2.3 正确性 / 体验

| 问题 | 位置 | 说明 |
|---|---|---|
| 批量下载图片弹多个保存框 | `article_detail_screen.dart` | 循环调用 `_downloadImage`，每张图各弹一次文件选择器 |
| 存储层的写入放大 | `storage_service.dart` | 每次落盘都会重新序列化**全部**文章；Web 的 localStorage 有 ~5MB 上限 |
| 未读标记无「全部已读」 | — | 只能逐篇打开，没有批量操作 |

> **已澄清的误报**：「第一张卡片不显示未读徽标」曾是悬而未决的现象。
> 实测确认那是**正确行为**——第一篇文章当时已被打开过（`isRead: true`），
> 徽标本就该消失。清空数据后新建订阅源，三篇文章的徽标均正常渲染。
> 当时未查 `isRead` 就记为异常，是不严谨的。

### 2.4 死代码

**已清理约 220 行**（`_showImagePreview`、`_showImageContextMenu`、
`_openImageGalleryFromContext`、`_downloadAllImages`）。

剩余无调用者：

- `cache_service.dart`：`cacheImage` / `getCachedImage`（图片 Base64 缓存）、`getCacheStats`
- `storage_service.dart`：`clearOldArticles`
- `backup_service.dart`：`getBackupFiles`、`importOpmlFromZip`
- `responsive_layout.dart`：`isWideScreen` 与断点枚举
- `article_detail_screen.dart`：`_hasError` 降级分支（只读不写，永不触发）
- `pubspec.yaml`：`cached_network_image`（正文用 `NetworkImage`，列表用 `Image.network`）

**已删除：五个纯持久化、无人读写的配置字段**（2026-09-29 核实并删除）

`AppConfig` 曾经有七个字段，其中这五个全项目没有任何地方读或写：

| 字段 | 曾经的默认值 |
|---|---|
| `refreshInterval` | 60 |
| `autoRefreshOnStart` | `true` |
| `maxCachedArticles` | 500 |
| `enableNotifications` | `false` |
| `lastSyncTime` | 永远 `null`（没有任何地方赋值） |

验证：`grep -rn "autoRefreshOnStart\|lastSyncTime\|refreshInterval\|maxCachedArticles\|enableNotifications" lib/ test/`
只命中 `lib/models/config.dart` 自己的声明与 JSON 序列化。设置页也没有对应 UI。

也就是说 **“启动时自动刷新”“定时刷新”“缓存上限”“通知”全是不存在的功能**，
尽管配置文件里写着 `autoRefreshOnStart: true`。`FEATURES.md` 没有声称过它们（这点还好）。

现仅保留真正在用的 `isDarkMode` + `followSystemTheme`（由 `theme_service.setThemeMode`
通过 `copyWith` 写入）。旧数据与旧备份里残留的这些 key 会被 `fromJson` 直接忽略，无需迁移。

**向后兼容已实测**：本机 macOS 的数据文件里恰好带着全部 5 个旧 key
（`{"isDarkMode":true,"followSystemTheme":false,"refreshInterval":60,
"maxCachedArticles":500,"autoRefreshOnStart":true,"enableNotifications":false,
"lastSyncTime":null}`），删字段后 app 直接加载无碍。
`test/config_test.dart` 另有一组专门的兼容性单测（旧数据、只有旧字段、
再序列化后旧 key 不回来）。

> 教训：这五个字段的 `fromJson`/`toJson`/`copyWith` 写得都挺像回事，
> 光看 `config.dart` 会以为功能是存在的。**要判断一个配置项有没有用，
> 得拿字段名去全仓库 grep，不能只看模型文件。**

### 2.4.1 尝试过但已回退

**用 `cached_network_image` 缓存正文图片** —— `cached_network_image` 本来就在
pubspec 里却从未被引用，因此尝试通过覆写 `WidgetFactory.imageProviderFromNetwork`
把它接入正文渲染。实测在 Web 上会出问题：打开图片画廊再关闭后，正文中同一张图
会渲染成黑块（移除覆写后黑块消失，已确认由它导致）。已回退为默认的 `NetworkImage`。
若后续要做图片缓存，建议改用 fwfh 的 `customWidgetBuilder` 自行接管 `img` 元素，
而不是替换全局 ImageProvider。

### 2.5 平台

| 问题 | 说明 |
|---|---|
| Web 无法抓取 RSS | CORS 预检架构限制，需要代理层。**不是可以改代码绕过的 bug**。**仅限 Web**，macOS 实测不受影响 |
| Web 备份不可用 | `dart:io` + `path_provider` 在 Web 抛 `UnsupportedError` |
| Android 未验证 | 缺少 Android SDK |
| iOS 未验证 | **有意排在 macOS / Android 之后**。阻塞与已修部分见 2.5.1 |
| macOS 完整链路未验证 | 构建与真实 RSS 抓取已通过，但交互链路一次都没跑过（见 2.5.4） |
| macOS 抓不到需翻墙的源 | `dio` 用 dart:io 默认直连，不读系统代理 |

### 2.5.1 iOS 构建阻塞（已定位到根因，按优先级暂不修）

平台优先级是 macOS → Android → iOS，iOS 排最后。但根因已查清，
记在这里免得下次从头查一遍。

**① `xcode-select` 未切到 Xcode —— 真阻塞。**

```
$ xcode-select -p
/Library/Developer/CommandLineTools

$ xcrun --show-sdk-path --sdk iphoneos
xcrun: error: SDK "iphoneos" cannot be located

$ xcrun --show-sdk-path --sdk macosx
/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk     # ← CLT 有 macOS SDK
```

CLT 有 macOS SDK、没有 iPhoneOS SDK。这就是 **macOS 一路顺风、iOS 必挂**的原因。

在 iOS 构建里它伪装成一个跟 SDK 毫无字面关系的错误：

```
Target build_hooks failed: Error: Building native assets failed.
Unhandled exception:
Bad state: No element
#1  firstLineOfStdout (objective_c-9.6.0/hook/build.dart:198:8)
#2  sdkPath            (objective_c-9.6.0/hook/build.dart:189:10)
```

`hook/build.dart:189` 就是 `xcrun --show-sdk-path --sdk iphoneos`；它返回空 stdout，
于是 `.first` 抛 `Bad state: No element`。报错信息里没有任何“SDK”“Xcode”字样。

**已实测**：手动给那个 hook 进程加 `DEVELOPER_DIR` 后立刻成功：

```
clang -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/\
iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk -target arm64-apple-ios \
-mios-version-min=15 -c .../objective_c-9.6.0/src/objective_c.c
```

对比跑（同一个 `hook.dill` + `input.json`）：无 `DEVELOPER_DIR` → `Bad state: No element`；
有 → 编译成功。所以 `DEVELOPER_DIR` 是唯一变量。

但它**救不了 `flutter build ios`** —— Xcode 的脚本阶段虽然导出了 `DEVELOPER_DIR`
（日志里能看到 `export DEVELOPER_DIR=/Applications/Xcode.app/...`），
flutter_tools 起 hook 子进程时不会透传。必须走 sudo：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

**② 无 Development Team。** 真机部署需要在 Xcode 里选 Team，命令行代劳不了。
`flutter build ios --debug --no-codesign` 一直走到 `Xcode build done. 16.6s`
才在这里失败。

**已修掉的部分**：`ios/Podfile` 的 Runner target 里补了 `use_modular_headers!`。
不加会这样失败（`pod install` 阶段，早于 Xcode）：

```
[!] The following Swift pods cannot yet be integrated as static libraries:
The Swift pod `DKPhotoGallery` depends upon `SDWebImage`, which does not define modules.
```

依赖链路：`file_picker` → `DKImagePickerController` → `DKPhotoGallery` → `SDWebImage`。
（`file_picker` 是真在用的：保存图片、选备份目录、导入文件，删不得。）

### 2.5.2 环境陷阱（不是代码问题，但能耗半天）

| 现象 | 根因 | 处理 |
|---|---|---|
| `brew install cocoapods` → `Error: cocoapods: no bottle available!` | USTC 镜像没有 macOS 27 的 bottle | 临时换官方源 + 代理：`HOMEBREW_BOTTLE_DOMAIN=https://ghcr.io/v2/homebrew/core HOMEBREW_API_DOMAIN=https://formulae.brew.sh/api` |
| `pod install` 卡在 `Cloning into ...`，最终 `Recv failure: Operation timed out` | `github.com` 直连超时 | 挂 `https_proxy=http://127.0.0.1:7897` |
| `git clone` → `LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to github.com:443` | 本地代理跑 HTTP/2 不稳 | `git -c http.version=HTTP/1.1`（实测加上就通） |

### 2.5.3 Flutter 3.47 会在构建时直接改写平台工程

不是提示、不是警告，是**直接改仓库文件**。2026-09-29 一次构建之后的 diff：

| 文件 | 变化 |
|---|---|
| `ios/Runner/AppDelegate.swift` | `FlutterAppDelegate` 加 `FlutterImplicitEngineDelegate`，插件注册移到 `didInitializeImplicitFlutterEngine` |
| `ios/Runner/Info.plist` | 新增 `UIApplicationSceneManifest`（UIScene 迁移）、`CADisableMinimumFrameDurationOnPhone` |
| `ios/Runner.xcodeproj` + `Runner.xcscheme` | 新增 `FlutterGeneratedPluginSwiftPackage` 与 PreActions |
| `ios/Flutter/AppFrameworkInfo.plist` | 移除 `MinimumOSVersion` |
| `macos/Runner.xcodeproj/project.pbxproj` | `MACOSX_DEPLOYMENT_TARGET` 10.15 → 12.0；新增 SPM 集成 |
| `macos/Podfile` | `platform :osx, '10.15'` → `'12.0'` |
| `pubspec.lock` | 98 个依赖重新解析（含 `vector_math 2.4.2 → 2.4.3`） |

**给后人的提醒**：pull 下来发现平台目录有 diff、但没人碰过，先想想是不是构建产生的。

### 2.5.4 macOS 现在的真实状态（2026-09-29 实测）

| 事项 | 结果 |
|---|---|
| `flutter analyze` | 0 error，4 info |
| `flutter test` | 70/70 通过 |
| `flutter build macos --debug` | ✅ |
| `flutter build macos --release` | ✅ 50.0MB |
| app 启动 | ✅ 进程正常起 |
| 界面渲染（截图实测） | ✅ 订阅源面板、未读数（10）、空状态提示均正常 |
| 持久化数据读取 | ✅ 改包名后迁移的 1 个源 / 12 篇文章被正确加载并显示 |
| 沙盒网络权限 | ✅ `network.client = true`（`codesign -d --entitlements -` 实测；Debug 与 Release 两份 entitlements 都已含） |
| 真实 RSS 抓取 | ✅ sspai 10 篇 / coolshell 15 篇，标题、日期（已 `toLocal()`）、链接均正确 |
| 真实 Atom 抓取 | ✅ ruanyifeng 3 篇 |
| 需翻墙的源 | ❌ `feeds.bbci.co.uk` 超时（dio 不读系统代理，国内源正常） |
| **完整交互链路** | **❌ 从未在 macOS 上跑过** |

最后一条是重点：macOS 上「能编译、能抓源」已证明，但
添加源 → 列表 → 详情 → 全文抓取 → 收藏 → 已读 → 删除 → OPML 导入导出 →
备份/恢复 → 图片下载 → 分享 → 外部链接 这整条链路**一次都没验证过**。
在跑完之前，不要写成「macOS 已支持」。

注意 Web 端的 e2e 走的是 `tool/e2e_fixture/` 那套 CORS 代理，跟真实 macOS 环境不是一回事。

### 2.6 规范

- `analysis_options.yaml` 里 `deprecated_member_use: ignore` 掩盖了一批存量：`WillPopScope`（`settings_screen.dart`）、`MaterialStateTextStyle`、`ColorScheme.background/surfaceVariant`
- `article_detail_screen.dart` 顶部 `// ignore_for_file: use_build_context_synchronously` 全局压制了正在发生的 async-gap 问题
- `ResponsiveLayout` 只在首页使用，与「统一用它做宽屏适配」的约定不符

### 2.7 HDR / 宽色域（2026-09-29 逐层核实）

结论：**真 HDR（超出 SDR 白点的亮度）在 Flutter 上做不到，这是引擎级限制，
app 代码解决不了。而宽色域 P3 已经自动生效，不需要改任何东西。**

#### 已经生效的：宽色域 P3

完整调用链（均在 `~/development/flutter/engine/src/flutter/`）：

```
FlutterEngine.mm:742              flutterArguments.enable_wide_gamut = enableWideGamut
FlutterDartProject.mm:87          enableWideGamut = enableImpeller(YES) && MTLGPUFamilyApple3
  ↓  settings.enable_wide_gamut
image_decoder.cc:27               ImageDecoderImpeller(..., settings.enable_wide_gamut, ...)
  ↓
image_decoder_impeller.cc:714     wide_gamut_enabled && Capabilities()->SupportsExtendedRangeFormats()
capabilities.cc / context_mtl.mm  SupportsExtendedRangeFormats = [device supportsFamily:MTLGPUFamilyApple3]
```

表面格式也已经是 10bit 扩展色域（`FlutterSurface.mm:62,117`）：

```objc
enableWideGamut ? MTLPixelFormatBGRA10_XR : MTLPixelFormatBGRA8Unorm;
IOSurfaceSetValue(res, kIOSurfaceColorSpace, kCGColorSpaceExtendedSRGB);
```

当前机器：Apple Silicon（满足 `Apple3`）+ `Built-in Liquid Retina XDR Display`
（`system_profiler` 实测），`canRepresentDisplayGamut:NSDisplayGamutP3` 成立。
Info.plist 里没有任何开关 → 走默认，Impeller 开。

**所以 P3 图片现在就是按宽色域渲染的，不需要做任何事。**

#### 做不到的：EDR / 真 HDR

1. `wantsExtendedDynamicRangeContent` 与 `CAEDRMetadata` 在整个
   `shell/platform/darwin/` 里**零出现**（grep 实测，非推测）。
2. 呈现走的是普通 `CALayer` + IOSurface（`FlutterSurfaceManager.mm` 的
   `UpdateContentSubLayers` 里 `[CALayer layer]` + `layer.contents = surface`），
   不是 `CAMetalLayer`。
3. [flutter/flutter#127520](https://github.com/flutter/flutter/issues/127520)
   （macOS EDR support）**至今 open**，无 milestone、无 assignee、无关联 PR。
   维护者 knopp：*"There's more work needed to get HDR working on macOS than
   just a property on CA(Metal)Layer"*。

#### 两个缺口，只堵上一个也没用

| 缺口 | 能不能在 app 里修 |
|---|---|
| ① layer 未 opt-in EDR | 理论可以：macOS 26+ 有 `CALayer.preferredDynamicRange`（`.high`），旧的 `wantsExtendedDynamicRangeContent` 已在 macOS 26 **obsolete**（本机是 27.0.1，只能用新的） |
| ② 解码器不产出 > 1.0 的 HDR 内容 | **不能**。HEIC gain map / PQ / HLG 都会被 Skia 当 SDR 解，值不会超过 1.0 |

即使堵上 ①，屏幕上也没有超过 1.0 的像素可显，所以**看不到任何变化**。

#### 如果以后真要做

唯一可行的路是**原生平台视图**：用 `FlutterPlatformView` 托管一个自己控制的
NSView，在里面用 Apple 原生 API（能处理 gain map）渲染 HDR 图片。
代价：仅 macOS、平台视图在 macOS 上本身有 z-order / 合成限制、且与正文混排困难。

#### 验证方法（不需要改代码）

```bash
system_profiler SPDisplaysDataType | grep -i "Display Type"   # 看是不是 XDR
# 确认引擎侧开关仍然是自动开启的（版本升级后重查）：
grep -n "enableWideGamut" ~/development/flutter/engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterDartProject.mm
```

---

## 三、如何复现验证

**优先用 macOS 端验**：没有 CORS 问题，直接添加真实源即可（实测可用源见 2.5.4）。

```bash
flutter run -d macos
# 添加 https://sspai.com/feed  或  https://www.ruanyifeng.com/blog/atom.xml
```

**Web 端**才需要本地 fixture（受 CORS 限制抓不到真实源），仓库内带了：
**`tool/e2e_fixture/`**（用法、每个文件回归什么、有哪些坑，都写在它自己的 README 里）。

```bash
flutter build web --release
python3 -m http.server 8099 --directory build/web   # 应用
python3 tool/e2e_fixture/serve.py 8100               # 带 CORS 的测试源
# 在应用里添加 http://127.0.0.1:8100/feed.xml  或  /atom.xml
```

fixture 覆盖的回归点：相对图片路径、懒加载 `data-src`、摘要不足触发的全文抓取、
只有 `dc:date` 的 RSS 条目、只有 `<updated>` 的 Atom 条目。

### 经验

1. **改动解析/渲染逻辑后要跑 e2e，不能只跑单测。** 单测能覆盖纯函数，
   但「真的渲染出来了」只有 e2e 看得到 —— 相对图片 404、404 错误页被当成正文、
   双层标题栏都是这样发现的。
2. **断言「未读徽标」之前先查 `isRead`。** 界面上没有徽标，可能只是那篇确实已读。
   曾经把这种情况误报成 bug。
3. **看服务器日志分清是 curl 还是应用发的请求。** 自己探测过某个 URL 之后，
   日志里就会出现它，容易误判成回归。
4. **fixture 必须发 `Cache-Control: no-store`**（`serve.py` 已带），
   否则浏览器会按启发式规则缓存：改了 feed 之后应用仍在拿旧内容。
