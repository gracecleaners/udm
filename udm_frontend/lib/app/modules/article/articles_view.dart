import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/article.dart';
import 'articles_controller.dart';

class ArticlesView extends GetView<ArticlesController> {
  const ArticlesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const AppText('Articles')),
      body: Obx(
        () => StateView(
          state: controller.state.value,
          failureMessage: controller.failureMessage.value,
          onRetry: controller.load,
          emptyTitle: 'No articles published yet',
          emptyMessage: 'New articles from the ministry will appear here.',
          emptyIcon: AppIcons.book,
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
              children: [
                Eyebrow('Read and reflect', color: theme.colorScheme.primary, icon: AppIcons.bookOpen),
                const SizedBox(height: AppSpacing.xs),
                AppText('Stories and teaching for everyday faith.', style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < controller.articles.length; i++) ...[
                  _ArticleTile(article: controller.articles[i], onTap: () => controller.open(controller.articles[i])),
                  if (i < controller.articles.length - 1) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverArt(
            url: article.imageUrl,
            monogram: UdmAvatar.initialsFor(article.title),
            width: double.infinity,
            height: 168,
            radius: AppSpacing.radiusCard,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Eyebrow(article.category.isEmpty ? 'Article' : article.category,
                      color: theme.colorScheme.primary)),
                  MetaPill(label: '${article.readingMinutes} min', icon: AppIcons.clock),
                ]),
                const SizedBox(height: AppSpacing.xs),
                AppText(article.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (article.preview.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AppText(article.preview, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: AppText(article.author.isEmpty ? 'UDM' : article.author,
                      style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (article.publishAt != null)
                    AppText(_date(article.publishAt!), style: theme.textTheme.labelSmall),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
