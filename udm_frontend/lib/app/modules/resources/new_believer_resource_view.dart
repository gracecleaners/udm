import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/formatted_content.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/new_believer_resource.dart';
import '../reader/reading_progress.dart';
import 'new_believer_resource_controller.dart';

class NewBelieverResourceView extends GetView<NewBelieverResourceController> {
  const NewBelieverResourceView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('New Believer')),
    body: Obx(
      () => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Resource unavailable',
        emptyMessage: 'This introduction resource is no longer published.',
        child: controller.resource.value == null
            ? const SizedBox.shrink()
            : _NewBelieverResourceBody(
                resource: controller.resource.value!,
                controller: controller,
              ),
      ),
    ),
  );
}

class _NewBelieverResourceBody extends StatelessWidget {
  const _NewBelieverResourceBody({
    required this.resource,
    required this.controller,
  });

  final NewBelieverResource resource;
  final NewBelieverResourceController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyColor = theme.textTheme.bodyLarge!.color!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        if (resource.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              resource.imageUrl,
              height: 210,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          )
        else
          const Center(child: Mark(size: 64)),
        const SizedBox(height: AppSpacing.md),
        const Eyebrow(
          'Things to understand first',
          color: AppColors.primaryBlue,
          icon: AppIcons.sparkles,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppText(
          resource.title,
          style: AppTypography.editorialTitle(bodyColor, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        const GoldRule(width: 72),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (resource.scriptureReference.isNotEmpty)
              MetaPill(icon: AppIcons.book, label: resource.scriptureReference),
            MetaPill(icon: AppIcons.clock, label: '${resource.readingMinutes} min'),
            if (resource.author.isNotEmpty)
              MetaPill(icon: AppIcons.person, label: resource.author),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (resource.excerpt.isNotEmpty) ...[
          FormattedContent(
            resource.excerpt,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        FormattedContent(
          resource.body,
          style: AppTypography.scriptureBody(bodyColor),
        ),
        if (resource.hasVideo) ...[
          const SizedBox(height: AppSpacing.lg),
          Panel(
            child: Row(
              children: [
                const IconBadge(
                  icon: AppIcons.playCircle,
                  size: 38,
                  tone: IconBadgeTone.gold,
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: AppText('Watch a ministry teaching about this topic.'),
                ),
                OutlinedButton.icon(
                  key: const Key('udm.watchNewBelieverResource'),
                  onPressed: controller.openVideo,
                  icon: const Icon(AppIcons.external, size: 16),
                  label: const AppText('Watch'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ProgressFooter(reader: controller),
      ],
    );
  }
}
