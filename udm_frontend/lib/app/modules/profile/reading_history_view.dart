import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/walk_summary.dart';
import 'reading_history_controller.dart';

/// The list behind the profile's Reading History row: every piece of reading
/// this student has marked finished, on the day the server says they did it.
///
/// There is no second copy of these rows on the device, so this screen shows
/// the account or nothing.
class ReadingHistoryView extends GetView<ReadingHistoryController> {
  const ReadingHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const AppText('Reading history')),
      body: Obx(() => StateView(
        state: controller.state.value,
        failureMessage: controller.failureMessage.value,
        onRetry: controller.load,
        emptyTitle: 'Nothing read yet',
        emptyMessage: controller.session.isSignedIn
            ? 'Mark a devotional or an article as read, and the day appears here.'
            : 'Sign in to keep a record of what you have read.',
        emptyIcon: AppIcons.history,
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
              AppText(
                'Finished reading, most recent first. The dates are the server\'s.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final day in controller.days) ...[
                Eyebrow(
                  MaterialLocalizations.of(context).formatMediumDate(day.day),
                  color: theme.colorScheme.primary,
                  icon: AppIcons.calendar,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final row in day.rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _HistoryRow(row: row),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      )),
    );
  }
}

/// One finished reading. The title is the server's own, printed on the row
/// because a history entry that carries only an id is one the student cannot
/// read back.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final ReadHistoryRow row;

  /// The three kinds the server records a reading for. Anything else it adds
  /// later falls back to the open book rather than to a blank tile.
  static const Map<String, IconData> _icons = {
    'devotional': AppIcons.bookmark,
    'article': AppIcons.bookOpen,
    'resource_step': AppIcons.steps,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: _icons[row.kind] ?? AppIcons.bookOpen,
            size: AppSpacing.iconTile,
            filled: false,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  row.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MetaPill(label: row.kindLabel, icon: AppIcons.list),
                    if (row.note.isNotEmpty)
                      MetaPill(label: 'Note kept', icon: AppIcons.note, tone: AppColors.gold),
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
