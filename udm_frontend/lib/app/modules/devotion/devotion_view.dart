import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/devotional.dart';
import '../reader/reading_progress.dart';
import 'devotion_controller.dart';

class DevotionView extends GetView<DevotionController> {
  const DevotionView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Today\'s devotion')),
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
    final paragraphs = devotional.body.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
      children: [
        Text(devotional.title, style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MetaPill(icon: Icons.book_outlined, label: devotional.scriptureReference),
            _MetaPill(icon: Icons.schedule_rounded, label: '${devotional.readingMinutes} min'),
            if (devotional.author.isNotEmpty)
              _MetaPill(icon: Icons.person_outline_rounded, label: devotional.author),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(paragraph.trim(), style: theme.textTheme.bodyLarge),
          ),
        if (devotional.hasQuestions) ...[
          const SizedBox(height: AppSpacing.sm),
          const SectionHeader(title: 'Reflect'),
          const SizedBox(height: AppSpacing.sm),
          ...devotional.reflectionQuestions.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.$1 + 1}.',
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(entry.$2, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
        if (devotional.application.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(icon: Icons.check_circle_outline_rounded, title: 'Live it out', body: devotional.application),
        ],
        if (devotional.prayer.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(icon: Icons.volunteer_activism_outlined, title: 'Pray', body: devotional.prayer),
        ],
        if (devotional.memoryScriptureReference.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Block(
            icon: Icons.psychology_outlined,
            title: 'Memorise',
            body: devotional.memoryScriptureReference,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: AppSpacing.sm),
                Text(title.toUpperCase(), style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: theme.extension<AppSurfaces>()!.scripture,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
