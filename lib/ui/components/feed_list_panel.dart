import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/feed.dart';
import '../../services/storage_service.dart';
import 'add_feed_dialog.dart';
import 'edit_feed_dialog.dart';
import 'feed_list_tile.dart';

/// 订阅源列表面板：表头 + 列表 + 新增按钮 + 空状态。
///
/// 删除、置顶、重命名都在这里闭环处理（含确认与提示），调用方只需要
/// 关心「选中了哪个订阅源」这一件事。
///
/// 数据来自 [StorageService]，它变化时本面板会自动重建，因此调用方
/// 不需要在增删改之后手工刷新它。
class FeedListPanel extends StatelessWidget {
  /// 用户选中某个订阅源
  final ValueChanged<Feed> onFeedSelected;

  const FeedListPanel({super.key, required this.onFeedSelected});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StorageService>();
    final feeds = store.feeds;

    return Stack(
      children: [
        Column(
          children: [
            _FeedListHeader(count: feeds.length),
            Expanded(
              child: feeds.isEmpty
                  ? const _EmptyFeeds()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 88),
                      itemCount: feeds.length,
                      itemBuilder: (context, index) {
                        final feed = feeds[index];
                        return FeedListTile(
                          feed: feed,
                          unreadCount: store.unreadCountOf(feed.id),
                          onTap: () => onFeedSelected(feed),
                          onDelete: () => _confirmDelete(context, feed),
                          onTogglePin: () => _togglePin(context, feed),
                          onEdit: () => _rename(context, feed),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            onPressed: () => _addFeed(context),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _addFeed(BuildContext context) async {
    final store = context.read<StorageService>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AddFeedDialog(
        existingUrls: store.feeds.map((f) => f.url).toList(),
        // 对话框只负责拿到数据，落库交给这里，避免重复请求同一份 feed
        onAdd: (feed) => store.addFeed(feed),
      ),
    );
  }

  Future<void> _rename(BuildContext context, Feed feed) async {
    final store = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);
    String? savedName;

    await showDialog<void>(
      context: context,
      builder: (ctx) => EditFeedDialog(
        feed: feed,
        onSave: (newName) async {
          savedName = newName;
          await store.updateFeed(feed.copyWith(customName: newName));
        },
      ),
    );

    if (savedName != null) {
      messenger.showSnackBar(_snack('已更新名称为 "$savedName"'));
    }
  }

  Future<void> _togglePin(BuildContext context, Feed feed) async {
    final store = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);

    await store.updateFeed(feed.copyWith(isPinned: !feed.isPinned));
    messenger.showSnackBar(
      _snack(feed.isPinned
          ? '已取消置顶 "${feed.title}"'
          : '已置顶 "${feed.title}"'),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Feed feed) async {
    final store = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订阅源'),
        content: Text('确定要删除 "${feed.displayTitle}" 吗？\n关联的文章也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await store.deleteFeed(feed.id);
    messenger.showSnackBar(_snack('已删除 "${feed.displayTitle}"'));
  }

  static SnackBar _snack(String text) => SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

/// 改名对话框保存后无法直接知道新名字是否有效，这里做一次兜底判断。
bool newNameIsEmpty(String? name) => name == null || name.isEmpty;

class _FeedListHeader extends StatelessWidget {
  final int count;

  const _FeedListHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
          Text(
            '订阅源',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary,
                  theme.colorScheme.secondary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeeds extends StatelessWidget {
  const _EmptyFeeds();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.6),
                    theme.colorScheme.secondary.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.rss_feed,
                size: 34,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '暂无订阅源',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加你的第一个 RSS 订阅源，开始阅读',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openAddDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加订阅源'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final store = context.read<StorageService>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AddFeedDialog(
        existingUrls: store.feeds.map((f) => f.url).toList(),
        onAdd: (feed) => store.addFeed(feed),
      ),
    );
  }
}