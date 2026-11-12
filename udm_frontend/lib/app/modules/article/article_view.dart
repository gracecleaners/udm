import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/article.dart';
import '../reader/reading_progress.dart';
import 'article_controller.dart';

class ArticleView extends GetView<ArticleController> {
  const ArticleView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Obx(
            () => AppText(
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
    final bodyColor = theme.textTheme.bodyLarge!.color!;
    final paragraphs = article.body.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
      children: [
        AppText(article.title, style: theme.textTheme.displayMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (article.author.isNotEmpty)
              MetaPill(icon: Icons.person_outline_rounded, label: article.author),
            MetaPill(icon: Icons.schedule_rounded, label: '${article.readingMinutes} min read'),
            if (article.publishAt != null)
              MetaPill(
                icon: Icons.calendar_today_rounded,
                label: _isoDate(article.publishAt!.toLocal()),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const GoldRule(width: 72),
        if (article.excerpt.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppGradients.hero,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppText(
                    article.excerpt,
                    style: AppTypography.scriptureVerse(bodyColor, size: 17).copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ...paragraphs.indexed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppText(
              entry.$2.trim(),
              // The opening paragraph runs a touch larger, the way a printed
              // feature leads in.
              style: entry.$1 == 0
                  ? AppTypography.scriptureBody(bodyColor).copyWith(fontSize: 19.5)
                  : AppTypography.scriptureBody(bodyColor),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}
