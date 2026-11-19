import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_art.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/formatted_content.dart';
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
      child: Obx(
        () => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: controller.statusBarUsesDarkIcons.value
                ? Brightness.dark
                : Brightness.light,
            statusBarBrightness: controller.statusBarUsesDarkIcons.value
                ? Brightness.light
                : Brightness.dark,
          ),
          child: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              const Positioned.fill(child: _HomeBackdrop()),
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final verseHeight = controller.data?.memoryVerse == null
                      ? 0.0
                      : _HomeMemoryVerseCard.heightForWidth(
                          MediaQuery.sizeOf(context).width,
                        );
                  final lightBackgroundStartsAt =
                      MediaQuery.paddingOf(context).top + 110 + verseHeight;
                  if (notification.depth == 0 &&
                      (notification is ScrollUpdateNotification ||
                          notification is OverscrollNotification)) {
                    controller.updateStatusBarTone(
                      notification.metrics.pixels,
                      lightBackgroundStartsAt,
                    );
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: controller.load,
                  child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  children: [
                    _HomeHeader(
                      verseExtension: controller.data?.memoryVerse == null
                          ? 0
                          : _HomeMemoryVerseCard.heightForWidth(
                                  MediaQuery.sizeOf(context).width,
                                ) *
                                .75,
                      child: const _Greeting(),
                    ),
                    if (controller.data?.memoryVerse != null)
                      Transform.translate(
                        offset: const Offset(0, -15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FadeIn(
                            child: Obx(
                              () => _HomeMemoryVerseCard(
                                reference:
                                    controller.data!.memoryVerse!.reference,
                                text: controller.data!.memoryVerse!.text,
                                artUrl: controller.data!.memoryVerse!.imageUrl,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FadeIn(
                        delay: const Duration(milliseconds: 120),
                        child: const _HomeFeatureCards(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (controller.data?.resources.isNotEmpty ?? false)
                      FadeIn(
                        delay: const Duration(milliseconds: 150),
                        child: _RecommendedResources(
                          resources: controller.data!.resources,
                          onSelect: controller.openTopic,
                        ),
                      ),
                    if (controller.data?.reading != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screen,
                        ),
                        child: FadeIn(
                          delay: const Duration(milliseconds: 180),
                          child: const _TodaysReading(),
                        ),
                      ),
                    ],
                    if (controller.data?.articles.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xl),
                     
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screen,
                      ),
                      child: const _SignInNudge(),
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
          ),
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

/// The image-led verse strip shown in the supplied home header reference.
/// Staff artwork wins; the bundled sunrise is the offline/default backdrop.
class _HomeMemoryVerseCard extends StatelessWidget {
  const _HomeMemoryVerseCard({
    required this.reference,
    required this.text,
    required this.artUrl,
  });

  final String reference;
  final String text;
  final String artUrl;

  static double heightForWidth(double width) =>
      (width * .49).clamp(180.0, 210.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = heightForWidth(width);
    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x39001F5B),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (artUrl.isNotEmpty)
            Image.network(
              artUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.asset(
                AppArt.splash,
                fit: BoxFit.cover,
                alignment: const Alignment(.28, .48),
              ),
            )
          else
            Image.asset(
              AppArt.splash,
              fit: BoxFit.cover,
              alignment: const Alignment(.28, .48),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xD900173D),
                  Color(0x9B001B40),
                  Color(0x3D001B40),
                ],
                stops: [0, .56, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x70000D25), Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 18, 19, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FormattedContent(
                      '“${text.trim().replaceAll(RegExp(r'^[“"]|[”"]$'), '')}”',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Colors.white,
                        fontSize: (width * .05).clamp(18.0, 21.0),
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.15,
                        shadows: const [
                          Shadow(color: Color(0xB8000A1C), blurRadius: 9),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      AppIcons.bookOpen,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Greeting, name and the face that belongs to them. The sentence is the
/// server's, the name is the account's, and the avatar is the Profile tab: a
/// student who taps their own face expects to land on their own details.
class _Greeting extends GetView<HomeController> {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    final type = Theme.of(context).textTheme;
    return Obx(() {
      final profile = session.profile.value;
      final displayName = profile?.displayName.trim() ?? '';
      final firstName = displayName.isEmpty
          ? ''
          : displayName.split(RegExp(r'\s+')).first;
      return Padding(
        padding: const EdgeInsets.fromLTRB(19, 11, 19, 0),
        child: Row(
          children: [
            PressableScale(
              onTap: () => profile == null
                  ? Get.toNamed(AppRoutes.signIn)
                  : Get.find<ShellController>().select(
                      ShellController.profileTab,
                    ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: profile == null
                  ? Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.royalBlue,
                      ),
                      child: const Icon(
                        AppIcons.person,
                        color: Colors.white,
                        size: 36,
                      ),
                    )
                  : UdmAvatar(
                      initials: profile.initials,
                      size: 58,
                      photoUrl: profile.photoUrl ?? '',
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning,',
                    style: type.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: firstName.isEmpty ? 'Welcome' : firstName,
                        ),
                        const TextSpan(text: ' 👋'),
                      ],
                    ),
                    style: type.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (controller.isOfflineCopy) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const OfflineChip(onDark: true),
                  ],
                ],
              ),
            ),
            const _NotificationBell(),
          ],
        ),
      );
    });
  }
}

/// Four compact, two-column doors keep the home page's most common journeys
/// visible without duplicating the shared bottom navigation.
class _HomeFeatureCards extends StatelessWidget {
  const _HomeFeatureCards();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _HomeFeatureImage(
        asset: 'assets/images/new_believer.png',
        semanticLabel: 'New Believer — Start your journey with Christ',
        onTap: () => Get.toNamed(AppRoutes.newBeliever),
      ),
      const SizedBox(height: AppSpacing.md),
      _HomeFeatureImage(
        asset: 'assets/images/articles.png',
        semanticLabel: 'Articles — Insights to strengthen your faith',
        onTap: () => Get.toNamed(AppRoutes.articles),
      ),
    ],
  );
}

class _HomeFeatureImage extends StatelessWidget {
  const _HomeFeatureImage({
    required this.asset,
    required this.semanticLabel,
    required this.onTap,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1.78,
            child: Ink.image(image: AssetImage(asset), fit: BoxFit.cover),
          ),
        ),
      ),
    ),
  );
}

class _SectionAccent extends StatelessWidget {
  const _SectionAccent();

  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 24,
    decoration: BoxDecoration(
      color: AppColors.primaryBlue,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
    ),
  );
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
          width: 42,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(AppIcons.notifications, color: Colors.white, size: 31),
              if (count > 0)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusPill,
                      ),
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
  const _HomeHeader({required this.child, this.verseExtension = 0});

  final Widget child;
  final double verseExtension;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: topInset, bottom: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -topInset,
            bottom: -verseExtension,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
            ),
          ),
          const Positioned.fill(child: _HeaderDecorations()),
          child,
        ],
      ),
    );
  }
}

class _HeaderDecorations extends StatelessWidget {
  const _HeaderDecorations();

  @override
  Widget build(BuildContext context) =>
      const IgnorePointer(child: CustomPaint(painter: _HeaderPainter()));
}

class _HeaderPainter extends CustomPainter {
  const _HeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(colors: [Color(0x4478C7FF), Color(0x0078C7FF)])
              .createShader(
                Rect.fromCircle(
                  center: Offset(size.width * .72, size.height * .2),
                  radius: size.width * .75,
                ),
              );
    canvas.drawRect(Offset.zero & size, glow);
    final circle = Paint()..color = Colors.white.withValues(alpha: .055);
    canvas.drawCircle(
      Offset(size.width * .60, -size.width * .22),
      size.width * .32,
      circle,
    );
    canvas.drawCircle(
      Offset(size.width * .97, size.height * .16),
      size.width * .23,
      circle,
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter oldDelegate) => false;
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFFBFDFF), AppColors.lightBlue],
        stops: [0, .65, 1],
      ),
    ),
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
                  "Today's reading",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                // The plan itself lives with the translation the student
                // reads, so "see all" moves them to that tab rather than to a
                // second list the app would have to keep in step.
                key: const Key('udm.home.readingPlans'),
                onPressed: () => Get.find<ShellController>().select(
                  ShellController.bibleTab,
                ),
                child: const _SeeAll(),
              ),
            ],
          ),
          Panel(
            onTap: controller.openReading,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: reading.day.completed
                          ? AppIcons.checkCircle
                          : AppIcons.bookOpen,
                      size: 48,
                      tone: reading.day.completed
                          ? IconBadgeTone.success
                          : IconBadgeTone.brand,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            reading.planTitle,
                            style: AppTypography.eyebrow(
                              theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          AppText(
                            reading.day.reference,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (reading.day.title.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            AppText(
                              reading.day.title,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(AppIcons.chevron, color: theme.colorScheme.primary),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: UdmProgressBar(
                        fraction: reading.fraction,
                        height: 6,
                        gradient: AppGradients.hero,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppText(
                      '${reading.completed}/${reading.total} days',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      reading.finished ? AppIcons.checkCircle : AppIcons.circle,
                      color: reading.finished
                          ? AppColors.success
                          : theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppText(
                        reading.finished
                            ? 'Plan complete'
                            : reading.day.completed
                            ? 'Today’s reading complete'
                            : 'Day ${reading.number} of ${reading.total}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppText(
                      reading.day.completed ? 'Read again' : 'Continue reading',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      AppIcons.next,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// The round blue door on the reference's continue-reading card. It is drawn
/// rather than wired: the whole card already opens the day, so a second tap
/// target inside it would only compete with the first.
/// Today, as a list a student can finish. Each row is real content the server
/// published for this day, and the tick is the server's own record that this
/// student has done it — not a streak the app guessed.
/// Swipeable resource cards scale up as they become the focused item. The list
/// and each resource's details are supplied by the ministry API.
class _RecommendedResources extends StatefulWidget {
  const _RecommendedResources({
    required this.resources,
    required this.onSelect,
  });

  final List<ResourceTopic> resources;
  final ValueChanged<String> onSelect;

  @override
  State<_RecommendedResources> createState() => _RecommendedResourcesState();
}

class _RecommendedResourcesState extends State<_RecommendedResources> {
  late final PageController _pageController;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: .78);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const _SectionAccent(),
            const SizedBox(width: 10),
            Expanded(
              child: AppText(
                'Recommended Resources',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.deepBlue,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _showAll,
              child: AppText(
                'View All',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.primaryBlue),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 355,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.resources.length,
          onPageChanged: (index) => setState(() => _focusedIndex = index),
          itemBuilder: (context, index) {
            final resource = widget.resources[index];
            final focused = index == _focusedIndex;
            return AnimatedScale(
              scale: focused ? 1 : .86,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  clipBehavior: Clip.antiAlias,
                  elevation: focused ? 7 : 2,
                  shadowColor: AppColors.deepBlue.withValues(alpha: .18),
                  child: InkWell(
                    onTap: () => widget.onSelect(resource.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CoverArt(
                                url: resource.imageUrl,
                                monogram: resource.monogram,
                                radius: 0,
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0xA500173F),
                                    ],
                                    stops: [.5, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .94),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    resource.pdfUrl.isNotEmpty
                                        ? 'PDF'
                                        : 'GUIDE',
                                    style: const TextStyle(
                                      color: AppColors.deepBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 15,
                                child: Text(
                                  '${resource.views} ${resource.views == 1 ? 'view' : 'views'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FormattedContent(
                                resource.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.deepBlue,
                                  fontSize: 16,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              FormattedContent(
                                resource.summary.isEmpty
                                    ? 'Open this resource to explore its overview.'
                                    : resource.summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (widget.resources.length > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < widget.resources.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _focusedIndex ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index == _focusedIndex
                      ? AppColors.primaryBlue
                      : AppColors.primaryBlue.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
    ],
  );

  Future<void> _showAll() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Recommended Resources',
                style: TextStyle(
                  color: AppColors.deepBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final resource in widget.resources)
              ListTile(
                leading: CoverArt(
                  url: resource.imageUrl,
                  monogram: resource.monogram,
                  width: 58,
                  height: 58,
                  radius: 10,
                ),
                title: Text(resource.title),
                subtitle: Text('${resource.views} ${resource.views == 1 ? 'view' : 'views'}'),
                trailing: const Icon(
                  AppIcons.chevron,
                  color: AppColors.primaryBlue,
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onSelect(resource.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The header's whole-group door, drawn the way the reference draws it: the
/// word in brand blue with a short arrow after it.
class _SeeAll extends StatelessWidget {
  const _SeeAll();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppText(
        'See all',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.primaryBlue,
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 2),
      Icon(AppIcons.next, size: 19, color: AppColors.primaryBlue),
    ],
  );
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
              gradient: AppGradients.tint(
                surfaces.scripture,
                theme.colorScheme.surface,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconBadge(
                        icon: AppIcons.heart,
                        size: 44,
                        tone: IconBadgeTone.gold,
                      ),
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
