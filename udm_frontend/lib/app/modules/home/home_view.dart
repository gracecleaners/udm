import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/article.dart';
import '../../data/models/home_payload.dart';
import '../../data/models/resource_topic.dart';
import '../session/session_controller.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => Obx(
        () => StateView(
          state: controller.state.value,
          failureMessage: controller.failureMessage.value,
          onRetry: controller.load,
          emptyTitle: 'Nothing published yet',
          emptyMessage: 'Once the ministry team publishes a devotion or article it shows up here.',
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
              children: [
                _BrandRow(offline: controller.isOfflineCopy),
                const SizedBox(height: AppSpacing.sm),
                _Hero(payload: controller.data),
                const SizedBox(height: AppSpacing.lg),
                if (controller.data?.memoryVerse != null)
                  FadeIn(
                    delay: const Duration(milliseconds: 80),
                    child: Obx(() => ScripturePanel(
                      reference: controller.data!.memoryVerse!.reference,
                      text: controller.data!.memoryVerse!.text,
                      translationCode: controller.data!.memoryVerse!.translationCode,
                      offline: controller.isOfflineCopy,
                      ctaLabel: controller.data!.devotion == null ? null : "Open today's devotion",
                      onTap: controller.data!.devotion == null
                          ? null
                          : () => controller.openDevotion(controller.data!.devotion!.id),
                      onReview: () => controller.markMemorized(),
                      memorized: controller.verseMemorized,
                      savingReview: controller.savingVerse.value,
                    )),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  eyebrow: 'For your walk today',
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
                const SectionHeader(eyebrow: 'Deepen', title: 'Latest reading'),
                const SizedBox(height: AppSpacing.md),
                ...?controller.data?.articles.map(
                  (article) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ContentCard(
                      icon: Icons.article_rounded,
                      title: article.title,
                      subtitle: _byline(article),
                      trailingLabel: '${article.readingMinutes} min',
                      onTap: () => controller.openArticle(article.id),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (controller.data?.resources.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    eyebrow: 'Guided reading',
                    title: 'Find resources on',
                    subtitle: 'Short guides for the questions students actually ask',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...controller.data!.resources.map(
                    (topic) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ResourceRow(
                        topic: topic,
                        onOpen: () => controller.openTopic(topic.id),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const _SignInNudge(),
              ],
            ),
          ),
        ),
      );

  static String _byline(Article article) {
    final parts = [
      if (article.author.isNotEmpty) article.author,
      if (article.category.isNotEmpty) article.category,
    ];
    return parts.isEmpty ? 'UDM' : parts.join(' · ');
  }
}

/// One row of the "Find resources on" list. The row is the guide's own name,
/// not a generic button, because the ministry writes the list and reorders it
/// without an app release.
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.topic, required this.onOpen});

  final ResourceTopic topic;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconTile,
            height: AppSpacing.iconTile,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
              boxShadow: AppShadows.glow(AppColors.primaryBlue),
            ),
            child: AppText(
              topic.monogram,
              style: theme.textTheme.titleSmall?.copyWith(color: AppColors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  topic.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                AppText(
                  '${topic.stepCount} steps',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary, size: 22),
        ],
      ),
    );
  }
}

/// Signing in has to be reachable where the student actually reads, not only
/// from the Profile tab. It sits under the day's content, so the feed is never
/// gated: spec asks that public content stays browsable without an account.
class _SignInNudge extends GetView<SessionController> {
  const _SignInNudge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => controller.isSignedIn
          ? const SizedBox.shrink()
          : Panel(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(icon: Icons.volunteer_activism_rounded, size: 40, tone: IconBadgeTone.gold),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText('Keep your reading history', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 3),
                            AppText(
                              'Sign in to save what you have finished, your progress and your details on your own account.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    key: const Key('udm.homeSignIn'),
                    onPressed: () => Get.toNamed(AppRoutes.signIn),
                    child: const AppText('Sign in'),
                  ),
                  TextButton(
                    onPressed: () => Get.toNamed(AppRoutes.register),
                    child: const AppText('Create an account'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const UdmLogo(size: 42, tagline: 'University Discipleship Mission'),
          const Spacer(),
          if (offline) const OfflineChip(),
        ],
      );
}

/// The greeting comes from the API, so the header is server-driven content in a
/// brand shell rather than a hardcoded banner.
class _Hero extends StatelessWidget {
  const _Hero({required this.payload});

  final HomePayload? payload;

  @override
  Widget build(BuildContext context) {
    final devotion = payload?.devotion;
    final readings = payload?.articles.length ?? 0;
    return HeroPanel(
      eyebrow: payload?.greeting.isNotEmpty == true ? payload!.greeting : 'Peace be with you',
      title: 'Grow in His Word.',
      subtitle: 'Scripture, devotion and teaching for this day at your campus.',
      trailing: const Mark(size: 46, icon: Icons.self_improvement_rounded),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (devotion != null)
              MetaPill(
                label: 'Devotion · ${devotion.readingMinutes} min',
                icon: Icons.wb_sunny_rounded,
                onDark: true,
              ),
            if (readings > 0)
              MetaPill(label: '$readings readings today', icon: Icons.local_library_rounded, onDark: true),
          ],
        ),
      ],
    );
  }
}
