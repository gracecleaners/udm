import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../localization/app_translations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';
import 'udm_widgets.dart';

/// The app's icon dialect. Every glyph a screen asks for comes through here so
/// the whole product speaks one weight of one family — the rounded Material set,
/// which is the closest Flutter ships to the single-stroke outline icons the
/// design is built around. A screen that reaches for `Icons.check` instead of
/// `AppIcons.check` is the reason two toolbars stop looking related.
abstract class AppIcons {
  const AppIcons._();

  static const home = Icons.home_rounded;
  static const book = Icons.menu_book_rounded;
  static const bookOpen = Icons.auto_stories_rounded;
  static const bible = Icons.import_contacts_rounded;
  static const learn = Icons.smart_display_rounded;
  static const community = Icons.groups_rounded;
  static const profile = Icons.person_rounded;
  static const search = Icons.search_rounded;
  static const close = Icons.close_rounded;
  static const back = Icons.arrow_back_rounded;
  static const next = Icons.arrow_forward_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const chevronUp = Icons.keyboard_arrow_up_rounded;
  static const check = Icons.check_rounded;
  static const checkCircle = Icons.check_circle_rounded;
  static const circle = Icons.radio_button_unchecked_rounded;
  static const add = Icons.add_rounded;
  static const edit = Icons.edit_rounded;
  static const note = Icons.edit_note_rounded;
  static const share = Icons.share_rounded;
  static const download = Icons.download_rounded;
  static const bookmark = Icons.bookmark_rounded;
  static const bookmarkBorder = Icons.bookmark_border_rounded;
  static const bookmarkAdd = Icons.bookmark_add_rounded;
  static const verify = Icons.fact_check_rounded;
  static const bookmarks = Icons.bookmarks_rounded;
  static const memory = Icons.psychology_rounded;
  static const delete = Icons.delete_outline_rounded;
  static const play = Icons.play_arrow_rounded;
  static const playCircle = Icons.play_circle_outline_rounded;
  static const pause = Icons.pause_rounded;
  static const clock = Icons.schedule_rounded;
  static const calendar = Icons.calendar_today_rounded;
  static const location = Icons.place_rounded;
  static const person = Icons.person_outline_rounded;
  static const personAdd = Icons.person_add_alt_rounded;
  static const sun = Icons.wb_sunny_rounded;
  static const moon = Icons.nightlight_round;
  static const quote = Icons.format_quote_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const mail = Icons.alternate_email_rounded;
  static const eye = Icons.visibility_rounded;
  static const eyeOff = Icons.visibility_off_rounded;
  static const offline = Icons.cloud_off_rounded;
  static const info = Icons.info_outline_rounded;
  static const warning = Icons.error_outline_rounded;
  static const external = Icons.open_in_new_rounded;
  static const filter = Icons.tune_rounded;
  static const refresh = Icons.refresh_rounded;
  static const more = Icons.more_horiz_rounded;
  static const sparkles = Icons.auto_awesome_rounded;
  static const target = Icons.flag_rounded;
  static const heart = Icons.volunteer_activism_rounded;
  static const school = Icons.school_rounded;
  static const church = Icons.church_rounded;
  static const building = Icons.account_balance_rounded;
  static const pin = Icons.location_on_rounded;
  static const inbox = Icons.inbox_rounded;
  static const language = Icons.translate_rounded;
  static const settings = Icons.settings_rounded;
  static const logout = Icons.logout_rounded;
  static const list = Icons.format_list_numbered_rounded;
  static const steps = Icons.account_tree_rounded;
  static const history = Icons.history_rounded;
  static const save = Icons.save_rounded;
}

/// Cover art the ministry uploaded, with the brand tile underneath it.
///
/// Artwork lives on the ministry's own host, so a series, shelf or recording
/// can be perfectly published and still have no picture. A missing image is a
/// designed state here, not a hole: the initials or the play mark show, and the
/// name stays readable. Exactly one `Image` is ever built, so a screen with two
/// tiles and one picture has one picture.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.url,
    required this.monogram,
    this.icon,
    this.width,
    this.height,
    this.radius = AppSpacing.radiusArt,
    this.fit = BoxFit.cover,
    this.monogramSize = 24,
    this.gradient,
  });

  final String url;

  /// What the tile falls back to when there is no picture: the initials the
  /// server derived from the title.
  final String monogram;

  /// Set instead of a monogram where the thing has no name to abbreviate — a
  /// recording's play mark, for instance.
  final IconData? icon;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final double monogramSize;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    if (url.isEmpty) {
      return _Fallback(
        width: width,
        height: height,
        borderRadius: borderRadius,
        gradient: gradient,
        child: icon != null
            ? Icon(icon, color: AppColors.white, size: monogramSize * 1.15)
            : AppText(
                monogram,
                style: AppTypography.scriptureVerse(AppColors.white, size: monogramSize),
                maxLines: 1,
              ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _Fallback(
            borderRadius: borderRadius,
            gradient: gradient,
            child: icon != null
                ? Icon(icon, color: AppColors.white, size: monogramSize * 1.15)
                : AppText(
                    monogram,
                    style: AppTypography.scriptureVerse(AppColors.white, size: monogramSize),
                    maxLines: 1,
                  ),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : _Fallback(
                  borderRadius: borderRadius,
                  gradient: gradient,
                  dimmed: true,
                  child: const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.width,
    this.height,
    this.gradient,
    this.dimmed = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;
  final Gradient? gradient;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: gradient ?? AppGradients.hero,
          borderRadius: borderRadius,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.16)),
            if (dimmed) const Positioned.fill(child: ColoredBox(color: Color(0x33FFFFFF))),
            Center(child: child),
          ],
        ),
      );
}

/// The large editorial card: art, a scrim that keeps the words legible over any
/// photograph, and the content's own name and byline. This is what a screen
/// leads with when one piece of content is today's.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.artUrl = '',
    this.monogram = '',
    this.artIcon,
    this.pills = const [],
    this.trailing,
    this.onTap,
    this.height = AppSpacing.featureArtHeight,
    this.showScrimText = true,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final String artUrl;
  final String monogram;
  final IconData? artIcon;

  /// Small facts rendered on the picture: reading time, translation, day count.
  final List<Widget> pills;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  /// `false` when the card's art is a plain thumbnail and the title belongs
  /// under it rather than on top of it.
  final bool showScrimText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppSpacing.radiusSheet);

    return PressableScale(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppShadows.float),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CoverArt(
                url: artUrl,
                monogram: monogram,
                icon: artIcon,
                radius: AppSpacing.radiusSheet,
                monogramSize: 44,
                gradient: AppGradients.scripture,
              ),
            ),
            if (showScrimText) const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.scrim))),
            Positioned.fill(
              child: SafeArea(
                top: true,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppText(
                              eyebrow.toUpperCase(),
                              style: AppTypography.eyebrow(Colors.white.withValues(alpha: 0.86)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                      const SizedBox(height: 7),
                      AppText(
                        title,
                        style: AppTypography.editorialTitleOnArt(AppColors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        AppText(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (pills.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: pills),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card in a horizontal discovery rail: art on top, its own name and one fact
/// under it. Fixed width so the rail scrolls by eye rather than by fractions.
class RailCard extends StatelessWidget {
  const RailCard({
    super.key,
    required this.title,
    required this.monogram,
    this.artUrl = '',
    this.artIcon,
    this.eyebrow,
    this.subtitle,
    this.pill,
    this.onTap,
    this.width = AppSpacing.railCard,
    this.artHeight = AppSpacing.railArt,
    this.artRatio = 4 / 3,
    this.useArtRatio = false,
  });

  final String title;
  final String monogram;
  final String artUrl;
  final IconData? artIcon;
  final String? eyebrow;
  final String? subtitle;

  /// One fact under the title — a length, a day count, a progress label.
  final Widget? pill;
  final VoidCallback? onTap;
  final double width;
  final double artHeight;
  final double artRatio;

  /// `true` to let the picture keep its own ratio instead of a fixed height,
  /// which is what a 16:9 recording thumbnail needs.
  final bool useArtRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (useArtRatio)
              AspectRatio(
                aspectRatio: artRatio,
                child: CoverArt(url: artUrl, monogram: monogram, icon: artIcon, radius: AppSpacing.radiusArt),
              )
            else
              SizedBox(
                height: artHeight,
                child: CoverArt(url: artUrl, monogram: monogram, icon: artIcon, radius: AppSpacing.radiusArt),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (eyebrow != null) ...[
              AppText(
                eyebrow!.toUpperCase(),
                style: AppTypography.eyebrow(theme.colorScheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
            ],
            AppText(title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              AppText(subtitle!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (pill != null) ...[
              const SizedBox(height: AppSpacing.sm),
              pill!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A horizontal strip of content the student scrolls through: Continue reading,
/// Related teachings, a shelf's recordings.
///
/// It scrolls in a `SingleChildScrollView`, not a `ListView`: the vertical page
/// it sits in is the list, and a second list inside it makes the screen's own
/// scrollable ambiguous to anything that has to find it.
class DiscoveryRail extends StatelessWidget {
  const DiscoveryRail({
    super.key,
    required this.children,
    this.height,
  });

  final List<Widget> children;

  /// Give a rail a height when its cards size themselves by their art; leave it
  /// null when the cards know their own height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final rail = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == children.length - 1 ? 0 : AppSpacing.md),
              child: children[i],
            ),
        ],
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(parent: ScrollPhysics()),
      padding: EdgeInsets.zero,
      child: height == null ? rail : SizedBox(height: height, child: rail),
    );
  }
}

/// The grid of tabs a student reaches for first: Bible, Devotion, Learn,
/// Community. Server-driven content decides what is here; this only decides how
/// a shortcut looks.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.actions, this.columns = 4});

  final List<QuickAction> actions;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Four across a phone, and never a tile narrower than a thumb needs.
    final perRow = width < 360 ? 3 : columns;
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final action in actions)
            SizedBox(
              width: (constraints.maxWidth - AppSpacing.sm * (perRow - 1)) / perRow,
              child: _QuickActionTile(action: action),
            ),
        ],
      ),
    );
  }
}

class QuickAction {
  const QuickAction({required this.label, required this.icon, required this.onTap, this.tone = IconBadgeTone.brand, this.badge});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final IconBadgeTone tone;

  /// A count worth showing on the shortcut itself.
  final String? badge;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return PressableScale(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: surfaces.card(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconBadge(icon: action.icon, size: 44, tone: action.tone),
                if (action.badge != null)
                  PositionedDirectional(
                    top: -5,
                    end: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        border: Border.all(color: theme.colorScheme.surface, width: 1.6),
                      ),
                      child: AppText(
                        action.badge!,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AppText(
                action.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 12,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one way a screen offers a small, finite set of choices: Campus, Groups,
/// Events, Prayer. Selected carries the brand; the rest stay quiet.
///
/// It wraps rather than scrolls, because a choice that is clipped off screen is
/// a choice the student does not know exists.
class PillSelector extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < options.length; i++)
            _Pill(
              label: options[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 9),
          decoration: surfaces.pill(selected: selected),
          child: AppText(
            label.tr,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 13,
              color: selected ? AppColors.white : theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// A rail's section title with its own see-all action, sized for the horizontal
/// strip rather than a stacked list.
class RailHeader extends StatelessWidget {
  const RailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
        child: SectionHeader(
          title: title,
          subtitle: subtitle,
          eyebrow: eyebrow,
          onSeeAll: onSeeAll,
          seeAllLabel: seeAllLabel,
          trailing: trailing,
        ),
      );
}

/// The tinted circular control that sits in a header row: search, filter, more.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.tone = AppIconButtonTone.quiet,
    this.size = 42,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final AppIconButtonTone tone;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final color = switch (tone) {
      AppIconButtonTone.quiet => theme.textTheme.bodyLarge?.color ?? AppColors.darkText,
      AppIconButtonTone.brand => theme.colorScheme.primary,
      AppIconButtonTone.onDark => AppColors.white,
    };
    final button = PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: switch (tone) {
          AppIconButtonTone.onDark => BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
            ),
          _ => BoxDecoration(
              color: surfaces.scripture,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: surfaces.hairline),
            ),
        },
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: AppTranslations.localize(tooltip!, Get.locale?.languageCode ?? 'en'), child: button);
  }
}

enum AppIconButtonTone { quiet, brand, onDark }

/// A button's own waiting state. The label already says what is happening, so
/// the mark only has to keep moving while the request is open.
class BusyMark extends StatelessWidget {
  const BusyMark({super.key, this.size = 16, this.color = AppColors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
      );
}

/// A rail of cards that have not arrived yet, shaped exactly like the rail they
/// stand in for, so the page does not jump when the content lands.
class SkeletonRail extends StatelessWidget {
  const SkeletonRail({super.key, this.count = 3, this.cardWidth = AppSpacing.railCard, this.artHeight = AppSpacing.railArt});

  final int count;
  final double cardWidth;
  final double artHeight;

  @override
  Widget build(BuildContext context) => DiscoveryRail(
        children: [
          for (var i = 0; i < count; i++)
            FadeIn(
              delay: Duration(milliseconds: 70 * i),
              child: SizedBox(
                width: cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: artHeight, width: cardWidth, radius: AppSpacing.radiusArt),
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(height: 13, width: double.infinity),
                    const SizedBox(height: 7),
                    const SkeletonBox(height: 13, width: 96),
                    const SizedBox(height: AppSpacing.sm),
                    const SkeletonBox(height: 22, width: 64, radius: AppSpacing.radiusPill),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// The featured-card shape while the day's devotion is still being fetched.
class SkeletonFeature extends StatelessWidget {
  const SkeletonFeature({super.key, this.height = AppSpacing.featureArtHeight});

  final double height;

  @override
  Widget build(BuildContext context) => SkeletonBox(height: height, width: double.infinity, radius: AppSpacing.radiusSheet);
}

/// Progress stated as a ring, which is what a course, series or plan wants: the
/// number is the subject, not the bar it is drawn on.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    this.size = 44,
    this.strokeWidth = 4.5,
    this.label,
    this.color,
    this.onDark = false,
  });

  /// 0 → 1. Anything outside that range is clamped rather than thrown at a
  /// paint stage, because a server count can exceed what the client expected.
  final double fraction;
  final double size;
  final double strokeWidth;

  /// Text inside the ring. Defaults to the percentage.
  final String? label;
  final Color? color;

  /// On the hero gradient the track has to be translucent white.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = fraction.clamp(0.0, 1.0);
    final accent = color ?? (onDark ? AppColors.gold : theme.colorScheme.primary);
    final track = onDark ? Colors.white.withValues(alpha: 0.26) : theme.extension<AppSurfaces>()!.scripture;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(value: value, color: accent, track: track, strokeWidth: strokeWidth),
          ),
          AppText(
            label ?? '${(value * 100).round()}%',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: size * 0.26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: onDark ? AppColors.white : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawArc(
      rect,
      0,
      2 * 3.141592653589793,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -3.141592653589793 / 2,
      2 * 3.141592653589793 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.55), color],
          transform: const GradientRotation(-3.141592653589793 / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.strokeWidth != strokeWidth;
}

/// Progress stated as a bar with the numbers beside it, for a lesson or a step
/// list where the count matters more than the shape.
class UdmProgressBar extends StatelessWidget {
  const UdmProgressBar({
    super.key,
    required this.fraction,
    this.height = 7,
    this.color,
    this.gradient,
  });

  final double fraction;
  final double height;

  /// Solid fill. Ignored when [gradient] is given.
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            SizedBox(
              height: height,
              width: constraints.maxWidth,
              child: ColoredBox(color: theme.extension<AppSurfaces>()!.scripture),
            ),
            // The bar grows to its new value instead of snapping to it, which is
            // what makes a progress change read as progress.
            AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.emphasized,
              height: height,
              width: constraints.maxWidth * value,
              decoration: BoxDecoration(
                gradient: gradient ??
                    LinearGradient(
                      colors: [AppColors.royalBlue, color ?? theme.colorScheme.primary],
                    ),
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
