import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/localization/date_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/media_item.dart';
import 'media_collection_controller.dart';

/// A shelf opened: the ministry's own banner for it, then its recordings in
/// the order the staff set.
class MediaCollectionView extends GetView<MediaCollectionController> {
  const MediaCollectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => AppText(controller.collection.value?.title ?? 'Learn')),
      ),
      body: Obx(() => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Nothing released on this shelf yet',
        emptyMessage:
            'The ministry team has not published a recording here. Check back soon.',
        emptyIcon: AppIcons.playCircle,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.xl,
            ),
            children: [
              HeroPanel(
                eyebrow: _countLabel(controller.collection.value?.itemCount ?? 0),
                title: controller.collection.value?.title ?? '',
                subtitle: (controller.collection.value?.description ?? '').isEmpty
                    ? null
                    : controller.collection.value!.description,
                trailing: const Mark(size: 46, icon: AppIcons.playCircle),
                children: [
                  if (controller.isOfflineCopy) ...[
                    const SizedBox(height: AppSpacing.md),
                    const OfflineChip(message: 'Offline copy of this shelf', onDark: true),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Eyebrow('In order', icon: AppIcons.list, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < controller.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: FadeIn(
                    delay: Duration(milliseconds: 55 * i),
                    child: _RecordingRow(
                      item: controller.items[i],
                      onOpen: () => controller.openItem(controller.items[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      )),
    );
  }

  /// The server counts what a student can actually open, so the banner states
  /// that number rather than the number staff typed into the console.
  static String _countLabel(int count) =>
      '$count ${count == 1 ? 'recording' : 'recordings'}';
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.item, required this.onOpen});

  final MediaItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A place in the recording only reads as a fraction when the ministry gave
    // a runtime to divide it by.
    final total = item.durationSeconds;
    final resume = item.resumeAt;
    final resuming = !item.watched && resume != null && resume > 0 && total != null && total > 0;
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecordingArt(item: item),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppFonts.scripture,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.5,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                AppText(
                  _byline(item),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.durationLabel.isNotEmpty)
                      MetaPill(icon: AppIcons.clock, label: item.durationLabel),
                    // The marks are facts the server states about this
                    // recording, so an item with no link carries neither.
                    if (item.youtubeVideoId != null)
                      const MetaPill(
                        label: 'Video',
                        icon: AppIcons.playCircle,
                      )
                    else if (item.downloadUrl.isNotEmpty)
                      const MetaPill(label: 'File', icon: AppIcons.download),
                    if (item.watched)
                      const MetaPill(
                        label: 'Watched',
                        icon: AppIcons.checkCircle,
                        tone: AppColors.success,
                      )
                    else if (item.resumeAt != null && item.resumeAt! > 0)
                      MetaPill(
                        label: 'Resume ${elapsed(item.resumeAt!)}',
                        icon: AppIcons.history,
                        tone: theme.colorScheme.primary,
                      ),
                  ],
                ),
                // Where a student stopped is worth a shape, not only a word.
                if (resuming) ...[
                  const SizedBox(height: AppSpacing.sm),
                  UdmProgressBar(fraction: resume / total, height: 4),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            AppIcons.chevron,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ],
      ),
    );
  }

  /// A shelf's rows say who taught and when, which is how a student tells two
  /// recordings on the same passage apart.
  static String _byline(MediaItem item) {
    final parts = [
      if (item.publishAt != null) publicationDate(item.publishAt!.toLocal()),
      if (item.author.isNotEmpty) item.author,
    ];
    return parts.isEmpty ? 'UDM' : parts.join(' · ');
  }

}

class _RecordingArt extends StatelessWidget {
  const _RecordingArt({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppSpacing.shelfArt,
    height: AppSpacing.shelfArt,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // A recording with no artwork of its own still has a face: the play
        // mark, on the brand gradient, which is what the row offers.
        CoverArt(
          url: item.imageUrl,
          monogram: '',
          icon: AppIcons.play,
          radius: AppSpacing.radiusArt,
          monogramSize: 26,
        ),
        if (item.watched)
          PositionedDirectional(
            bottom: 4,
            start: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.4),
              ),
              child: const Icon(AppIcons.check, size: 11, color: AppColors.white),
            ),
          ),
      ],
    ),
  );
}
