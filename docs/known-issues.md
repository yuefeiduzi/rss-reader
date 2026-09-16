# 已核实的问题与技术债

本文件记录**经过源码核实或实测验证**的问题，每条都附证据。避免记录「听说有问题」这类未验证内容。

最后核对：2026-09-16

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
| Web 无法抓取 RSS | CORS 预检架构限制，需要代理层。**不是可以改代码绕过的 bug** |
| Web 备份不可用 | `dart:io` + `path_provider` 在 Web 抛 `UnsupportedError` |
| macOS / iOS / Android 未验证 | 缺少 Xcode 与 Android SDK |

### 2.6 规范

- `analysis_options.yaml` 里 `deprecated_member_use: ignore` 掩盖了一批存量：`WillPopScope`（`settings_screen.dart`）、`MaterialStateTextStyle`、`ColorScheme.background/surfaceVariant`
- `article_detail_screen.dart` 顶部 `// ignore_for_file: use_build_context_synchronously` 全局压制了正在发生的 async-gap 问题
- `ResponsiveLayout` 只在首页使用，与「统一用它做宽屏适配」的约定不符

---

## 三、如何复现验证

本地 Web 验证需要一个带 CORS 的测试源（真实 RSS 服务器都不发 CORS 头）：

```bash
# 1. 构建并托管应用
flutter build web --release
cd build/web && python3 -m http.server 8099

# 2. 起一个带 CORS 头的静态服务器，内含 feed.xml / 文章页 / 图片
#    然后在应用里添加 http://127.0.0.1:8100/feed.xml
```

用固定装置（fixture）验证的好处：可以精确控制 RSS 内容，从而覆盖 `dc:date`、
懒加载图片、相对路径、短摘要触发全文抓取等边界情况。

### 两个踩过的坑

1. **fixture 必须发 `Cache-Control: no-store`。** 否则浏览器会按启发式规则缓存
   响应：改了 `feed.xml` 之后应用仍在拿旧内容，会误判成解析 bug。
   （判断方法：看服务器日志里到底有没有收到请求。）
2. **验证 id 冲突之类的问题时，别用「同路径 + 不同 query」来造第二个源。**
   修好之前这恰好会撞成同一个 id，反而验证不了想看的东西；换个真实路径。

### 断言未读标记前先查 `isRead`

界面上「没有未读徽标」可能只是因为那篇确实已读。先读一次本地存储确认状态，
再下结论。