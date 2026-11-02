import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/article.dart';
import '../../data/models/home_payload.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => Obx(() => StateView(
          state: controller.state.value,
          failureMessage: controller.failureMessage.value,
          onRetry: controller.load,
          emptyTitle: 'Nothing published yet',
          emptyMessage: 'Once the ministry team publishes a devotion or article it shows up here.',
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
              children: [
                _Header(payload: controller.data, offline: controller.isOfflineCopy),
                const SizedBox(height: AppSpacing.lg),
                if (controller.data?.verse != null)
                  ScripturePanel(
                    reference: controller.data!.verse!.reference,
                    text: controller.data!.verse!.text,
                    translationCode: controller.data!.verse!.translationCode,
                    offline: controller.isOfflineCopy,
                    onTap: controller.data!.devotion == null
                        ? null
                        : () => controller.openDevotion(controller.data!.devotion!.id),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Today',
                  subtitle: 'Curated by the ministry team',
                ),
                const SizedBox(height: AppSpacing.md),
                if (controller.data?.devotion != null)
                  ContentCard(
                    icon: Icons.wb_sunny_rounded,
                    title: controller.data!.devotion!.title,
                    subtitle: controller.data!.devotion!.scriptureReference,
                    trailingLabel: '${controller.data!.devotion!.readingMinutes} min',
                    onTap: () => controller.openDevotion(controller.data!.devotion!.id),
                  )
                else
                  const ContentCard(
                    icon: Icons.wb_sunny_rounded,
                    title: 'No devotion scheduled',
                    subtitle: 'Check back after the next publishing window.',
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Latest reading'),
                const SizedBox(height: AppSpacing.md),
                ...?controller.data?.articles.map((article) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ContentCard(
                        icon: Icons.article_rounded,
                        title: article.title,
                        subtitle: _byline(article),
                        trailingLabel: '${article.readingMinutes} min',
                        onTap: () => controller.openArticle(article.id),
                      ),
                    )),
              ],
            ),
          ),
        ));

  static String _byline(Article article) {
    final parts = [
      if (article.author.isNotEmpty) article.author,
      if (article.category.isNotEmpty) article.category,
    ];
    return parts.isEmpty ? 'UDM' : parts.join(' · ');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.payload, required this.offline});

  final HomePayload? payload;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const UdmLogo(size: 40),
            const Spacer(),
            if (offline) const OfflineChip(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          payload?.greeting.isNotEmpty == true ? payload!.greeting : 'Peace be with you',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: 2),
        Text('Grow in His Word.', style: theme.textTheme.displaySmall),
      ],
    );
  }
}
