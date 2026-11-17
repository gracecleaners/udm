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
import '../../data/models/resume_item.dart';
import '../../data/models/resource_topic.dart';
import '../session/session_controller.dart';
import '../shell/shell_controller.dart';
import 'home_controller.dart';

/// The day's feed, in the order a student actually works through it: who is
/// greeting them, the verse to keep, where they left off, what today asks of
/// them, and the four doors they use most.
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
                const _Greeting(),
                const SizedBox(height: AppSpacing.lg),
                if (controller.data?.memoryVerse != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: FadeIn(
                      child: Obx(
                        () => ScripturePanel(
                          reference: controller.data!.memoryVerse!.reference,
                          text: controller.data!.memoryVerse!.text,
                          translationCode: controller.data!.memoryVerse!.translationCode,
                          artUrl: controller.data!.memoryVerse!.imageUrl,
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
                  const SizedBox(height: AppSpacing.xl),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (controller.resume.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: FadeIn(
                      delay: const Duration(milliseconds: 60),
                      child: _ContinueWatching(items: controller.resume.toList()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: FadeIn(
                    delay: const Duration(milliseconds: 90),
                    child: const _TodaysPlan(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  child: FadeIn(
                    delay: const Duration(milliseconds: 120),
                  child: QuickActionGrid(actions: _shortcuts()),
                  ),
                ),
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
                        artUrl: controller.data!.devotion!.imageUrl,
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
                            artUrl: article.imageUrl,
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
                    title: 'Courses',
                    subtitle: 'Short guides for the questions students actually ask',
                    onSeeAll: _openCourses,
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

  /// The four requested home doors. The five-tab navigation remains separate.
  List<QuickAction> _shortcuts() {
    void go(int tab) => Get.find<ShellController>().select(tab);
    return [
      QuickAction(label: 'Courses', icon: AppIcons.school, onTap: _openCourses),
      QuickAction(label: 'Articles', icon: AppIcons.book, onTap: () => Get.toNamed(AppRoutes.articles)),
      QuickAction(
        label: 'New Believer',
        icon: AppIcons.sparkles,
        onTap: () => Get.toNamed(AppRoutes.newBeliever),
      ),
      QuickAction(
        label: 'Media',
        icon: AppIcons.play,
        onTap: () => go(ShellController.learnTab),
      ),
    ];
  }

  /// Courses is a screen of its own, not a section of the feed, so both doors
  /// into it go to the same route.
  static void _openCourses() => Get.toNamed(AppRoutes.courses);

  static String _byline(Article article) {
    final parts = [
      if (article.author.isNotEmpty) article.author,
      if (article.category.isNotEmpty) article.category,
    ];
    return parts.isEmpty ? 'UDM' : parts.join(' · ');
  }
}

/// Greeting, name and the face that belongs to them. The sentence is the
/// server's, the name is the account's, and the avatar is the Profile tab: a
/// student who taps their own face expects to land on their own details.
class _Greeting extends GetView<HomeController> {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = Get.find<SessionController>();
    return Obx(() {
      final greeting = controller.data?.greeting;
      final profile = session.profile.value;
      final firstName = profile?.displayName.trim().split(RegExp(r'\s+')).first ?? '';
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    [
                      if (greeting != null && greeting.isNotEmpty) greeting else 'Peace be with you',
                      if (firstName.isNotEmpty) firstName,
                    ].join(', '),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (controller.isOfflineCopy) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const OfflineChip(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // A signed-out student has no face to show, so the door to sign in
            // takes the avatar's place instead of an invented silhouette.
            if (profile == null)
              GhostButton(
                key: const Key('udm.homeGreetingSignIn'),
                label: 'Sign in',
                icon: AppIcons.person,
                onTap: () => Get.toNamed(AppRoutes.signIn),
              )
            else
              PressableScale(
                onTap: () => Get.find<ShellController>().select(ShellController.profileTab),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: UdmAvatar(initials: profile.initials, size: 44),
              ),
          ],
        ),
      );
    });
  }
}

/// Where the student left off in the ministry's recordings. One card per
/// recording, each opening on the place the server says they stopped.
class _ContinueWatching extends StatelessWidget {
  const _ContinueWatching({required this.items});

  final List<ResumeItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                'Continue watching',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => Get.find<ShellController>().select(ShellController.learnTab),
              child: const AppText('See all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 216,
                child: Panel(
                  onTap: () => Get.toNamed(
                    AppRoutes.mediaItem,
                    arguments: {RouteArgs.mediaItemId: item.id},
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CoverArt(
                            url: item.imageUrl,
                            monogram: UdmAvatar.initialsFor(item.title),
                            icon: AppIcons.play,
                            width: 44,
                            height: 44,
                            radius: AppSpacing.radiusTile,
                            monogramSize: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.collectionTitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  AppText(
                                    item.collectionTitle,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: UdmProgressBar(
                              fraction: item.progress,
                              height: 5,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppText(
                            item.remainingLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(AppIcons.playCircle, size: 22, color: theme.colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Today, as a list a student can finish. Each row is real content the server
/// published for this day, and the tick is the server's own record that this
/// student has done it — not a streak the app guessed.
class _TodaysPlan extends GetView<HomeController> {
  const _TodaysPlan();

  @override
  Widget build(BuildContext context) => Obx(() => _rows(context));

  Widget _rows(BuildContext context) {
    final theme = Theme.of(context);
    final payload = controller.data;
    final rows = <_PlanRow>[
      if (payload?.devotion != null)
        _PlanRow(
          label: 'Daily devotional',
          title: payload!.devotion!.title,
          icon: AppIcons.sun,
          done: controller.isDone(payload.devotion!.id),
          onTap: () => controller.openDevotion(payload.devotion!.id),
        ),
      if (payload?.memoryVerse != null)
        _PlanRow(
          label: 'Verse to keep',
          title: payload!.memoryVerse!.reference,
          icon: AppIcons.memory,
          done: controller.verseMemorized,
          onTap: controller.markMemorized,
        ),
      if (payload?.articles.isNotEmpty ?? false)
        _PlanRow(
          label: 'Reading for today',
          title: payload!.articles.first.title,
          icon: AppIcons.book,
          done: controller.isDone(payload.articles.first.id),
          onTap: () => controller.openArticle(payload.articles.first.id),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Panel(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            "Today's plan",
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            PressableScale(
              onTap: row.onTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    IconBadge(icon: row.icon, size: 38, tone: row.done ? IconBadgeTone.success : IconBadgeTone.brand),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            row.label,
                            style: AppTypography.eyebrow(theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            row.title,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      row.done ? AppIcons.checkCircle : AppIcons.circle,
                      size: 22,
                      color: row.done
                          ? AppColors.success
                          : (theme.textTheme.bodySmall?.color ?? AppColors.secondaryText).withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanRow {
  const _PlanRow({
    required this.label,
    required this.title,
    required this.icon,
    required this.done,
    required this.onTap,
  });

  final String label;
  final String title;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;
}

/// One row of the "Courses" list. The row is the guide's own name, not a
/// generic button, because the ministry writes the list and reorders it without
/// an app release.
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
          CoverArt(
            url: topic.imageUrl,
            monogram: topic.monogram,
            width: AppSpacing.iconTile,
            height: AppSpacing.iconTile,
            radius: AppSpacing.radiusTile,
            monogramSize: 16,
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
                    MetaPill(
                      label: topic.stepsCompleted > 0
                          ? '${topic.stepsCompleted} of ${topic.stepCount} done'
                          : '${topic.stepCount} steps',
                      icon: AppIcons.steps,
                    ),
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
                // The bar is about the reader, not the guide, so it only
                // appears once there is something the student has read.
                if (topic.stepsCompleted > 0) ...[
                  const SizedBox(height: 7),
                  UdmProgressBar(
                    fraction: topic.fractionComplete,
                    height: 5,
                    gradient: AppGradients.hero,
                  ),
                ],
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
