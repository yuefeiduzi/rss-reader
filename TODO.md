# 待办

详细的已核实问题与技术债见 [docs/known-issues.md](docs/known-issues.md)。本文件只放**路线图**。

最后更新：2026-09-16

---

## 进行中

- [ ] 删除剩余死代码（清单见 [known-issues 2.4](docs/known-issues.md)）
- [ ] 批量下载图片：目前会每张弹一次保存框，应改为串行任务
- [ ] 渲染异常降级为纯文本：`_hasError` 分支已写好但永远不会触发

## 需要先解决前置条件

- [ ] **补 Xcode**，让 macOS 桌面端可构建 —— Web 端因 CORS 抓不到 RSS，
      桌面/移动端才是这个 App 的真实使用场景
- [ ] 补 Android SDK，验证 Android 构建
- [ ] 为 Web 端引入 CORS 代理层（否则 Web 只能作为 UI 演示）

## 架构改进

- [ ] 存储层改造：每次写入都会重新序列化全部文章，Web 的 localStorage 有 ~5MB 上限。
      考虑改用对象存储（Hive / Isar / sqlite）或按 feed 分片
- [ ] `theme_service.dart` 的两份重复 ThemeData 收敛为共享 builder
- [ ] 清理 `analysis_options.yaml` 的 `deprecated_member_use: ignore`，
      逐个修掉 `MaterialStateTextStyle` / `ColorScheme.background`
- [ ] 移除 `article_detail_screen.dart` 的 `ignore_for_file: use_build_context_synchronously`

## 功能

- [ ] 国际化：目前中英混排（左侧栏中文、设置页与空状态英文），且无日期本地化
- [ ] 订阅源分组
- [ ] 搜索
- [ ] Web 端备份导出（改为浏览器下载）
- [ ] 正文图片缓存：曾尝试用 `cached_network_image` 接管，在 Web 上会渲染成黑块已回退。
      建议改用 fwfh 的 `customWidgetBuilder` 自行接管 `img` 元素（见 known-issues 2.4.1）

## 工程

- [ ] 补充更多 widget 测试（`StorageService` 的响应式行为已有覆盖）
- [ ] 为 `file_picker` / `share_plus` / `Clipboard` / `url_launcher` 引入接口 seam 以便 mock
- [ ] 清理 `pubspec.yaml` 里已无引用的依赖（`cached_network_image`）
- [ ] CI：analyze + test + build web
- [ ] 把本地 CORS fixture（`feed.xml` + 文章页 + 图片 + CORS 服务器）纳入仓库，
      作为端到端验证的可重复基础设施

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