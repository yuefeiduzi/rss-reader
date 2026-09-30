# 待办

详细的已核实问题与技术债见 [docs/known-issues.md](docs/known-issues.md)。本文件只放**路线图**。

最后核对：2026-09-30（清掉已完成/失效的旧条目；桌面打磨 ②③④ 已完成（见里程碑 F），
只剩 ① 图标。证据都在 docs/known-issues.md 与本文件的里程碑里）

当前基线：`flutter analyze` **0 issues**，`flutter test` 101 个通过，
`./tool/run_macos_e2e.sh` 7/7 通过；macOS debug/release 均可构建。

---

## 进行中

（暂无 —— 上一批四项（死代码 / 渲染失败降级 / async-gap 警告 / 批量下载）
已于 2026-09-30 全部完成（里程碑 E），桌面打磨 ②③④ 也已完成（里程碑 F）。
下一步：① 图标，或从下面的路线里挑。）

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

- [ ] **① 设计并制作 App 图标** —— 现在六个平台全是 Flutter 默认图标。
      出 1024×1024 设计稿 → 生成各平台资源：macOS 的
      `macos/Runner/Assets.xcassets/AppIcon.appiconset/`（16/32/128/256/512，@1x/@2x 全套）、
      Android mipmap 各密度、iOS AppIcon、Web favicon/PWA。
      注意 macOS 规范：系统不裁圆角也不加投影，画布四周要自己留白
      （Apple 网格：1024 画布里内容约占 824，即四周约 10%）。
      可用 `flutter_launcher_icons` 一次性生成（dev dependency）
- [x] **② 窗口默认位置 / ③ 红绿灯适配 / ④ 正文图片居中**（2026-09-30 完成）——
      ② 优先恢复上次位置，第一次打开居中；③ 标题栏透明 + `.fullSizeContentView`，
      红绿灯浮在 Flutter 顶栏上，整条顶栏都能拖动（`MacWindowDragArea` + method channel）；
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

- [ ] 国际化：设置页与错误提示是英文（`Theme` / `Backup Now` / `Restore successful!`），
      侧栏与其余页面中文，日期也无本地化
- [ ] 订阅源分组
- [ ] 搜索
- [ ] 「全部已读」（[known-issues 2.3](docs/known-issues.md)：目前只能逐篇点开）
- [ ] Web 端备份导出（改为浏览器下载）—— `backup_service` 用 `dart:io` + `path_provider`，
      Web 调用直接抛 `UnsupportedError`
- [ ] 正文图片缓存：曾用 `cached_network_image` 接管，Web 上关闭画廊后图片变黑块已回退。
      建议改用 fwfh 的 `customWidgetBuilder` 自行接管 `img` 元素（见 known-issues 2.4.1）

## 工程

- [ ] 补充更多 widget 测试（现有 3 个：空状态、写入后自动更新、未读数增量维护）
- [ ] 引入接口 seam 以便 mock：`file_picker` / `share_plus` / `Clipboard` /
      `url_launcher`，以及 `RssService` 的 `Dio`（现在是 `RssService()` 内部 `Dio()`，
      无法注入）；`article_detail_screen` 里的单张/批量下载也各自 `Dio()` 直连
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

- `titlebarAppearsTransparent = true` + `titleVisibility = .hidden` +
  `.fullSizeContentView`：不再有系统标题栏 + 应用顶栏两层，Flutter 顶栏顶到
  窗口最上方，红绿灯浮在它上面（像 Mail / Notes）
- Flutter 侧把标题栏高度注入 `MediaQuery.padding.top`（`lib/utils/macos_window.dart`
  + `main.dart` 的 `builder`）：AppBar 自己会加高并把标题、按钮下移，
  不用逐页写 padding；窄屏（返回按钮在左侧）也不会撞到红绿灯 —— 截图验证过
- 拖动：`isMovableByWindowBackground` 实测**不管用**（Flutter 视图拦掉事件，
  引擎里也没有相关支持）。改成在 AppBar 的 `flexibleSpace` 挂一层
  `MacWindowDragArea`，经 method channel 调 `performDrag(with:)`。
  实测：拖顶栏窗口跟随位移移动；拖侧栏 tile / 空白处窗口不动
- 按钮不受影响：集成测试用例 7 点主题按钮与设置入口均正常（拖拽层不吞点击）

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