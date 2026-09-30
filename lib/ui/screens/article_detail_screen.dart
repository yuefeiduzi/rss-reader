import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/article.dart';
import '../../services/cache_service.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../../utils/date_format.dart';
import '../../utils/download_names.dart';
import '../../utils/html_content.dart';
import '../components/html_content_view.dart';
import '../components/image_gallery.dart';

/// 文章详情。
///
/// 不自带 Scaffold / AppBar：标题栏由 [HomeScreen] 统一提供，本页只提供一条
/// 操作栏，否则窄屏会出现上下两条标题栏。
///
/// 收藏与已读状态直接读 [StorageService] 里的实时副本（按 id 查），
/// 不再本地维护一份 _isFavorite —— 那样两个副本会不一致。
class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  /// 正文抓取中
  bool _isLoading = true;

  /// 正在重新抓取全文
  bool _isRefreshing = false;

  String _fullContent = '';

  Article get _article => widget.article;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (mounted) setState(() => _isLoading = true);

    final cache = context.read<CacheService>();
    final rss = context.read<RssService>();

    // 优先级：已抓取的全文缓存 > 源正文 > 摘要
    _fullContent = cache.getArticleContent(_article.id) ??
        _article.content ??
        _article.summary ??
        '';

    debugPrint('[加载缓存] 加载文章内容: ${_article.title}');

    if (_fullContent.isEmpty || _fullContent.length < 200) {
      try {
        debugPrint('[动作] 抓取文章全文: ${_article.link}');
        _fullContent = await rss.fetchFullContent(_article.link);
        await cache.cacheArticleContent(_article.id, _fullContent);
        debugPrint('[成功] 全文抓取完成, 内容长度: ${_fullContent.length}');
      } catch (e) {
        debugPrint('[错误] 全文抓取失败: $e');
      }
    }

    // 相对图片地址必须按文章链接补全：否则渲染引擎会相对应用自身的
    // 域名去取图，博客站常见的 /images/a.jpg 全部 404。
    _fullContent = absolutizeImageUrls(_fullContent, _article.link);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final cache = context.read<CacheService>();
    final rss = context.read<RssService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('[动作] 强制刷新文章全文: ${_article.link}');
      final newContent = absolutizeImageUrls(
        await rss.fetchFullContent(_article.link),
        _article.link,
      );
      if (!mounted) return;

      setState(() => _fullContent = newContent);
      await cache.cacheArticleContent(_article.id, newContent);
      debugPrint('[成功] 强制刷新成功, 内容长度: ${newContent.length}');
      messenger.showSnackBar(const SnackBar(content: Text('内容已更新')));
    } catch (e) {
      debugPrint('[错误] 强制刷新失败: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('内容已失效，无法获取新内容')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _toggleFavorite() {
    context.read<StorageService>().toggleFavorite(_article.id);
  }

  Future<void> _openInBrowser() => _openLinkInBrowser(_article.link);

  Future<void> _shareArticle() async {
    await Share.share(
      '${_article.title}\n\n${_article.link}\n\n分享自 RSS Reader',
      subject: _article.title,
    );
  }

  Future<void> _openLinkInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开链接')),
      );
    }
  }

  /// 批量下载正文里的图片：只弹一次目录选择框，然后串行下载。
  ///
  /// 串行是为了能汇报进度、也不至于把图片服务器打崩；
  /// 只弹一次则是因为早先的实现是每张图各弹一次保存框（见 known-issues 2.3）。
  /// 同名文件会直接覆盖（单张保存那条路由系统对话框负责提醒）。
  Future<void> _downloadAllImages(List<String> images) async {
    if (images.isEmpty) return;

    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择保存位置（共 ${images.length} 张）',
    );
    if (directory == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final dio = Dio();
    final names = uniqueFileNamesFor(images);
    var saved = 0;
    final failed = <String>[];

    for (var i = 0; i < images.length; i++) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('正在下载图片 ${i + 1}/${images.length}…'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(minutes: 1),
      ));

      try {
        await dio.download(images[i], '$directory/${names[i]}');
        saved++;
      } catch (e) {
        debugPrint('[下载] 失败 ${images[i]}: $e');
        failed.add(images[i]);
      }
    }

    messenger.removeCurrentSnackBar();
    if (!mounted) return;

    _showToast(
      context,
      failed.isEmpty
          ? '已保存 $saved 张图片到 $directory'
          : '已保存 $saved 张，${failed.length} 张失败',
    );
  }

  Future<void> _downloadImage(BuildContext context, String url) async {
    try {
      final fileName = url.substring(url.lastIndexOf('/') + 1).split('?')[0];
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存图片',
        fileName: fileName,
      );

      if (result == null) return;

      await Dio().download(url, result);

      if (!context.mounted) return;

      _showToast(
        context,
        '图片已保存到: $result',
        actionLabel: '分享',
        onAction: () async {
          await Share.shareXFiles([XFile(result)]);
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      _showToast(context, '下载失败');
    }
  }

  void _showToast(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 80,
        left: 20,
        right: 20,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<StorageService>();

    // 实时副本：收藏与已读状态以仓库为准，避免本地副本与真相不一致
    final article = store.articleById(widget.article.id) ?? widget.article;
    final feed = store.feedById(article.feedId);
    final images = extractImageUrls(_fullContent);

    return Column(
      children: [
        _DetailActionBar(
          feedTitle: feed?.displayTitle,
          isFavorite: article.isFavorite,
          isRefreshing: _isRefreshing,
          imageCount: images.length,
          onRefresh: _forceRefresh,
          onToggleFavorite: _toggleFavorite,
          onOpenInBrowser: _openInBrowser,
          onShare: _shareArticle,
          onDownloadAllImages: () => _downloadAllImages(images),
        ),
        Expanded(
          child: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (article.author != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  article.author!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            _MetaRow(
                              publishedAt: article.pubDate,
                              fetchedAt: article.cachedAt,
                            ),
                            const Divider(height: 24),
                            ErrorBoundary(
                              content: _fullContent,
                              link: article.link,
                              onOpenInBrowser: _openInBrowser,
                              onTapLink: (_) => _openInBrowser(),
                              onTapImage: (url) {
                                final index = images.indexOf(url);
                                _showImageGallery(
                                    context, images, index < 0 ? 0 : index);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              // 「看大图」入口。没有 Scaffold 可挂 FAB，直接叠在右下角。
              if (images.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: () => _showImageGallery(context, images, 0),
                    icon: const Icon(Icons.image),
                    label: const Text('看大图'),
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示图片画廊
  void _showImageGallery(BuildContext context, List<String> images, int initialIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ImageGallery(
          images: images,
          initialIndex: initialIndex,
          onDownload: (url) => _downloadImage(context, url),
          onOpenInBrowser: (url) => _openLinkInBrowser(url),
          onCopyUrl: (url) => _copyImageUrl(url),
          onShare: (url) => _shareImage(url),
        );
      },
    );
  }

  /// 复制图片链接
  void _copyImageUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接已复制到剪贴板')),
      );
    }
  }

  /// 分享图片链接
  Future<void> _shareImage(String url) async {
    await Share.share(url, subject: '分享图片');
  }
}

/// 详情页顶部操作栏：左侧订阅源名，右侧刷新 / 收藏 / 浏览器打开 / 分享。
///
/// 用一条普通横栏代替 AppBar，是为了让整页只有一条标题栏。
class _DetailActionBar extends StatelessWidget {
  final String? feedTitle;
  final bool isFavorite;
  final bool isRefreshing;
  final int imageCount;
  final VoidCallback onRefresh;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onShare;
  final VoidCallback onDownloadAllImages;

  const _DetailActionBar({
    required this.feedTitle,
    required this.isFavorite,
    required this.isRefreshing,
    required this.imageCount,
    required this.onRefresh,
    required this.onToggleFavorite,
    required this.onOpenInBrowser,
    required this.onShare,
    required this.onDownloadAllImages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              feedTitle ?? '文章',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onRefresh,
              tooltip: '重新抓取全文',
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined, size: 20),
            onPressed: imageCount > 0 ? onDownloadAllImages : null,
            tooltip: '下载全部图片',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: isFavorite ? theme.colorScheme.error : null,
            ),
            onPressed: onToggleFavorite,
            tooltip: isFavorite ? '取消收藏' : '收藏',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 20),
            onPressed: onOpenInBrowser,
            tooltip: '在浏览器中打开原文',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: onShare,
            tooltip: '分享',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// 发布时间与抓取时间
class _MetaRow extends StatelessWidget {
  final DateTime publishedAt;
  final DateTime fetchedAt;

  const _MetaRow({required this.publishedAt, required this.fetchedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Icon(Icons.rss_feed, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(formatDateTime(publishedAt), style: muted),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline,
            shape: BoxShape.circle,
          ),
        ),
        Icon(Icons.download_done, size: 12, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          formatDateTime(fetchedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// 正文渲染的失败兜底：引擎构建整篇 HTML 失败时切到纯文本降级视图。
///
/// 错误信号来自 [HtmlContentView.onRenderError]，且只对「整篇构建失败」置位 ——
/// 单张图片加载失败不会把文章换成降级视图。
class ErrorBoundary extends StatefulWidget {
  final String content;
  final String link;
  final VoidCallback onOpenInBrowser;
  final void Function(String url)? onTapLink;
  final void Function(String url)? onTapImage;

  const ErrorBoundary({
    super.key,
    required this.content,
    required this.link,
    required this.onOpenInBrowser,
    this.onTapLink,
    this.onTapImage,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;

  @override
  void didUpdateWidget(covariant ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了正文（重新抓取 / 切文章）就再给渲染引擎一次机会
    if (oldWidget.content != widget.content) {
      _hasError = false;
    }
  }

  /// 引擎构建整篇正文失败时调用。它发生在 build 期间，不能同步 setState，
  /// 所以隔一帧再切到降级 UI。
  void _markRenderFailed() {
    if (_hasError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasError) setState(() => _hasError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return HtmlRenderFallback(
        content: widget.content,
        onOpenInBrowser: widget.onOpenInBrowser,
      );
    }

    // 正常渲染
    return SelectionArea(
      child: HtmlContentView(
        html: widget.content,
        link: widget.link,
        onTapLink: widget.onTapLink,
        onTapImage: widget.onTapImage,
        onRenderError: _markRenderFailed,
      ),
    );
  }
}
