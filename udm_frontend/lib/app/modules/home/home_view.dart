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
import '../../data/models/resource_topic.dart';
import '../session/session_controller.dart';
import '../shell/shell_controller.dart';
import '../notifications/notifications_controller.dart';
import 'home_controller.dart';

/// The day's feed, in the order a student actually works through it: who is
/// greeting them, the verse to keep, the day of the plan in front of them, what
/// today has already been finished, and the doors they use most.
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
            _HomeHeader(
              child: Column(
                children: [
                  const _Greeting(),
                  if (controller.data?.memoryVerse != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: FadeIn(
                        child: Obx(
                          () => ScripturePanel(
                            compact: true,
                            reference: controller.data!.memoryVerse!.reference,
                            text: controller.data!.memoryVerse!.text,
                            translationCode: controller.data!.memoryVerse!.translationCode,
                            artUrl: controller.data!.memoryVerse!.imageUrl,
                            offline: controller.isOfflineCopy,
                            ctaLabel: controller.data!.devotion == null
                                ? null
                                : "Open today's devotion",
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
                ],
              ),
            ),
            if (controller.data?.reading != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: FadeIn(
                  delay: const Duration(milliseconds: 60),
                  child: const _TodaysReading(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: FadeIn(
                delay: const Duration(milliseconds: 90),
                child: const _TodaysActivities(),
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
                        pill: MetaPill(
                          label: '${article.readingMinutes} min',
                          icon: AppIcons.clock,
                        ),
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
                        child: _ResourceRow(
                          topic: topic,
                          onOpen: () => controller.openTopic(topic.id),
                        ),
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

  /// The three home doors the ministry asked for. The five-tab navigation
  /// stays separate, so nothing here repeats what the bar already carries.
  List<QuickAction> _shortcuts() => [
    QuickAction(label: 'Courses', icon: AppIcons.school, onTap: _openCourses),
    QuickAction(
      label: 'Articles',
      icon: AppIcons.book,
      onTap: () => Get.toNamed(AppRoutes.articles),
    ),
    QuickAction(
      label: 'New Believer',
      icon: AppIcons.sparkles,
      onTap: () => Get.toNamed(AppRoutes.newBeliever),
    ),
  ];

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
            if (profile != null) ...[
              PressableScale(
                onTap: () => Get.find<ShellController>().select(ShellController.profileTab),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: UdmAvatar(
                  initials: profile.initials,
                  size: 42,
                  photoUrl: profile.photoUrl ?? '',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    [
                      if (greeting != null && greeting.isNotEmpty)
                        greeting
                      else
                        'Peace be with you',
                      if (firstName.isNotEmpty) firstName,
                    ].join(', '),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (controller.isOfflineCopy) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const OfflineChip(onDark: true),
                  ],
                ],
              ),
            ),
            // A signed-out student has no face to show, so the door to sign in
            // takes the avatar's place instead of an invented silhouette.
            if (profile == null)
              GhostButton(
                key: const Key('udm.homeGreetingSignIn'),
                label: 'Sign in',
                icon: AppIcons.person,
                onTap: () => Get.toNamed(AppRoutes.signIn),
              ),
            const SizedBox(width: AppSpacing.sm),
            const _NotificationBell(),
          ],
        ),
      );
    });
  }
}

class _NotificationBell extends GetView<NotificationsController> {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) => Obx(() {
    final count = controller.unreadCount.value;
    return Semantics(
      button: true,

      child: PressableScale(
        onTap: () => Get.toNamed(AppRoutes.notifications),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(AppIcons.notifications, color: Colors.white, size: 23),
              if (count > 0)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(color: AppColors.white, width: 1.2),
                    ),
                    child: AppText(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  });
}

/// A compact blue welcome band gives the home feed the warm, personal entry
/// point from the approved reference while leaving the app's shared tab bar
/// untouched.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
    padding: const EdgeInsets.only(top: 24, bottom: AppSpacing.lg),
    decoration: const BoxDecoration(
      gradient: AppGradients.hero,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: child,
  );
}

/// The day of the plan the ministry marked as the daily one, with the plan's
/// own length drawn as a line. The counts come from the server, so the bar says
/// where this student stands rather than where the phone guesses.
class _TodaysReading extends GetView<HomeController> {
  const _TodaysReading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final reading = controller.data?.reading;
      if (reading == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  "Today's readings",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                // The plan itself lives with the translation the student
                // reads, so "see all" moves them to that tab rather than to a
                // second list the app would have to keep in step.
                key: const Key('udm.home.readingPlans'),
                onPressed: () => Get.find<ShellController>().select(ShellController.bibleTab),
                child: const AppText('See all'),
              ),
            ],
          ),
          Panel(
            onTap: controller.openReading,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                IconBadge(
                  icon: reading.day.completed ? AppIcons.checkCircle : AppIcons.bookOpen,
                  size: 62,
                  tone: reading.day.completed ? IconBadgeTone.success : IconBadgeTone.brand,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        reading.day.reference,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppText(
                        'Day ${reading.number} of ${reading.total} · ${reading.planTitle}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      UdmProgressBar(
                        fraction: reading.fraction,
                        height: 5,
                        gradient: AppGradients.hero,
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevron, color: theme.colorScheme.primary, size: 22),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Today, as a list a student can finish. Each row is real content the server
/// published for this day, and the tick is the server's own record that this
/// student has done it — not a streak the app guessed.
///
/// The plan rows come first and the finished rows are what makes their ticks
/// true, so nothing is listed twice: a devotion read today is one row with a
/// check on it, not a to-do and a log entry.
class _TodaysActivities extends GetView<HomeController> {
  const _TodaysActivities();

  @override
  Widget build(BuildContext context) => Obx(() => _activities(context));

  Widget _activities(BuildContext context) {
    final theme = Theme.of(context);
    final payload = controller.data;
    final rows = <_ActivityRow>[
      if (payload?.devotion != null)
        _ActivityRow(
          label: 'Daily devotional',
          title: payload!.devotion!.title,
          icon: AppIcons.sun,
          done: controller.isDone(payload.devotion!.id),
          onTap: () => controller.openDevotion(payload.devotion!.id),
        ),
      if (payload?.memoryVerse != null)
        _ActivityRow(
          label: 'Verse to keep',
          title: payload!.memoryVerse!.reference,
          icon: AppIcons.memory,
          done: controller.verseMemorized,
          onTap: controller.markMemorized,
        ),
      if (payload?.articles.isNotEmpty ?? false)
        _ActivityRow(
          label: 'Reading for today',
          title: payload!.articles.first.title,
          icon: AppIcons.book,
          done: controller.isDone(payload.articles.first.id),
          onTap: () => controller.openArticle(payload.articles.first.id),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Panel(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  "Today's activities",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              // The list on home is only today's; the account holds the rest.
              TextButton(
                key: const Key('udm.home.activityHistory'),
                onPressed: () => Get.toNamed(AppRoutes.readingHistory),
                child: const AppText('See all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in rows)
            PressableScale(
              onTap: row.onTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconBadge(
                      icon: row.icon,
                      size: 38,
                      tone: row.done ? IconBadgeTone.success : IconBadgeTone.brand,
                    ),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
                          : (theme.textTheme.bodySmall?.color ?? AppColors.secondaryText)
                                .withValues(alpha: 0.5),
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

/// One line of today's list: what the ministry put in front of this student,
/// whether their account says it is finished, and where it opens.
class _ActivityRow {
  const _ActivityRow({
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
                            AppText(
                              'Keep your reading history',
                              style: theme.textTheme.titleMedium,
                            ),
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
