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
import 'media_item_controller.dart';
import 'media_player.dart';

/// One recording opened: it plays here, in the app, on the ministry's own
/// YouTube address, with the write-up the staff published under it.
class MediaItemView extends GetView<MediaItemController> {
  const MediaItemView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Obx(() => AppText(
        controller.item.value?.collectionTitle.isNotEmpty == true
            ? controller.item.value!.collectionTitle
            : 'Learn',
      )),
    ),
    body: Obx(() => StateView(
      state: controller.state.value,
      failureMessage: controller.failureMessage.value,
      onRetry: controller.load,
      emptyTitle: 'Recording unavailable',
      emptyMessage: 'This recording is no longer published.',
      emptyIcon: AppIcons.playCircle,
      child: controller.item.value == null
          ? const SizedBox.shrink()
          : _RecordingBody(item: controller.item.value!, controller: controller),
    )),
  );
}

class _RecordingBody extends StatelessWidget {
  const _RecordingBody({required this.item, required this.controller});

  final MediaItem item;
  final MediaItemController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyColor = theme.textTheme.bodyLarge!.color!;
    final paragraphs = item.body
        .split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xl,
      ),
      children: [
        _PlayerSlot(item: item, controller: controller),
        const SizedBox(height: AppSpacing.md),
        Obx(
          () => controller.hasResumePoint
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: NoticeBanner(
                    message:
                        'Continuing from ${elapsed(controller.resumeAt)}. Press play where you stopped.',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (controller.isOfflineCopy) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: OfflineChip(message: 'Offline copy of this recording'),
          ),
        ],
        AppText(
          item.title,
          style: AppTypography.editorialTitle(bodyColor, size: 32),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (item.author.isNotEmpty)
              MetaPill(icon: AppIcons.person, label: item.author),
            if (item.durationLabel.isNotEmpty)
              MetaPill(icon: AppIcons.clock, label: item.durationLabel),
            if (item.publishAt != null)
              MetaPill(
                icon: AppIcons.calendar,
                label: publicationDate(item.publishAt!.toLocal()),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const GoldRule(width: 72),
        const SizedBox(height: AppSpacing.md),
        _Actions(item: item, controller: controller),
        if (item.excerpt.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AppText(
            item.excerpt,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
        ],
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: AppText(paragraph.trim(), style: AppTypography.scriptureBody(bodyColor)),
          ),
        const SizedBox(height: AppSpacing.xl),
        _NoteSection(item: item, controller: controller),
        const SizedBox(height: AppSpacing.lg),
        Obx(
          () => controller.keepsPrivateState
              ? const SizedBox.shrink()
              : AppText(
                  'Sign in to keep your notes and your place in a recording.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
        ),
      ],
    );
  }
}

/// The player is only rendered where it can actually run. On a build with no
/// WebView behind the embedded frame the recording is still reachable: the row
/// hands it to YouTube, which is where the ministry put it.
class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({required this.item, required this.controller});

  final MediaItem item;
  final MediaItemController controller;

  @override
  Widget build(BuildContext context) {
    final videoId = item.youtubeVideoId;
    if (videoId == null) {
      // A recording staff have not attached a link to yet, or one the ministry
      // distributes only as a file: either way there is nothing to fake here.
      return item.shareUrl.isEmpty
          ? Panel(
              child: Row(
                children: [
                  const IconBadge(
                    icon: AppIcons.learn,
                    size: 40,
                    tone: IconBadgeTone.neutral,
                    filled: false,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppText(
                      'The ministry has not put this recording online yet. Its write-up is here to read, and the teaching arrives as soon as staff attach it.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink();
    }
    if (!inlinePlaybackSupported) {
      return Panel(
        child: Row(
          children: [
            const IconBadge(
              icon: AppIcons.playCircle,
              size: 40,
              tone: IconBadgeTone.gold,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppText(
                'This build has no video engine for the inline player.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => openOnYouTube(videoId),
              icon: const Icon(AppIcons.external, size: 18),
              label: const AppText('Play on YouTube'),
            ),
          ],
        ),
      );
    }
    return Obx(
      () => RecordingPlayer(
        // A new start point is a new player: the frame is cued once, when the
        // page opens, and the student moves it from there with its own controls.
        key: ValueKey('${videoId}_${controller.resumeAt}'),
        videoId: videoId,
        startAt: controller.resumeAt,
        onPosition: controller.recordPosition,
        onEnded: controller.markWatched,
      ),
    );
  }
}

/// The four things a student does with a recording. Each one is rendered only
/// where it can actually be done: Download appears when staff host the file
/// themselves, because a YouTube recording may not be downloaded under its
/// terms, and Share appears when there is a public address to send.
class _Actions extends StatelessWidget {
  const _Actions({required this.item, required this.controller});

  final MediaItem item;
  final MediaItemController controller;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      Obx(() => controller.watched
          ? OutlinedButton.icon(
              onPressed: controller.savingWatch.value ? null : controller.undoWatched,
              icon: const Icon(AppIcons.checkCircle, color: AppColors.success, size: 18),
              label: AppText(controller.savingWatch.value ? 'Saving…' : 'Watched'),
            )
          : FilledButton.icon(
              key: const Key('udm.markWatched'),
              onPressed: controller.savingWatch.value ? null : controller.markWatched,
              icon: const Icon(AppIcons.check, size: 18),
              label: AppText(controller.savingWatch.value ? 'Saving…' : 'Mark watched'),
            )),
      Obx(
        () => OutlinedButton.icon(
          key: const Key('udm.takeNote'),
          onPressed: controller.openNoteEditor,
          icon: Icon(
            controller.noteEditorOpen.value ? AppIcons.chevronUp : AppIcons.note,
            size: 18,
          ),
          label: AppText(
            controller.noteEditorOpen.value
                ? 'Close note'
                : (item.hasNote ? 'Your note' : 'Take a note'),
          ),
        ),
      ),
      if (item.shareUrl.isNotEmpty)
        OutlinedButton.icon(
          key: const Key('udm.shareRecording'),
          onPressed: controller.share,
          icon: const Icon(AppIcons.share, size: 18),
          label: const AppText('Share'),
        ),
      if (item.downloadUrl.isNotEmpty)
        OutlinedButton.icon(
          key: const Key('udm.downloadRecording'),
          onPressed: controller.download,
          icon: const Icon(AppIcons.download, size: 18),
          label: const AppText('Download'),
        ),
    ],
  );
}

/// A note is the student's own writing. It is read from the server with the
/// recording, edited on the page, and stored against their account alone —
/// never in the app's content cache, and never in a staff listing.
class _NoteSection extends StatefulWidget {
  const _NoteSection({required this.item, required this.controller});

  final MediaItem item;
  final MediaItemController controller;

  @override
  State<_NoteSection> createState() => _NoteSectionState();
}

class _NoteSectionState extends State<_NoteSection> {
  final TextEditingController _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    _field.text = widget.item.note;
  }

  @override
  void didUpdateWidget(_NoteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the editor is shut the field follows the server's copy; while it is
    // open the student's typing is the text, and a background refetch must not
    // overwrite it.
    final draft = widget.item.note;
    if (!widget.controller.noteEditorOpen.value && _field.text != draft) {
      _field.text = draft;
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _deleteNote() {
    _field.clear();
    widget.controller.noteDraft.value = '';
    widget.controller.saveNote();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final controller = widget.controller;
    return Obx(() {
      if (!controller.noteEditorOpen.value) {
        if (!item.hasNote) return const SizedBox.shrink();
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(
                      'Your note',
                      icon: AppIcons.note,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  if (item.noteUpdatedAt != null)
                    AppText(
                      publicationDate(item.noteUpdatedAt!.toLocal()),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppText(item.note, style: theme.textTheme.bodyMedium),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoticeBanner(message: controller.noteMessage.value, tone: NoticeTone.problem),
          if (controller.noteMessage.value.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('udm.noteField'),
            controller: _field,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onChanged: (value) => controller.noteDraft.value = value,
            decoration: InputDecoration(
              labelText: 'What did this teaching bring you?',
              helperText: 'Only you and your account can see this.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('udm.saveNote'),
                  onPressed: controller.savingNote.value ? null : controller.saveNote,
                  icon: const Icon(AppIcons.save, size: 18),
                  label: AppText(controller.savingNote.value ? 'Saving…' : 'Save note'),
                ),
              ),
              if (item.hasNote)
                TextButton(
                  key: const Key('udm.deleteNote'),
                  onPressed: controller.savingNote.value ? null : _deleteNote,
                  child: const AppText('Delete'),
                ),
            ],
          ),
        ],
      );
    });
  }
}
