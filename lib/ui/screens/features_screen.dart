import 'package:flutter/material.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  final features = const [
    {
      'icon': Icons.rss_feed,
      'iconColor': Color(0xFFFFA726),
      'title': 'RSS/Atom 订阅',
      'description': '支持标准 RSS 2.0 和 Atom 格式订阅源，自动解析各种日期格式',
    },
    {
      'icon': Icons.view_list,
      'iconColor': Color(0xFF66BB6A),
      'title': '文章列表管理',
      'description': '卡片式文章列表，支持未读标记、收藏、置顶分组，显示发布时间和拉取时间',
    },
    {
      'icon': Icons.open_in_new,
      'iconColor': Color(0xFF42A5F5),
      'title': '全文抓取',
      'description': '自动抓取文章全文内容，提取正文图片，支持图片预览和缩放',
    },
    {
      'icon': Icons.dark_mode,
      'iconColor': Color(0xFFAB47BC),
      'title': '主题切换',
      'description': '支持浅色/深色/系统自动三种模式，Material 3 设计语言',
    },
    {
      'icon': Icons.backup,
      'iconColor': Color(0xFF26A69A),
      'title': '数据备份',
      'description': '一键备份订阅源和文章数据到本地文件，支持导入恢复',
    },
    {
      'icon': Icons.devices,
      'iconColor': Color(0xFFEF5350),
      'title': '跨平台支持',
      'description': '支持 iOS、Android、macOS、Windows、Linux、Web 多平台',
    },
    {
      'icon': Icons.drag_indicator,
      'iconColor': Color(0xFFFF7043),
      'title': '可调侧边栏',
      'description': '桌面端支持拖动调整订阅源列表宽度，最小 200px，最大 450px',
    },
    {
      'icon': Icons.link,
      'iconColor': Color(0xFF8D6E63),
      'title': '右键菜单',
      'description': '支持长按/右键菜单，可复制链接、重命名、删除订阅源',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '功能介绍',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部介绍
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.rss_feed,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RSS Reader',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '跨平台 RSS/Atom 阅读器',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '一款简洁高效的 RSS 订阅阅读器，支持多平台使用。添加订阅源后自动抓取文章列表，支持全文阅读、收藏、备份等功能。',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 功能列表
              Text(
                '主要功能',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ...features.map((feature) => _buildFeatureCard(context, feature)),
              const SizedBox(height: 24),
              // 快捷操作
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: theme.colorScheme.secondary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '快速上手',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTip(context, '点击右下角 "+" 按钮添加订阅源'),
                    _buildTip(context, '点击订阅源进入文章列表'),
                    _buildTip(context, '点击文章查看详细内容'),
                    _buildTip(context, '长按/右键可复制链接、重命名或删除'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, Map<String, dynamic> feature) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (feature['iconColor'] as Color).withValues(alpha: 0.9),
                  (feature['iconColor'] as Color).withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['title'] as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature['description'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
