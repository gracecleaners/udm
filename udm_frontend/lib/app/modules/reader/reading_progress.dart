import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../data/models/content_kind.dart';
import '../../data/repositories/content_repository.dart';
import '../session/session_controller.dart';

/// Finishing a piece of reading is the one thing a reader writes back to the
/// server. Devotions and articles share this so both say the same thing about
/// the same action, and so an anonymous tap offers sign-in instead of silently
/// dropping the tap.
mixin TracksReadingProgress on GetxController {
  SessionController get session;
  ContentRepository get content;
  ContentKind get progressKind;
  String get progressId;

  final RxBool markedRead = false.obs;
  final RxBool savingProgress = false.obs;
  final RxString progressMessage = ''.obs;

  /// Whether this reading will be remembered.
  bool get tracksProgress => session.isSignedIn;

  Future<void> markRead() async {
    if (markedRead.value || savingProgress.value) return;
    if (!session.isSignedIn) {
      Get.toNamed(AppRoutes.signIn);
      return;
    }
    savingProgress.value = true;
    progressMessage.value = '';
    try {
      await content.recordCompletion(kind: progressKind, id: progressId);
      markedRead.value = true;
    } on Failure catch (failure) {
      progressMessage.value = failure.message;
    } finally {
      savingProgress.value = false;
    }
  }
}

/// The footer every reader ends with: the write-back and, when the student is
/// not signed in, the reason the tap would only take them to sign-in.
class ProgressFooter extends StatelessWidget {
  const ProgressFooter({super.key, required this.reader});

  final TracksReadingProgress reader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() => NoticeBanner(message: reader.progressMessage.value, tone: NoticeTone.problem)),
        Obx(
          () => reader.markedRead.value
              ? OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                  label: const Text('Marked as read'),
                )
              : FilledButton.icon(
                  key: const Key('udm.markRead'),
                  onPressed: reader.savingProgress.value ? null : reader.markRead,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(reader.savingProgress.value ? 'Saving…' : 'Mark as read'),
                ),
        ),
        Obx(
          () => reader.tracksProgress
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Sign in to keep this in your reading history.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }
}
