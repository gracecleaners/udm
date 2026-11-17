import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/verse_focus.dart';
import '../settings/appearance_controller.dart';
import '../settings/reading_size_sheet.dart';
import '../session/session_controller.dart';
import 'bible_controller.dart';

/// One verse, alone, on a page worth keeping.
///
/// The reading screen gives a verse its number and its neighbours; this gives
/// it the whole picture, because a verse a student means to memorise or send
/// to somebody is read one at a time. Everything asked for under a verse —
/// keep it, size it, send it, write on it — is here, and only what the app can
/// honestly do with the text the server actually gave us.
class VerseDetailView extends StatefulWidget {
  const VerseDetailView({super.key});

  @override
  State<VerseDetailView> createState() => _VerseDetailViewState();
}

class _VerseDetailViewState extends State<VerseDetailView> {
  VerseFocus get _verse {
    final arguments = Get.arguments;
    final carried = arguments is Map<String, dynamic> ? arguments[RouteArgs.verse] : null;
    return carried is VerseFocus ? carried : const VerseFocus(reference: '', text: '');
  }

  @override
  void initState() {
    super.initState();
    // Whether this verse is already kept is the student's own list, and the
    // reading screen has had no reason to ask for it yet.
    if (_verse.isKeppable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Get.find<SessionController>().isSignedIn) {
          Get.find<BibleController>().loadSaved();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bible = Get.find<BibleController>();
    final appearance = Get.find<AppearanceController>();
    final verse = _verse;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.scripture)),
            Mark.backdrop(tint: AppColors.white, alpha: 0.08),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: AppIcons.close,
                        tooltip: 'Close',
                        tone: AppIconButtonTone.onDark,
                        onTap: Get.back,
                      ),
                      const Spacer(),
                      if (verse.translationCode.isNotEmpty)
                        MetaPill(label: verse.translationCode.toUpperCase(), onDark: true),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Obx(
                    () => Column(
                      children: [
                        AppText(
                          verse.text,
                          textAlign: TextAlign.center,
                          style: AppTypography.scriptureVerse(
                            AppColors.white,
                            size: appearance.scaled(25),
                          ).copyWith(height: 1.42),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const GoldRule(width: 44),
                        const SizedBox(height: AppSpacing.md),
                        AppText(
                          verse.reference,
                          textAlign: TextAlign.center,
                          style: AppTypography.scriptureReference(AppColors.white.withValues(alpha: 0.88))
                              .copyWith(fontSize: 15),
                        ),
                        if (verse.attribution.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          AppText(
                            verse.attribution,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Obx(
                  () => _ActionBar(
                    verse: verse,
                    kept: verse.isKeppable
                        ? bible.bookmarks.firstWhereOrNull((row) => '${row['verse_id']}' == verse.verseId)
                        : null,
                    note: verse.isKeppable
                        ? bible.notes.firstWhereOrNull((row) => '${row['verse_id']}' == verse.verseId)
                        : null,
                    signedIn: bible.session.isSignedIn,
                    bible: bible,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The four things a student does with a verse they have stopped on.
///
/// A verse the app may not write to — one the router answered from a version
/// it is only licensed to link out to — keeps its share and its size control,
/// and says plainly why there is nothing to save.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.verse,
    required this.kept,
    required this.note,
    required this.signedIn,
    required this.bible,
  });

  final VerseFocus verse;
  final Map<String, dynamic>? kept;
  final Map<String, dynamic>? note;
  final bool signedIn;
  final BibleController bible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (note != null) ...[
            _NoteCard(
              body: '${note?['body'] ?? ''}',
              onEdit: () => bible.note(verse.verseId, initial: '${note?['body'] ?? ''}'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.darkInk.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      if (verse.isKeppable)
                        _Action(
                          icon: kept == null ? AppIcons.bookmarkBorder : AppIcons.bookmark,
                          label: kept == null ? 'Keep' : 'Kept',
                          onTap: () => kept == null
                              ? bible.bookmark(verse.verseId)
                              : bible.removeBookmark('${kept!['id']}'),
                        )
                      else
                        _Action(icon: AppIcons.lock, label: 'Keep', onTap: _explain),
                      _Action(icon: AppIcons.textSize, label: 'Size', onTap: () => ReadingSizeSheet.show(context)),
                      _Action(icon: AppIcons.share, label: 'Share', onTap: _share),
                      if (verse.isKeppable)
                        _Action(
                          icon: AppIcons.note,
                          label: note == null ? 'Note' : 'Edit note',
                          onTap: () => bible.note(verse.verseId, initial: '${note?['body'] ?? ''}'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!signedIn) ...[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              verse.isKeppable
                  ? 'Signing in keeps this verse on your own account.'
                  : 'This translation is read from an authorized site.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  void _explain() => Get.snackbar(
    'This verse cannot be kept',
    'The app may only link out to this translation, so its verses are not '
        'stored to bookmark.',
  );

  Future<void> _share() async {
    final text = '“${verse.text}”\n${verse.reference}'
        '${verse.translationCode.isEmpty ? '' : ' · ${verse.translationCode.toUpperCase()}'}'
        '${verse.attribution.isEmpty ? '' : '\n${verse.attribution}'}';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } on Exception {
      Get.snackbar('Could not share', 'No sharing app answered. Copy the verse instead.');
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.white),
            const SizedBox(height: 5),
            AppText(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// What the student already wrote on this verse, with the only edit that is
/// theirs to make.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.body, required this.onEdit});

  final String body;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      border: false,
      radius: AppSpacing.radiusCard,
      gradient: AppGradients.tint(
        AppColors.darkInk.withValues(alpha: 0.55),
        AppColors.darkSurface.withValues(alpha: 0.62),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.note, size: 20, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Your note', style: AppTypography.eyebrow(AppColors.white.withValues(alpha: 0.72))),
                const SizedBox(height: 3),
                AppText(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.white),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIconButton(
            icon: AppIcons.edit,
            tooltip: 'Edit note',
            tone: AppIconButtonTone.onDark,
            size: 38,
            iconSize: 17,
            onTap: onEdit,
          ),
        ],
      ),
    );
  }
}
