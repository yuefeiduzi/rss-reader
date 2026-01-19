# rss_reader - 跨平台 RSS 阅读器

一个功能完整的跨平台 RSS/Atom 阅读器应用，支持 iOS、Android、macOS、Windows、Linux 和 Web。

## 功能特性

### 订阅源管理
- 添加/删除 RSS/Atom 订阅源
- 预设热门订阅源（Hacker News、Dribbble、The Verge 等）
- 订阅源置顶功能
- 未读文章计数显示

### 文章阅读
- 卡片式布局展示
- 未读/已读状态标记
- 收藏功能
- 下拉刷新 + 缓存刷新
- 图片懒加载

### 文章详情
- 全文 HTML 渲染
- 图片预览（支持缩放）
- 外部浏览器打开
- 分享功能

### 主题系统
- 浅色/暗色/跟随系统三种模式
- Material 3 设计语言

### 响应式布局
- 移动端：单页导航
- 桌面端：分栏布局（左侧订阅源，右侧文章列表/详情）

### 数据管理
- SharedPreferences 持久化存储
- 30天过期文章自动清理
- 7天缓存过期管理

### 备份恢复
- JSON 完整备份
- OPML 订阅源导出（兼容其他阅读器）
- 备份文件管理

### 全文抓取
- 智能内容提取
- 广告过滤
- HTML 实体解码

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.10.0+ |
| SDK | Dart 3.0.0 - 4.0.0 |
| 状态管理 | Provider 6.0.5 |

**主要依赖：**
- `webfeed` - RSS/Atom 解析
- `dio` - HTTP 请求
- `html` - HTML 解析
- `shared_preferences` - 本地存储
- `cached_network_image` - 图片缓存
- `flutter_html` - HTML 渲染
- `url_launcher` - 外部链接
- `share_plus` - 分享功能

## 项目结构

```
lib/
├── main.dart                      # 应用入口
├── models/
│   ├── article.dart               # 文章数据模型
│   ├── feed.dart                  # 订阅源数据模型
│   └── config.dart                # 配置数据模型
├── services/
│   ├── rss_service.dart           # RSS/Atom 解析服务
│   ├── storage_service.dart       # 本地存储服务
│   ├── cache_service.dart         # 缓存管理服务
│   ├── theme_service.dart         # 主题管理服务
│   └── backup_service.dart        # 备份恢复服务
└── ui/
    ├── screens/
    │   ├── home_screen.dart       # 首页
    │   ├── article_list_screen.dart   # 文章列表页
    │   ├── article_detail_screen.dart # 文章详情页
    │   └── settings_screen.dart   # 设置页
    └── components/
        ├── add_feed_dialog.dart   # 添加订阅源对话框
        ├── feed_list_tile.dart    # 订阅源列表项
        └── responsive_layout.dart # 响应式布局组件
```

## 快速开始

### 环境要求
- Flutter 3.10.0+
- Dart 3.0.0+

### 安装依赖

```bash
flutter pub get
```

### 运行项目

```bash
flutter run
```

### 构建发布

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

## 配置

### 代码规范

项目使用以下 lint 规则：
- `prefer_const_constructors`
- `prefer_const_declarations`
- `avoid_print`

## 许可证

MIT License
