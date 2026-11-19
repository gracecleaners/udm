import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/formatted_content.dart';
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
          // The category opens the page itself as an eyebrow, so the bar is
          // left with the way back.
          title: const SizedBox.shrink(),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
      children: [
        FeatureCard(
          eyebrow: article.category.isEmpty ? 'Article' : article.category,
          title: article.title,
          titleStyle: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontSize: 22,
            height: 1.18,
            fontWeight: FontWeight.w800,
          ),
          subtitle: article.author.isEmpty ? null : article.author,
          artUrl: article.imageUrl,
          monogram: UdmAvatar.initialsFor(article.title),
          height: 210,
          pills: [MetaPill(icon: AppIcons.clock, label: '${article.readingMinutes} min', onDark: true)],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (article.category.isNotEmpty) ...[
          AppText(article.category, style: AppTypography.eyebrow(theme.colorScheme.primary)),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppText(
          article.title,
          style: theme.textTheme.displaySmall?.copyWith(
            color: bodyColor,
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (article.author.isNotEmpty)
              MetaPill(icon: AppIcons.person, label: article.author),
            MetaPill(icon: AppIcons.clock, label: '${article.readingMinutes} min read'),
            if (article.publishAt != null)
              MetaPill(
                icon: AppIcons.calendar,
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
                  child: FormattedContent(
                    article.excerpt,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: bodyColor,
                      fontSize: 17,
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
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: FormattedContent(
            article.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: bodyColor,
              fontSize: 16.5,
              height: 1.72,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}
