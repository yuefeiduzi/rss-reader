# 待办

详细的已核实问题与技术债见 [docs/known-issues.md](docs/known-issues.md)。本文件只放**路线图**。

最后核对：2026-10-12（新增「下一批」六项；桌面打磨 ②③④ 已于 2026-09-30 完成，
只剩 ① 图标 —— 并入下一批。证据都在 docs/known-issues.md 与本文件的里程碑里）

当前基线：`flutter analyze` **0 issues**，`flutter test` 101 个通过，
`./tool/run_macos_e2e.sh` 7/7 通过；macOS debug/release 均可构建。

---

## 进行中

（暂无 —— 上一批四项（死代码 / 渲染失败降级 / async-gap 警告 / 批量下载）
已于 2026-09-30 全部完成（里程碑 E），桌面打磨 ②③④ 也已完成（里程碑 F）。
下一批六项已排定，见下。）

## 下一批（2026-10-12 排定）

六项：**① 图标 / ② 国际化 / ③ 正文视频 / ④ 正文规范 / ⑤ 二级列表页 / ⑥ 导入导出测试**。
②④③⑤ 都动 UI 与文案，①⑥ 相对独立。

建议顺序：先 ②（l10n 基建落地后，后面新写的界面直接走 l10n，不会二次返工）→ ④ → ③
（同在 `html_content_view.dart` / `html_content.dart` 一带）→ ⑤（列表页设计）；
① 的设计稿要人拍板，越早越好、可与其它项并行；⑥ 随时能插。

### ① App 图标（六平台还是 Flutter 默认图标）

- [ ] 现状（2026-10-12 核实）：macOS `AppIcon.appiconset` 里 7 个 PNG
      （16/32/64/128/256/512/1024，@1x/@2x 由 `Contents.json` 映射）、iOS 15 个 PNG、
      Android 5 个 `mipmap-*/ic_launcher.png`（**没有 adaptive icon**，无 `mipmap-anydpi-v26`）、
      Web 最弱：`web/` 下只有 `index.html`，**没有任何 favicon / manifest 引用**（grep 0 命中）
- [ ] 步骤
      - 出 2–3 个方向的设计稿（可先用 codemode 的 image models 出草图），1024×1024 定稿；
        16/32pt 下要能辨认 —— 别用细线、渐变细节、小字
      - 生成各平台资源：`flutter_launcher_icons`（dev dependency，最新 0.14.4；README 已核实
        支持 android / ios / macos / web / windows，Android 可配 adaptive
        foreground / background / monochrome）
      - Web 的 `web/icons/` 与 `manifest.json` **现在根本不存在**，要新建并在 `index.html` 里引用
      - 逐平台核对文件真的被替换（生成器「跑成功但没动文件」是常见坑）
- [ ] macOS 设计约束：系统不裁圆角、不加投影，圆角要画进图里；画布四周自己留白
      （Apple 网格：1024 画布里内容约占 824，即四周约 10%）
- ⚠️ 加 dev 依赖会触发 `flutter pub get` 重新解析：**必须带着 `PUB_HOSTED_URL` 镜像跑**，
      否则 `pubspec.lock` 那 99 行会被静默改写成 pub.dev（AGENTS.md 陷阱 8）
- [ ] 验收：至少 macOS + Web 两端。`flutter build macos --release` + `./tool/build_macos_dmg.sh`，
      在 Finder 看 DMG 图标、装到 Applications 看 Dock / 关于本机；Finder 有图标缓存，
      看不到变化不代表没生效（`killall Finder`，或换个没跑过的新用户/机器验证）

### ② 国际化（中文 + 英文）

- [ ] 现状：文案手写且中英混杂 —— 设置页整页英文（`Settings` / `Appearance` / `Theme` /
      `Backup Now` / `Import` / `System` / `Light` / `Dark`，`lib/ui/screens/settings_screen.dart`），
      其余页面中文；相对时间写死中文（`lib/utils/date_format.dart` 的「分钟前 / 小时前 / 天前」）；
      service 层还有直接弹给用户的英文异常（`backup_service.dart` 的 `Backup file not found` /
      `OPML file not found` / `Invalid backup file...`）。粗扫字面量：`lib/ui` 126 处含中文、
      `lib/services` 5 处、`lib/utils` 3 处（含 `debugPrint`，动手前逐条筛，日志不算 UI）
- [ ] 方案：Flutter 官方 gen-l10n，不引第三方
      - `pubspec.yaml` 加 `flutter_localizations: sdk: flutter` + `intl`
        （Flutter 3.47.4 的 flutter_localizations 锁 `intl ^0.20.3`，照抄）
      - `l10n.yaml`：`arb-dir: lib/l10n`、`template-arb-file: app_en.arb`、
        `output-localization-file: app_localizations.dart`
      - ⚠️ `flutter gen-l10n --help` 实测（3.47.4）：`--synthetic-package` 已废弃且
        「cannot be enabled」，生成文件直接落在 `lib/l10n/` —— 生成物要提交进仓库
      - `MaterialApp` 加 `localizationsDelegates`（`AppLocalizations.delegate` +
        GlobalMaterial / Widgets / Cupertino）+ `supportedLocales: [en, zh]`；locale 跟随系统，
        先不做手动切换（要做就得加 config 字段，注意 StorageService 落盘）
      - service 层拿不到 `context`：把 `backup_service.dart` 的裸 `Exception('...')` 换成
        类型化异常 / 错误码，由 UI（设置页 snackbar）映射到 l10n
      - 日期：`date_format.dart` 改走 `intl` 的 `DateFormat` + ARB plural 消息；
        **保留** `toLocal()`（历史 8 小时 bug）与「未来时间回退到绝对时间」两个行为，
        `test/date_format_test.dart` 同步改
- [ ] 验收：`flutter gen-l10n` 成功；`flutter analyze` 0 issues；`flutter test`；
      系统语言切英文后 macOS 手点主要页面（首页 / 添加订阅 / 列表 / 详情 / 设置 / 功能介绍）
      无漏网；`rg "'[^']*[\x{4e00}-\x{9fff}][^']*'" lib/ui` 只剩注释与 debugPrint

### ③ 正文支持 video

- [ ] 现状：渲染引擎 `flutter_widget_from_html_core` 0.17.4 只做核心元素 —— 源码里 grep
      `video|iframe|audio` **0 命中**，`<video>` / `<iframe>`（YouTube / Bilibili 嵌入）
      没有专门处理。先给 fixture 加一篇带视频的文章，记录现状（可能整段空白，也可能露出
      fallback 文本）再动手
- [ ] 方案（按投入从小到大，**建议先做 a**）：
      - **a. 轻量兜底**：`customWidgetBuilder` 拦 `<video>` / `<iframe>`，渲染成
        「视频卡片 + 在浏览器中打开」，复用已有 `url_launcher`。零新增原生依赖、全平台可用；
        缺点是不能站内播放
      - **b. 站内播 `<video>`**：加 `fwfh_chewie`（最新 0.16.1，2025-07；依赖 `chewie ^1.3`
        + `video_player ^2.2.9`，声明兼容 core `>=0.14.2 <0.18.0`，与 0.17.4 兼容）。
        `video_player` 最新 2.14.1 要 Flutter ≥3.44（本机 3.47.4 满足）；
        `video_player_avfoundation` 的 pubspec 里 **iOS + macOS 都声明了**（已核实）
      - **c. 站内播 `<iframe>`**：加 `fwfh_webview`（0.15.8，依赖 `webview_flutter ^4`；
        `webview_flutter_wkwebview` 同样声明了 iOS + macOS，已核实）。风险：一个 iframe
        一个 WKWebView 偏重，macOS 沙盒网络权限虽有，仍要实测
- [ ] 落地：元素识别 / 视频 URL 提取抽成 `lib/utils/html_content.dart` 的纯函数写单测
      （仓库约定：可测逻辑不埋在 widget 私有方法里）；`HtmlContentView` 只负责把自定义
      widget 接到 `customWidgetBuilder`；fixture 请求日志要能证明「没有自动加载 / 自动播放」
- ⚠️ 一旦选 b/c 就多一个原生插件 → 必须重跑 macOS 构建（pod install / SPM，参考
      `ios/Podfile` 的 `use_modular_headers!` 教训）与 `./tool/run_macos_e2e.sh`
- [ ] 验收：识别纯函数单测；fixture e2e；macOS 上挑一个带视频 / 嵌入的真实源手点

### ④ 正文规范：阅读栏最大宽度 + 图片全部居中

- [ ] 现状：详情页正文只加 16pt 内边距（`article_detail_screen.dart` ≈305 行附近），
      窗口一宽正文就铺满整行；图片居中只覆盖「容器里只有图片」的形状
      （`isImageOnlyContainer`，里程碑 F ④），夹在文字里的图片仍是行内 ——
      本次要改成**所有图片都居中**，覆盖 F 的旧规则
- [ ] 目标规范（定稿后写进 `AGENTS.md`，作为唯一约定）：
      - 阅读栏最大宽度（建议 720pt，宽度不足时占满可用宽）并居中
      - 标题 / 作者 / 时间 / 正文在**同一条栏**里 —— 只约束正文会让宽屏下标题贴左、正文居中
      - 所有图片水平居中 + `max-width: 100%` 等比缩放，不溢出（`pre` 代码块的横向溢出
        属于同一批要看的）
      - 宽屏 2/3 栏下，栏宽相对**内容面板**（`LayoutBuilder` 的约束）而非整窗
- [ ] 实现位置：栏宽常量单一来源（`responsive_layout.dart` 或新建
      `lib/ui/components/reading_column.dart`，⑤ 的列表页也能复用）；约束加在详情页滚动内容
      外层，`HtmlContentView` 不再自己限宽。引擎侧有 `max-width` / `display: block` /
      `margin: auto` 支持（`flutter_widget_from_html_core` 的 `style_sizing.dart`：
      `kCssMaxWidth`、`CssLengthUnit.auto`），但**带 `width=` 属性的大图**行为要实测
- [ ] 先照里程碑 F 的做法写「量图片中心点与宽度」的 widget 测试，再改实现
- [ ] 验收：宽/窄 + 深浅主题截图；`flutter test`；`./tool/run_macos_e2e.sh`
      （已有图片居中断言，规则改成「全部居中」后那条断言要跟着改）

### ⑤ 二级文章列表页设计

> 「二级」= 订阅源列表（一级）→ 该博客的文章列表（二级）→ 文章详情（三级）。
> 当前实现：`lib/ui/screens/article_list_screen.dart`（227 行）+
> `lib/ui/components/article_card.dart`（343 行）。

- [ ] 现状：头部只有「描述 + 刷新 + 强制刷新」一条横栏；卡片 = 180pt 头图 + 标题 + 摘要
      + 收藏；**没有**筛选（全部 / 未读 / 收藏）、排序、日期分组、批量操作、「全部已读」
      （known-issues 2.3）；宽屏时它是 `HomeScreen` 三段式的中间栏，窄屏是整页
      （断点 900，`ResponsiveLayout`）
- [ ] 先出设计（建议用 prototype skill 做一版可点的骨架），要拍板的点：
      - 头部放什么：源图标 / 标题 / 未读数 / 上次刷新时间？操作平铺还是收进菜单？
      - 视图：桌面紧凑列表 / 移动卡片，还是两端统一？
      - 筛选与排序的默认值（未读优先？时间倒序？）；筛选是页面本地 state 还是要持久化
      - 空态（现在 `_NoArticles`）/ 抓取失败态（现在只有 snackbar）/ 加载态
      - 「全部已读」放哪、要不要二次确认
      - 文案 key 与 ② 一起定，别让 i18n 返工
- [ ] 实现约束：数据只从 `StorageService.articlesOf(feedId)` 读、未读数用 `unreadCountOf`，
      筛选 / 排序纯客户端；「全部已读」要在 `StorageService` 加批量方法（一次落盘），
      注意「写不阻塞」约定 + `flush()`；保留现有防重入刷新（`_isRefreshing`）
- [ ] 验收：宽/窄 + 深浅主题截图；筛选 / 排序 / 全部已读的 widget 测试；
      `./tool/run_macos_e2e.sh` 的列表用例要跟着改（结构变 → 选择器变）

### ⑥ 导入导出功能测试

- [ ] 现状（2026-10-12 核实）：**没有 `test/backup_service_test.dart`**。唯一覆盖是
      `integration_test/macos_e2e_test.dart` 用例 5（服务层直调 zip 往返 / OPML 去重）；
      原生文件对话框没人点过（AGENTS.md 已列为「自动化覆盖不到」）。`backup_service.dart`
      没有输入校验：`data['feeds'] as List`、`AppConfig.fromJson(data['config'])` 遇坏文件
      直接抛；`'version': '1.0'` 只写不读
- [ ] 补 `test/backup_service_test.dart`（用 `Directory.systemTemp` + `outputDirectory` 参数
      绕开 `path_provider`，保持 hermetic）：
      - 往返：zip / 纯 JSON 两种入口，feeds / articles / config 数量与字段一致、`feedId` 对
      - 失败路径先锁行为再定语义：文件不存在 / 不是 zip / zip 里没有 `backup.json` /
        JSON 不是对象 / 缺 `feeds` | `articles` | `config` 键
      - 去重：重复 feed 不新增且返回计数正确；OPML 同一份导两次第二次为 0
      - OPML：分组嵌套、XML 实体转义（`& < "`）、非法 XML、空文件
      - 规模 sanity：1000 篇文章往返（同时也是存储层改造的基线数据）
- [ ] 人工 / 集成：macOS 真点一遍设置页 Backup Now / Import（保存 → 清数据 → 导入），
      含中文 / 空格路径；Web 端点 Backup 现在抛 `UnsupportedError`（`dart:io`），
      本轮至少要有可读提示、不能崩
- [ ] 关联：给 `file_picker` 引 seam（「工程」区已有条目）后，「用户取消选择」
      「选了非法文件」两条分支可进 widget 测试
- ⚠️ 用例 5 的 `expect(await backup.restoreFromJson(zipPath), 1)` 依赖「重复不计数」语义，
      改行为时同步改

## 平台路线（优先级已定：macOS → Android → iOS）

这三个的顺序是明确的，别打乱。Web 保留为 UI 演示。

- [x] **macOS 可构建 / 可安装**（2026-09-29/30）：Xcode 27 + CocoaPods 1.17.0；
      debug/release 均通过，实测抓到真实 RSS/Atom；`tool/build_macos_dmg.sh` 出
      `build/dist/RSS-Reader-1.0.0-universal.dmg`（22MB，x86_64 + arm64，ad-hoc）。
      完整证据见 [known-issues 2.5.4](docs/known-issues.md)
- [ ] **Android**：SDK 36.0.0 只装了一部分，缺 cmdline-tools、license 未接受
      （`flutter doctor`）→ 补齐后 `flutter build apk` 验证。
      ⚠️ `applicationId` 是 `org.ross.rssReader`，惯例上应为全小写，一并处理
- [ ] **iOS**（有意排最后）：需要两步前置 ——
      ① `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
      （见 [AGENTS.md 陷阱 6](AGENTS.md)：不切的话 macOS 侧也得靠 `DEVELOPER_DIR` 绕过）
      ② 在 Xcode 里选一个 Development Team。
      `ios/Podfile` 的 `use_modular_headers!` 已补好，`pod install` 已能跑通
- [ ] 为 Web 端引入 CORS 代理层（否则 Web 只能作为 UI 演示）

## macOS

构建与完整链路都已经通了（2026-09-30 起链路 e2e 自动化）。
桌面打磨 ②③④ 已完成（见下与里程碑 F），只剩 ① 图标。

**桌面打磨（2026-09-30）**

- [ ] **① 设计并制作 App 图标** —— 已升级为「下一批」第 ① 项（六平台资源现状与步骤都在那里）；
      本节只留一条事实：macOS 图标是 `AppIcon.appiconset` 里 7 个 PNG + `Contents.json`
- [x] **② 窗口默认位置 / ③ 红绿灯适配 / ④ 正文图片居中**（2026-09-30 完成，
      ③ 2026-10-12 重做）——
      ② 优先恢复上次位置，第一次打开居中；③ 现在内容真铺满整窗（`.fullSizeContentView`
      真的加到了窗口上），顶栏压到 52pt，红绿灯与标题/按钮同一条带子，深色下不再有白杠；
      ④ 只有图片的容器加 `text-align: center`。细节与实测记录见里程碑 F

**其余**

- [x] **链路 e2e 已自动化**（2026-09-30）：`integration_test/macos_e2e_test.dart` +
      `./tool/run_macos_e2e.sh`（起 fixture → 6 个用例 → 校验 fixture 请求日志）。
      覆盖加源 / 列表 / 全文抓取 / 收藏 / 已读 / 未读数 / Atom / 删除 / 备份恢复 /
      OPML / 图片与画廊；日志侧硬证据：`placeholder.png` 与 `article2.html` 均 0 请求。
      细节见 [known-issues 2.5.4](docs/known-issues.md)
- [ ] **`xcode-select` 切到 Xcode**（要 sudo）：它现在还指着 CLT，导致直接跑
      `flutter build macos` / `flutter test -d macos` 会报 “Xcode not installed”
      （两个脚本里靠 `DEVELOPER_DIR` 绕过）。与 iOS 的前置是同一件事，见 traps 6
- [x] bundle id 已改为 **`org.ross.rssReader`**（2026-09-29，六个平台都改了；
      Android 全小写的惯例问题见「平台路线」的 Android 条目）
- [ ] **要分发给别人就得买 Developer ID + 公证**：现状是 ad-hoc 签名，
      `spctl -a -t exec` 返回 rejected。自己用没事（实测从只读 DMG 能启动），
      别人下载会被 Gatekeeper 拦。
      ⚠️ **换自签名证书解决不了这个问题** —— 证书不在别人信任库里，一样被拦，
      只是提示语不同。详见 `docs/UNSIGNED.md` 与 AGENTS.md 的「签名：三条路的区别」
- [ ] `MainFlutterWindow.swift` 设了默认 1200×800，但没设 `minSize`，
      窗口可以拖到很小，窄屏布局可能崩
- [ ] **抓不到需要翻墙的源**：`dio` 走 dart:io 默认直连，不读系统代理。
      实测 `feeds.bbci.co.uk` 超时、国内源正常。要不要加代理设置项待定
- [ ] macOS 系统菜单栏（App / Edit / Window 的惯例项）未检查过
- [ ] **HDR 图片**：引擎级限制，app 代码解决不了 —— 详见
      [known-issues 2.7](docs/known-issues.md)。P3 宽色域已自动生效，真 HDR 需等
      [flutter#127520](https://github.com/flutter/flutter/issues/127520)
- [ ] 待验证：`share_plus` / `file_picker` 在 macOS 上的**原生对话框**行为
      （两者都不支持 SPM，走的是 CocoaPods 回退路径；集成测试绕过了对话框，因为会卡住）
      —— `file_picker` 部分已排进「下一批」第 ⑥ 项

## 架构改进

- [ ] 存储层改造：`_saveToPrefs` 每次落盘都重新序列化全部 feeds/articles/config，
      Web 的 localStorage 有 ~5MB 上限。考虑改用对象存储（Hive / Isar / sqlite）或按 feed 分片。
      注意接口约定已改成「写不阻塞、后台排队落盘」，所以改的是容量与放大，不是交互卡顿
- [ ] `theme_service.dart` 的两份重复 ThemeData 收敛为共享 builder
      （`lightTheme` ≈58 行起，`darkTheme` ≈262 行起，各约 190 行）
- [ ] 清理 `analysis_options.yaml` 的 `deprecated_member_use: ignore`，逐个修掉：
      `theme_service.dart` 的 `surfaceVariant` ×2 / `MaterialStateTextStyle` ×2，
      `settings_screen.dart:175,176` 的 `surfaceVariant`
      （`WillPopScope` 已全部迁到 `PopScope`，不用再留）
- [ ] 宽屏适配统一走 `ResponsiveLayout`：目前只有 `home_screen.dart` 用它，
      详情页与列表页尚未接，与 AGENTS.md 的约定不符

## 功能

- [ ] 国际化 —— 已排进「下一批」第 ② 项（含方案与验收），这里不再重复
- [ ] 订阅源分组
- [ ] 搜索
- [ ] 「全部已读」（[known-issues 2.3](docs/known-issues.md)：目前只能逐篇点开）
      —— 并入「下一批」第 ⑤ 项（列表页重设计）一起做
- [ ] Web 端备份导出（改为浏览器下载）—— `backup_service` 用 `dart:io` + `path_provider`，
      Web 调用直接抛 `UnsupportedError`
- [ ] 正文图片缓存：曾用 `cached_network_image` 接管，Web 上关闭画廊后图片变黑块已回退。
      建议改用 fwfh 的 `customWidgetBuilder` 自行接管 `img` 元素（见 known-issues 2.4.1）

## 工程

- [ ] 补充更多 widget 测试（现有 3 个：空状态、写入后自动更新、未读数增量维护）
- [ ] 引入接口 seam 以便 mock：`file_picker` / `share_plus` / `Clipboard` /
      `url_launcher`，以及 `RssService` 的 `Dio`（现在是 `RssService()` 内部 `Dio()`，
      无法注入）；`article_detail_screen` 里的单张/批量下载也各自 `Dio()` 直连
      —— `file_picker` 那一半已排进「下一批」第 ⑥ 项（导入导出测试）
- [x] **2026-09-30 已完成**：CI（analyze/test/build web/build macos + tag 发版）、
      把 `tool/e2e_fixture/` 接进自动化（macOS 集成测试）、清掉无引用依赖
      （`cached_network_image` + 13 个传递依赖）。细节见里程碑 E 与 AGENTS.md

---

## 已完成的里程碑

<details>
<summary><b>F. macOS 桌面打磨：窗口位置 / 红绿灯 / 图片居中</b>（2026-09-30）</summary>

**② 窗口默认位置**

`MainFlutterWindow.swift` 原来写死 `NSRect(x: 0, y: 0, ...)`，而 Cocoa 坐标原点在
左下角，所以窗口总是开在屏幕左下角。现在用 `setFrameUsingName` +
`setFrameAutosaveName` 恢复上次的位置与大小，第一次打开（没有存档）时 `center()`。
实测：清掉存档后首次打开落在 (156, 71)、1200×800，正好是主屏居中。

**③ 红绿灯（traffic lights）适配**

- 窗口：`titlebarAppearsTransparent = true` + `titleVisibility = .hidden` +
  **`.fullSizeContentView`**，Flutter 内容铺满整窗（含标题栏那条带），红绿灯浮在
  Flutter 画的顶栏左上角，整个头部只有一条带子（像 Mail / Notes）
- ⚠️ 坑：`MainMenu.xib` 里 window 的 `styleMask` 只有
  `titled/closable/miniaturizable/resizable`，**没有 fullSizeContentView**。
  早先 Swift 里只是拿它算了个 rect 却从没赋给窗口，于是内容视图从标题栏下方开始，
  顶上留一条原生色带 —— 浅色主题下也是白的，看不出来；深色主题下就是一条白杠
  （实测 y=0..32pt 恒为 `#FFFFFF`）。修法就是 `self.styleMask.insert(.fullSizeContentView)`
- Flutter 侧顶栏：`lib/ui/components/app_top_bar.dart` 统一三件事 —— 工具栏压到
  52pt（`macOSTopBarHeight`）、标题往右让开红绿灯 80pt（`macOSTrafficLightInset`）、
  返回键画在标题前面（AppBar 自带的 `leading` 会被居中到红绿灯底下，点不到）。
  三个页面（首页 / 设置 / 功能介绍）共用这一个组件，不再各写一遍
- **红绿灯与标题同线**：AppKit 默认把红绿灯居中在标题栏那条 32pt 的带子里
  （实测按钮中心距窗口顶 16pt），而顶栏是 52pt、中线在 26pt，看着就「高了一截」。
  AppKit 没有「把红绿灯居中到自定义高度」的接口（那是 NSToolbar 的事），
  所以 `MainFlutterWindow.alignTrafficLights()` 自己挪这三个按钮：
  按「目标位置 - 当前位置」算位移，可重复调用；窗口 resize、退出全屏后
  AppKit 会弹回原处，所以 `didResizeNotification` / `didExitFullScreenNotification`
  之后再对齐一次。实测：按钮中心 25.8pt vs 标题墨迹中心 25.5pt；缩小窗口、
  进出全屏后仍是 26pt；挪过之后仍可点（点绿按钮确实缩放了窗口）
- 拖动：`isMovableByWindowBackground` 实测**不管用**（Flutter 视图拦掉事件，
  引擎里也没有相关支持）。在 AppBar 的 `flexibleSpace` 挂一层
  `MacWindowDragArea`，经 method channel 调 `performDrag(with:)`。
  实测：拖顶栏窗口跟随位移移动（+120,+60 精确跟随）；双击顶栏的系统缩放也还在
- 按钮不受影响：集成测试用例 7 点主题按钮与设置入口均正常（拖拽层不吞点击），
  实机也点到了位于标题栏那条带里的主题按钮

**旧实现的教训**：上一版把标题栏高度注入 `MediaQuery.padding.top`，等于在
「内容本来就已让出标题栏」的基础上又让了一次，顶栏实际有 32+28+56 = 116pt 高，
深色下还多一条白杠。现在既没有这层 padding，也没有原生色带。

顶栏高度的唯一来源是 Dart 的 `macOSTopBarHeight`，启动时经 method channel
告知原生（`syncMacOSTopBarHeight`）—— 两边各写一个常量迟早写歪
（历史上 AppKit 的标题栏是 32pt，Dart 里写的却是 28）。

**④ 正文图片居中**

先看真实源再定规则：少数派 21 个 `figure` 里 20 个是「容器里只有一张图」，
coolshell 用 `<p><img></p>` —— 都是「容器里只有图片」。规则就取这个形状：
只给这种容器加 `text-align: center`（图片是行内元素，`text-align` 只有落在
容器上才生效），夹在文字里的图片保持行内。实现是
`lib/utils/html_content.dart` 的 `isImageOnlyContainer`（6 个单测）+
`stylesForElement` 里合并样式；另有 2 个 widget 测试直接量图片中心点，
确认真的居中。fixture 的 `article1.html` 顺手改成真实源的形状（图片包进 `<p>`）。

**验证**：`flutter analyze` 0 issues；`flutter test` 101 个通过；
`./tool/run_macos_e2e.sh` **7/7**（新增用例 7 与图片居中断言）；
release 构建 + 安装 + 截图人工确认窗口观感。

</details>

<details>
<summary><b>E. 清尾：死代码 / 渲染失败降级 / async-gap 警告 / 批量下载</b>（2026-09-30）</summary>

**死代码清零**

- 删 `cache_service` 的 6 个无调用方法，连带那套从未接线的 Base64 图片缓存
  （它只会把空 map 反复写进 prefs）
- 删 `backup_service` 的 `getBackupFiles` / `importOpmlFromZip`、
  `responsive_layout` 的 `isWideScreen`
- 顺带删掉 pubspec 里已无引用的 `cached_network_image`（连带 13 个传递依赖：
  sqflite / http / rxdart / flutter_cache_manager …）

**`_hasError` 接上真信号（不再只读）**

`HtmlContentView` 新增 `onRenderError`，透传 fwfh 的 `onErrorBuilder`；
只对「整篇构建失败」（引擎传入的合成根元素 `root`）降级，
单张图片 404 不会把整篇文章换成纯文本。降级 UI 抽成 `HtmlRenderFallback`
（可单独测试），换正文（重新抓取/切文章）时给引擎重试机会。
新增 4 个单测覆盖判别逻辑与降级 UI。

**3 条 `use_build_context_synchronously` 全修**

`article_detail_screen.dart` 的 `_downloadImage` 两处、`feed_context_menu.dart`
的 `showMenu` 之后 —— 都用 `context.mounted` 守卫。
`flutter analyze` 因此变成 **0 issues**（此前 4 条存量 info）。

**批量下载图片（新功能）**

详情页动作栏新增「下载全部图片」：只弹一次目录选择框、串行下载、
单条进度 snackbar、结束给汇总（成功/失败张数）。文件名推导抽到
`lib/utils/download_names.dart`，10 个单测覆盖 query 剥离 / 百分号编码 /
跨平台非法字符 / 同名去重。

**验证**：`flutter analyze` 0 issues；`flutter test` 79 → 93；
`./tool/run_macos_e2e.sh` 6/6 仍全绿（详情页与画廊被改动过，必须重跑）。

</details>

<details>
<summary><b>D. 拆解上帝组件 + 引入状态管理</b>（2026-09-16）</summary>

**状态管理**
- `StorageService` 成为唯一的 `ChangeNotifier` 真相来源：读操作改同步；
  未读数内部增量维护（不再是 O(源数 × 文章数)）；写操作立即返回、
  后台按提交顺序排队落盘（并发写会让旧快照覆盖新数据）
- 服务通过 `MultiProvider` 注入，`provider` 依赖终于真正被用上
- 删除了所有「写完之后手工刷新」：`_loadFeeds()`、`onArticleRead` 回调、
  设置页的 `shouldRefresh` 返回值

**拆解**

| 文件 | 行数变化 |
|---|---|
| `home_screen.dart` | 747 → 248 |
| `article_list_screen.dart` | 608 → 227 |
| `article_detail_screen.dart` | 1046 → 593 |
| `feed_list_tile.dart` | 632 → 443 |

新拆出：`feed_list_panel.dart`（同时消除两份几乎相同的列表构建）、
`article_card.dart`、`image_gallery.dart`、`feed_context_menu.dart`。

**同时修掉的缺陷**
- 窄屏双层标题栏（子页面不再自带 Scaffold / AppBar）
- 过度刷新（实测：打开文章不再触发整源网络刷新）
- 添加订阅源重复请求（最坏 3 次 → 1 次；对话框只拉一次并直接交出 `Feed`）
- **feed id 冲突**：`_generateId` 只取 host + path，仅 query 或端口不同的
  两个源会撞成同一个 id，导致按 id 取源/取文章/删除/置顶全部作用到错误的源
- **404 错误页被当成正文**渲染并写进缓存（`validateStatus` 放行了 `< 500`）
- 删除确认弹两次（tile 与面板各一份）

**删除的死代码**（约 220 行）：`_showImagePreview`、`_showImageContextMenu`、
`_openImageGalleryFromContext`、`_downloadAllImages`。

**验证**：70 个测试通过；e2e 实测宽/窄两种布局的完整链路
（添加 → 列表 → 详情 → 收藏 → 已读 → 删除）。

</details>


<details>
<summary><b>C. 迁移 HTML 渲染引擎</b>（2026-09-16）</summary>

`flutter_html`（停更的 3.0.0，且违规使用 html 包私有 API）→
`flutter_widget_from_html_core` 0.17.4（活跃维护，仅 3 个依赖）。

- 渲染逻辑抽出到 `lib/ui/components/html_content_view.dart`
- 同步移除了 `html: 0.15.4` 的版本锁定
- 正文图片点击 → 全屏画廊终于接线（此前是死代码）
- 新增 `test/html_content_view_test.dart`（CSS 映射与颜色转换）
- 实测渲染保真度优于原引擎（列表、代码块、标题层级均正确）

尝试过程记录：曾用 `cached_network_image` 接管正文图片，但 Web 上关闭画廊后图片会变成
黑块，已回退（见 [known-issues 2.4.1](docs/known-issues.md)）。

</details>

<details>
<summary><b>第一轮缺陷修复</b>（2026-09-16，16 项）</summary>

- 全文抓取必然返回空串
- 只有 `<updated>` 的 Atom 源解析崩溃
- `dc:date` 未生效
- 正文相对图片 404；头图懒加载与相对路径
- 时间显示差 8 小时（缺 `toLocal()`）
- OPML 导入无法工作（属性顺序依赖）
- 导入数量虚报
- `getAllArticles(limit)` 失效
- 「跟随系统」主题重启失效
- 裸域名输入被拒
- `getAllFeeds` 泄漏内部列表
- 批量导入 feed id 重复
- `async void` 吞异常
- 备份文件列表永远为空
- `CupertinoPageTransitionsBuilder` 编译失败
- 建立测试地基：`lib/utils/` 纯函数层 + 66 个测试

</details>