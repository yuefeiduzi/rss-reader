import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddFeedDialog extends StatefulWidget {
  final Function(String url) onAdd;

  const AddFeedDialog({super.key, required this.onAdd});

  @override
  State<AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<AddFeedDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // 预设的热门 RSS 源
  static const List<Map<String, String>> _presetFeeds = [
    {'title': 'Hacker News', 'url': 'https://news.ycombinator.com/rss'},
    {'title': 'Dribbble', 'url': 'https://dribbble.com/feed'},
    {'title': 'The Verge', 'url': 'https://www.theverge.com/rss/index.xml'},
    {'title': 'TechCrunch', 'url': 'https://techcrunch.com/feed/'},
    {'title': 'GitHub Blog', 'url': 'https://github.blog/feed/'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validateAndAdd() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入订阅源地址');
      return;
    }

    // 验证 URL 格式
    try {
      final uri = Uri.parse(url);
      if (!uri.isAbsolute) {
        setState(() => _error = '请输入有效的 URL 地址');
        return;
      }
      // 自动补全 http:// 前缀
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _controller.text = 'https://$url';
      }
    } catch (e) {
      setState(() => _error = 'URL 格式无效');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 重新获取补全后的 URL
      final finalUrl = _controller.text.trim();
      await widget.onAdd(finalUrl);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '添加订阅源失败: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectPreset(String url) {
    _controller.text = url;
    _validateAndAdd();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData != null && clipboardData.text != null) {
        _controller.text = clipboardData.text!;
        setState(() => _error = null);
      }
    } catch (e) {
      // 剪贴板访问失败，尝试使用快捷键提示
      debugPrint('Clipboard access failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.rss_feed,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Text('添加订阅源'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL 输入框
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '订阅源地址',
                hintText: 'https://example.com/feed.xml',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _error = null);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: '从剪贴板粘贴',
                      onPressed: _isLoading ? null : _pasteFromClipboard,
                    ),
                  ],
                ),
                filled: _error != null,
                fillColor: _error != null
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.3)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
              enabled: !_isLoading,
              onSubmitted: (_) => _validateAndAdd(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            // 错误提示
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 预设 RSS 源
            if (_error == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '快速添加',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presetFeeds.map((feed) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(feed['title']!),
                          onPressed: _isLoading
                              ? null
                              : () => _selectPreset(feed['url']!),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _validateAndAdd,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('添加'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
