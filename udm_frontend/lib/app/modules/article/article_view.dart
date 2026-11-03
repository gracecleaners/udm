import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/article.dart';
import '../reader/reading_progress.dart';
import 'article_controller.dart';

class ArticleView extends GetView<ArticleController> {
  const ArticleView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Obx(
            () => Text(
              controller.article.value?.category.isNotEmpty == true
                  ? controller.article.value!.category
                  : 'Reading',
            ),
          ),
        ),
        body: Obx(() => StateView(
              state: controller.state.value,
              failureMessage: controller.failureMessage.value,
              onRetry: controller.load,
              emptyTitle: 'Article unavailable',
              emptyMessage: 'This article is no longer published.',
              child: controller.article.value == null
                  ? const SizedBox.shrink()
                  : _ArticleBody(article: controller.article.value!, controller: controller),
            )),
      );
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({required this.article, required this.controller});

  final Article article;
  final ArticleController controller;

  static String _isoDate(DateTime moment) =>
      '${moment.year}-${moment.month.toString().padLeft(2, '0')}-${moment.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = article.body.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
      children: [
        Text(article.title, style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          [
            if (article.author.isNotEmpty) article.author,
            '${article.readingMinutes} min read',
            if (article.publishAt != null) _isoDate(article.publishAt!.toLocal()),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (article.excerpt.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.extension<AppSurfaces>()!.scripture,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: Text(
              article.excerpt,
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              paragraph.trim(),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}
