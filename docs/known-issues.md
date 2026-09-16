# 已核实的问题与技术债

本文件记录**经过源码核实或实测验证**的问题，每条都附证据。避免记录「听说有问题」这类未验证内容。

最后核对：2026-09-16

---

## 一、已修复（保留记录以便回溯）

| 问题 | 根因 | 证据 |
|---|---|---|
| 全文抓取永远返回空串 | `_dio` 的 `BaseOptions` 设了 `ResponseType.bytes`，`response.data` 是 `Uint8List`，直接喂给 `html_parser.parse` 抛 TypeError，又被 `catch → return ''` 吞掉；空串还会被写进缓存 | 修复后实测日志 `全文抓取完成, 内容长度: 147` |
| 只有 `<updated>` 的 Atom 源解析崩溃 | `AtomItem.updated` 是 `DateTime?`、`published` 是 `String?`；代码写的是 `_parseDate(entry.published ?? entry.updated)`，把 DateTime 传进期望 String 的形参 | `test/rss_service_test.dart` 中的回归测试 |
| `dc:date` 未生效 | RSS 路径写的是 `item.pubDate ?? DateTime.now()`，而 webfeed 不会把 `dc:date` 填进 `pubDate` | 实测：`dc:date`-only 条目 `pubDate` 为 `null` |
| 正文相对图片 404 | 未按文章链接补全，`flutter_html` 相对应用自身域名解析 | 修复前 `GET /img.png` 打在应用端口 → 404；修复后打在文章域名 → 200 |
| 时间显示差 8 小时 | 两处 `_formatDateTime` 都漏了 `toLocal()` | 修复前 `2026-09-16 00:00`，修复后 `2026-09-16 08:00`（源为 `+0800`） |
| OPML 导入基本无法工作 | 导入正则要求 `xmlUrl` 紧跟 `text`，而导出与标准 OPML 都把 `xmlUrl` 放在最后 | `test/opml_test.dart` |
| 导入订阅源数量虚报 | 忽略 `addFeedWithDuplicateCheck` 的返回值，无条件自增 | — |
| `getAllArticles(limit)` 的 limit 失效 | 级联 `..take(limit)` 返回的是接收者，`take` 结果被丢弃 | — |
| 「跟随系统」主题重启后失效 | `init()` 用 `isDarkMode` 算 light/dark，无视 `followSystemTheme` | — |
| 裸域名输入被拒 | 先判 `Uri.isAbsolute`，`example.com/feed` 直接报错，后面的 https 补全是死代码 | `test/feed_url_test.dart` |
| 相对/懒加载头图失败 | 只取 `src`，不解析相对路径、不认 `data-src` | — |
| `getAllFeeds` 泄漏内部列表 | 返回内部可变列表，`home_screen` 在其上原地排序 | — |
| 批量导入 feed id 可能重复 | 用 `millisecondsSinceEpoch` 生成 id | — |
| `async void` 吞异常 | `_deleteFeed` / `_togglePinFeed` 声明为 `void ... async` | — |
| `backup_service` 备份文件列表永远为空 | 扫描 `<docs>/backup/*.json`，实际写入 `<docs>/backup_<时间戳>.zip` | — |
| `CupertinoPageTransitionsBuilder` 编译失败 | Flutter 3.47 起不再由 `material.dart` 导出（PR #179776） | `flutter analyze` |

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
| 窄屏双层标题栏 | `home_screen.dart` + `article_list_screen.dart` | 两处都提供 Scaffold + AppBar，嵌套后叠加 |
| 过度刷新 | `article_list_screen.dart` | **实测确认**：打开一篇文章返回后会触发整个订阅源的网络刷新 |
| 刷新竞态 | `article_list_screen.dart` | `_loadArticles` 与 `_forceRefresh` 两条路径都可能提前把 `_isRefreshing` 置 false |
| 添加订阅源重复请求 | `add_feed_dialog.dart` + `home_screen.dart` | 预览一次、提交一次、真正添加再一次，最坏 3 次网络请求 |
| 批量下载图片弹多个保存框 | `article_detail_screen.dart` | 循环调用 `_downloadImage`，每张图各弹一次文件选择器 |
| 未读徽标异常 | `article_list_screen.dart` | 实测观察到第一张卡片不显示未读徽标，第二张显示；未深究 |
| 存储层的写入放大 | `storage_service.dart` | 任何一次标记已读都会重新序列化**全部**文章；Web 的 localStorage 有 ~5MB 上限 |

### 2.4 死代码

以下均有代码、无调用者，建议删除或接线：

- `article_detail_screen.dart`：`_showImagePreview`（约 100 行，单图预览，已被画廊取代）、
  `_showImageContextMenu`（约 80 行）、`_hasError` 降级分支
- `cache_service.dart`：`cacheImage` / `getCachedImage`（图片 Base64 缓存）、`getCacheStats`
- `storage_service.dart`：`clearOldArticles`
- `backup_service.dart`：`getBackupFiles`、`importOpmlFromZip`
- `responsive_layout.dart`：`isWideScreen` 与断点枚举
- `pubspec.yaml`：`provider`、`cached_network_image`（正文用的是 `NetworkImage`，列表用 `Image.network`）

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

用固定装置（fixture）验证的好处：可以精确控制 RSS 内容，从而覆盖 `dc:date`、懒加载图片、相对路径、短摘要触发全文抓取等边界情况。