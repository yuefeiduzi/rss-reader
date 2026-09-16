import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/article.dart';
import '../../models/feed.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import '../components/feed_list_panel.dart';
import '../components/responsive_layout.dart';
import 'article_detail_screen.dart';
import 'article_list_screen.dart';
import 'settings_screen.dart';

/// 首页：窄屏单页导航，宽屏左右分栏。
///
/// 这里只持有**选中状态**（选中了哪个订阅源、哪篇文章）—— 那是纯粹
/// 的界面状态。数据本身来自 [StorageService]，它变化时本页会自动重建，
/// 因此不存在「增删改之后手工刷新列表」的代码。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Feed? _selectedFeed;
  Article? _selectedArticle;
  double _sidebarWidth = 280;
  final double _minSidebarWidth = 200;
  final double _maxSidebarWidth = 450;

  void _selectFeed(Feed feed) {
    setState(() {
      _selectedFeed = feed;
      _selectedArticle = null;
    });
  }

  void _selectArticle(Article article) {
    setState(() => _selectedArticle = article);
  }

  void _clearSelection() {
    setState(() {
      _selectedFeed = null;
      _selectedArticle = null;
    });
  }

  /// 宽屏下左侧面板宽度可能被拖动过，选中订阅源时保持当前宽度
  bool get _hasSelection => _selectedFeed != null || _selectedArticle != null;

  /// 右侧内容区。窄屏与宽屏共用，避免两处各写一遍同样的分支。
  Widget _buildContentPane() {
    if (_selectedArticle != null) {
      return ArticleDetailScreen(article: _selectedArticle!);
    }
    if (_selectedFeed != null) {
      return ArticleListScreen(
        key: ValueKey('feed-${_selectedFeed!.id}'),
        feed: _selectedFeed!,
        onArticleSelected: _selectArticle,
      );
    }
    return const _NothingSelected();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeService = context.watch<ThemeService>();

    return ResponsiveLayout(
      mobileLayout: _buildMobileLayout(themeService, isDark),
      wideScreenLayout: _buildWideScreenLayout(themeService, isDark),
    );
  }

  Widget _buildMobileLayout(ThemeService themeService, bool isDark) {
    return Scaffold(
      appBar: _buildAppBar(
        themeService: themeService,
        isDark: isDark,
        title: _selectedFeed?.displayTitle ?? 'RSS Reader',
        // 选中内容后提供返回，用于退回订阅源列表
        onBack: _hasSelection ? _clearSelection : null,
      ),
      body: _selectedFeed == null
          ? FeedListPanel(onFeedSelected: _selectFeed)
          : _buildContentPane(),
    );
  }

  Widget _buildWideScreenLayout(ThemeService themeService, bool isDark) {
    return Scaffold(
      appBar: _buildAppBar(
        themeService: themeService,
        isDark: isDark,
        title: 'RSS Reader',
      ),
      body: Row(
        children: [
          SizedBox(
            width: _sidebarWidth,
            child: FeedListPanel(onFeedSelected: _selectFeed),
          ),
          _buildResizableDivider(),
          Expanded(child: _buildContentPane()),
        ],
      ),
    );
  }

  /// 单层 AppBar。子页面（文章列表 / 详情）不再各自提供 Scaffold+AppBar，
  /// 否则窄屏会出现上下两条标题栏。
  PreferredSizeWidget _buildAppBar({
    required ThemeService themeService,
    required bool isDark,
    required String title,
    VoidCallback? onBack,
  }) {
    return AppBar(
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: false,
      leading: onBack == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
      actions: [
        IconButton(
          icon: Icon(_themeIcon(themeService, isDark)),
          onPressed: themeService.toggleDarkMode,
          tooltip: '切换主题',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size(double.infinity, 1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  IconData _themeIcon(ThemeService themeService, bool isDark) {
    if (isDark) return Icons.dark_mode;
    if (themeService.themeMode == ThemeMode.light) return Icons.light_mode;
    return Icons.brightness_6;
  }

  Widget _buildResizableDivider() {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sidebarWidth = (_sidebarWidth + details.delta.dx)
                .clamp(_minSidebarWidth, _maxSidebarWidth);
          });
        },
        child: Container(
          width: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 宽屏下未选择任何内容时的占位。
class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.secondary.withValues(alpha: 0.6),
                  theme.colorScheme.secondary.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.article,
              size: 40,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '选择一个订阅源开始阅读',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}