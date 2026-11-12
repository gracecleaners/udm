import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_text.dart';
import 'udm_widgets.dart';

enum ViewState { loading, ready, empty, error }

/// Every screen renders through this so loading, failure and empty states look
/// and behave the same across features.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.state,
    required this.child,
    this.onRetry,
    this.failureMessage,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon = Icons.auto_awesome_outlined,
    this.retryLabel = 'Try again',
  });

  final ViewState state;
  final Widget child;
  final VoidCallback? onRetry;
  final String? failureMessage;
  final String? emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ViewState.loading:
        return const CenteredSlot(child: _LoadingSkeleton());
      case ViewState.error:
        return CenteredSlot(
          child: MessagePanel(
            icon: Icons.cloud_off_rounded,
            iconColor: AppColors.warning,
            title: 'We could not load this',
            message: failureMessage ?? 'Check your connection and try again.',
            actionLabel: onRetry == null ? null : retryLabel,
            onAction: onRetry,
          ),
        );
      case ViewState.empty:
        return CenteredSlot(
          child: MessagePanel(
            icon: emptyIcon,
            iconColor: Theme.of(context).colorScheme.primary,
            title: emptyTitle ?? 'Nothing here yet',
            message: emptyMessage ?? 'Content published by the ministry team will appear here.',
            actionLabel: onRetry == null ? null : retryLabel,
            onAction: onRetry,
          ),
        );
      case ViewState.ready:
        return child;
    }
  }
}

/// Three rows of shimmer standing in for the content that is on its way.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 2 ? 0 : AppSpacing.md),
              child: FadeIn(delay: Duration(milliseconds: 90 * i), child: const SkeletonCard()),
            ),
        ],
      );
}

class CenteredSlot extends StatelessWidget {
  const CenteredSlot({super.key, required this.child});

  final Widget child;

  /// Centred while it fits, scrollable when it does not: a long server message
  /// on a small phone must stay readable, not clip.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Centered(child: child),
          ),
        ),
      );
}

/// Small helper so a state panel never stretches oddly on tablets.
class Centered extends StatelessWidget {
  const Centered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: child),
      );
}

class MessagePanel extends StatelessWidget {
  const MessagePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.secondaryText,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, size: 62, tone: _toneOf(iconColor), filled: iconColor != AppColors.secondaryText),
          const SizedBox(height: AppSpacing.lg),
          AppText(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onAction, child: AppText(actionLabel!)),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSecondary, child: AppText(secondaryLabel!)),
          ],
        ],
      ),
    );
  }

  static IconBadgeTone _toneOf(Color color) {
    if (color == AppColors.warning) return IconBadgeTone.warning;
    if (color == AppColors.success) return IconBadgeTone.success;
    if (color == AppColors.danger) return IconBadgeTone.warning;
    return IconBadgeTone.brand;
  }
}

class UdmProgress extends StatelessWidget {
  const UdmProgress({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppText(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}

/// Labels content that came from the device rather than the server. Never rely
/// on colour alone: the icon and the words both say it.
class OfflineChip extends StatelessWidget {
  const OfflineChip({super.key, this.message = 'Offline copy', this.onDark = false});

  final String message;

  /// On the scripture gradient the chip is translucent white instead of amber.
  final bool onDark;

  @override
  Widget build(BuildContext context) => MetaPill(
        label: message,
        icon: Icons.cloud_off_rounded,
        onDark: onDark,
        tone: onDark ? null : AppColors.warning,
      );
}

enum NoticeTone { info, problem }

/// Something the student has to see that is not a whole-screen state: a rejected
/// sign-in, a sign-out the server never heard about, a profile that is offline
/// copy.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message, this.tone = NoticeTone.info});

  final String message;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = tone == NoticeTone.problem ? AppColors.danger : AppColors.warning;
    return FadeIn(
      child: Container(
        key: const Key('udm.noticeBanner'),
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppSpacing.radiusField),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              // The text has to be the flexible child of this row: an `Expanded`
              // inside a row that is itself a row child gets unbounded width.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        tone == NoticeTone.problem ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppText(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyLarge?.color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
