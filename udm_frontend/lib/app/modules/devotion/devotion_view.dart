import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/devotional.dart';
import '../reader/reading_progress.dart';
import 'devotion_controller.dart';

class DevotionView extends GetView<DevotionController> {
  const DevotionView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        // The page opens with its own title set in the reading serif, so the
        // bar carries only the way back.
        appBar: AppBar(),
        body: Obx(() => StateView(
              state: controller.state.value,
              failureMessage: controller.failureMessage.value,
              onRetry: controller.load,
              emptyTitle: 'Devotion unavailable',
              emptyMessage: 'This devotion is no longer published.',
              child: controller.devotional.value == null
                  ? const SizedBox.shrink()
                  : _DevotionBody(devotional: controller.devotional.value!, controller: controller),
            )),
      );
}

class _DevotionBody extends StatelessWidget {
  const _DevotionBody({required this.devotional, required this.controller});

  final Devotional devotional;
  final DevotionController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyColor = theme.textTheme.bodyLarge!.color!;
    final paragraphs = devotional.body.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
      children: [
        AppText(
          'Today\'s devotion',
          style: AppTypography.eyebrow(theme.colorScheme.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppText(
          devotional.title,
          style: AppTypography.editorialTitle(bodyColor, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        const GoldRule(width: 72),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            MetaPill(icon: AppIcons.book, label: devotional.scriptureReference),
            MetaPill(icon: AppIcons.clock, label: '${devotional.readingMinutes} min'),
            if (devotional.author.isNotEmpty) MetaPill(icon: AppIcons.person, label: devotional.author),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppText(paragraph.trim(), style: AppTypography.scriptureBody(bodyColor)),
          ),
        if (devotional.hasQuestions) ...[
          const SizedBox(height: AppSpacing.sm),
          SectionHeader(
            title: 'Reflect',
            subtitle: '${devotional.reflectionQuestions.length} questions to sit with',
          ),
          const SizedBox(height: AppSpacing.md),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: devotional.reflectionQuestions.indexed
                  .map((entry) => _Question(index: entry.$1 + 1, text: entry.$2))
                  .toList(),
            ),
          ),
        ],
        if (devotional.application.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(
            icon: AppIcons.checkCircle,
            eyebrow: 'Live it out',
            body: devotional.application,
            tone: IconBadgeTone.success,
          ),
        ],
        if (devotional.prayer.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(
            icon: AppIcons.heart,
            eyebrow: 'Pray',
            body: devotional.prayer,
            tone: IconBadgeTone.brand,
          ),
        ],
        if (devotional.memoryScriptureReference.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(
            icon: AppIcons.memory,
            eyebrow: 'Memorise',
            body: devotional.memoryScriptureReference,
            tone: IconBadgeTone.gold,
            onDark: true,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.hero,
              boxShadow: AppShadows.glow(AppColors.primaryBlue),
            ),
            child: AppText(
              '$index',
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: AppText(text, style: theme.textTheme.titleSmall?.copyWith(height: 1.5))),
        ],
      ),
    );
  }
}

/// The three closing blocks of a devotion. Only the memory verse is scripture,
/// so only it wears the dark gradient and the reading serif.
class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.eyebrow,
    required this.body,
    required this.tone,
    this.onDark = false,
  });

  final IconData icon;
  final String eyebrow;
  final String body;
  final IconBadgeTone tone;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (tone) {
      IconBadgeTone.success => AppColors.success,
      IconBadgeTone.gold => AppColors.gold,
      IconBadgeTone.warning => AppColors.warning,
      _ => AppColors.primaryBlue,
    };

    return Panel(
      gradient: onDark ? AppGradients.scripture : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, size: 32, tone: tone, filled: onDark),
              const SizedBox(width: AppSpacing.sm),
              Eyebrow(eyebrow, color: onDark ? Colors.white70 : accent),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (onDark) ...[
            const GoldRule(width: 44),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppText(
            body,
            style: onDark
                ? AppTypography.scriptureVerse(AppColors.white, size: 19)
                : theme.textTheme.bodyMedium?.copyWith(height: 1.62),
          ),
        ],
      ),
    );
  }
}
