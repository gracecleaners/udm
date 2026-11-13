import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/article.dart';
import '../../data/models/home_payload.dart';
import '../../data/models/resource_topic.dart';
import '../session/session_controller.dart';
import '../shell/shell_controller.dart';
import 'home_controller.dart';

/// The day's feed, in the order the ministry's payload supports it: a greeting,
/// the verse to keep, the devotion to read, the reading to deepen into, and the
/// guides that answer the questions students actually ask.
///
/// Every section here is server-gated. A section with nothing published is not
/// rendered as an empty shape, and a shortcut with nowhere to go is not
/// rendered at all.
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
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: _BrandRow(offline: controller.isOfflineCopy),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: _Hero(payload: controller.data),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: FadeIn(
                    delay: const Duration(milliseconds: 60),
                    child: QuickActionGrid(actions: _shortcuts(controller.data)),
                  ),
                ),
                if (controller.data?.memoryVerse != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: FadeIn(
                      delay: const Duration(milliseconds: 110),
                      child: Obx(
                        () => ScripturePanel(
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
                        ),
                      ),
                    ),
                  ),
                ],
                if (controller.data?.devotion != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  RailHeader(
                    eyebrow: 'For your walk today',
                    title: 'Today',
                    subtitle: 'Curated by the ministry team',
                  ),
                  FadeIn(
                    delay: const Duration(milliseconds: 60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: FeatureCard(
                        eyebrow: 'Devotion',
                        title: controller.data!.devotion!.title,
                        subtitle: controller.data!.devotion!.scriptureReference,
                        monogram: UdmAvatar.initialsFor(controller.data!.devotion!.title),
                        pills: [
                          MetaPill(
                            label: '${controller.data!.devotion!.readingMinutes} min',
                            icon: AppIcons.clock,
                            onDark: true,
                          ),
                        ],
                        onTap: () => controller.openDevotion(controller.data!.devotion!.id),
                      ),
                    ),
                  ),
                ],
                if (controller.data?.articles.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const RailHeader(eyebrow: 'Deepen', title: 'Latest reading'),
                  DiscoveryRail(
                    children: controller.data!.articles
                        .map(
                          (article) => RailCard(
                            title: article.title,
                            subtitle: _byline(article),
                            monogram: UdmAvatar.initialsFor(article.title),
                            pill: MetaPill(label: '${article.readingMinutes} min', icon: AppIcons.clock),
                            onTap: () => controller.openArticle(article.id),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (controller.data?.resources.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const RailHeader(
                    eyebrow: 'Guided reading',
                    title: 'Find resources on',
                    subtitle: 'Short guides for the questions students actually ask',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: Column(
                      children: [
                        for (final topic in controller.data!.resources)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _ResourceRow(topic: topic, onOpen: () => controller.openTopic(topic.id)),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: const _SignInNudge(),
                ),
              ],
            ),
          ),
        ),
      );

  /// The four shortcuts a student reaches for from the feed. The last one is
  /// the ministry's own lead guide, so the strip changes with what staff
  /// publish instead of being a fixed set of buttons.
  List<QuickAction> _shortcuts(HomePayload? payload) {
    void go(int tab) => Get.find<ShellController>().select(tab);
    return [
      QuickAction(label: 'Bible', icon: AppIcons.bible, onTap: () => go(ShellController.bibleTab)),
      QuickAction(label: 'Devotions', icon: AppIcons.sun, onTap: () => go(ShellController.devotionsTab)),
      QuickAction(label: 'Learn', icon: AppIcons.learn, onTap: () => go(ShellController.learnTab)),
      if (payload != null && payload.resources.isNotEmpty)
        QuickAction(
          label: 'Guides',
          icon: AppIcons.steps,
          tone: IconBadgeTone.gold,
          onTap: () => controller.openTopic(payload.resources.first.id),
        ),
    ];
  }

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
                Row(
                  children: [
                    MetaPill(label: '${topic.stepCount} steps', icon: AppIcons.steps),
                    if (topic.summary.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppText(
                          topic.summary,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(AppIcons.chevron, color: theme.colorScheme.primary, size: 22),
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
    final surfaces = theme.extension<AppSurfaces>()!;
    return Obx(
      () => controller.isSignedIn
          ? const SizedBox.shrink()
          : Panel(
              gradient: AppGradients.tint(surfaces.scripture, theme.colorScheme.surface),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(icon: AppIcons.heart, size: 44, tone: IconBadgeTone.gold),
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
                  FilledButton.icon(
                    key: const Key('udm.homeSignIn'),
                    onPressed: () => Get.toNamed(AppRoutes.signIn),
                    icon: const Icon(AppIcons.person, size: 18),
                    label: const AppText('Sign in'),
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
          // A non-flex child of a Row is measured with unlimited width, so the
          // wordmark would run off a 320dp screen instead of ellipsizing.
          Expanded(
            child: UdmLogo(size: 42, tagline: 'University Discipleship Mission'),
          ),
          if (offline) ...[
            const SizedBox(width: AppSpacing.sm),
            const OfflineChip(),
          ],
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
      trailing: const Mark(size: 46, icon: AppIcons.bookOpen),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (devotion != null)
              MetaPill(
                label: 'Devotion · ${devotion.readingMinutes} min',
                icon: AppIcons.sun,
                onDark: true,
              ),
            if (readings > 0)
              MetaPill(label: '$readings readings today', icon: AppIcons.book, onDark: true),
          ],
        ),
      ],
    );
  }
}
