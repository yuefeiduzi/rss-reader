# 待办

详细的已核实问题与技术债见 [docs/known-issues.md](docs/known-issues.md)。本文件只放**路线图**。

最后核对：2026-09-16（逐条对照源码、`flutter analyze`、`flutter test`、`flutter doctor`；
已不成立的旧条目记在文末的「本轮核对」里，别再照着做）

当前基线：`flutter analyze` 4 条 info（都是下方记的存量），`flutter test` 70 个通过。

---

## 进行中

- [ ] **清理剩余死代码**（更新后的清单在 [known-issues 2.4](docs/known-issues.md)）：
      `cache_service` 的 `getCachedArticle` / `cacheImage` / `getCachedImage` /
      `clearArticleCache` / `clearAllCache` / `getCacheStats`，
      `backup_service` 的 `getBackupFiles` / `importOpmlFromZip`，
      `responsive_layout` 的 `isWideScreen`
- [ ] **处理 `_hasError` 降级分支**：只读不写，永不触发，analyzer 已经把它报成
      `prefer_final_fields`。二选一 —— 接上错误信号，或连分支一起删
- [ ] **修 `use_build_context_synchronously` 警告**：`article_detail_screen.dart:155,164`、
      `feed_context_menu.dart:58`。原先的 `ignore_for_file` 已不在，问题本身还在，
      现在是 analyzer 里看得见的 3 条 info
- [ ] **批量下载图片**（是补功能，不是修 bug）：里程碑 D 把无人调用的
      `_downloadAllImages` 当死代码删了，现在只有画廊里的单张下载。
      要做的话需要串行任务 + 只弹一次保存框

## 需要先解决前置条件

- [ ] **补 Xcode**，让 macOS 桌面端可构建 —— Web 端因 CORS 抓不到 RSS，
      桌面/移动端才是这个 App 的真实使用场景。
      `flutter doctor`：Xcode 安装不完整，**且 CocoaPods 未安装**（插件依赖它，两样都要）
- [ ] 补 Android SDK，验证 Android 构建（`flutter doctor`：Unable to locate Android SDK）
- [ ] 为 Web 端引入 CORS 代理层（否则 Web 只能作为 UI 演示）

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
      无法注入）
- [ ] 清理 `pubspec.yaml` 里已无引用的依赖（`cached_network_image`，`lib/` 下只剩一条注释提到它）
- [ ] 把 `tool/e2e_fixture/` 接进自动化测试（见其 README 末尾）——卡在上面那条 Dio seam
- [ ] CI：analyze + test + build web（仓库目前没有 `.github/workflows`）

---

## 本轮核对：已不成立的旧条目

| 旧条目 | 现状（2026-09-16） |
|---|---|
| 死代码：`storage_service.clearOldArticles` | 方法已不存在 |
| 死代码：`responsive_layout` 的「断点枚举」 | `ResponsiveBreakpoint` 正被 `ResponsiveLayout` 使用，只有在它自己的文件里被引用；死的只有 `isWideScreen` |
| 移除 `article_detail_screen.dart` 的 `ignore_for_file: use_build_context_synchronously` | 该 ignore 已不在文件里；改为修 3 条真实警告（并入「进行中」） |
| 批量下载图片「每张弹一次保存框」 | 入口已随里程碑 D 删除，是「无此功能」而非「行为不对」（并入「进行中」） |
| known-issues 2.6 提到的 `WillPopScope` | 代码里已全部是 `PopScope` |

---

## 已完成的里程碑

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