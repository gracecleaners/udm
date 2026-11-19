import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/app_text.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/verse_focus.dart';
import '../settings/appearance_controller.dart';
import '../shell/shell_controller.dart';
import 'bible_controller.dart';

/// Scripture in three motions: choose a translation, book and chapter; read;
/// then keep what mattered.
///
/// The reading bar is the whole design problem here. A dropdown for the book
/// and another for the chapter hide the size of the library behind two taps; a
/// testament choice, a book rail and a chapter rail show the canon as the
/// student already thinks about it.
class BibleView extends GetView<BibleController> {
  const BibleView({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final theme = Theme.of(context);

    if (controller.translations.isEmpty) {
      if (controller.busy.value) {
        return const CenteredSlot(child: UdmProgress(label: 'Loading English Bible versions…'));
      }
      return _Problem(
        message: controller.message.value.isEmpty
            ? 'No licensed translations are available yet.'
            : controller.message.value,
        retry: controller.load,
      );
    }
    final translation = controller.translations.firstWhereOrNull(
      (t) => t['code'] == controller.selectedTranslation.value,
    );
    final verses = (controller.chapterData.value?['verses'] as List<dynamic>?) ?? const [];

    return Container(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(child: CustomPaint(painter: _ReaderWavePainter())),
          ),
          RefreshIndicator(
            color: AppColors.primaryBlue,
            onRefresh: controller.load,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical &&
                    notification.metrics.maxScrollExtent > 0) {
                  controller.readingProgress.value =
                      (notification.metrics.pixels / notification.metrics.maxScrollExtent)
                          .clamp(0, 1)
                          .toDouble();
                }
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                children: [
                  const _Header(),
                  if (translation != null)
                    _ChapterTitle(
                      heading: chapterHeading(controller),
                      translationName: '${translation['name'] ?? ''}',
                      translationCode: '${translation['code'] ?? ''}',
                    ),
                  if (controller.offline.value) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      // The full sentence needs the width a pill cannot give it: this
                      // chapter is on the device, not on the network.
                      child: const NoticeBanner(message: 'Offline copy · saved on this device'),
                    ),
                  ],
                  if (translation != null) ...[
                    const SizedBox(height: 18),
                    _ReadingBar(controller: controller),
                  ],
                  if (controller.message.value.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: AppText(controller.message.value, style: theme.textTheme.bodySmall),
                    ),
                  ],
                  if (translation == null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: AppText(
                        'No translation has been synced into this deployment yet, so '
                        'reading a whole chapter is not available yet.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 25),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: verses.isEmpty && controller.busy.value
                          ? const _ReadingSkeleton()
                          : _ScriptureBlock(
                              heading: chapterHeading(controller),
                              translationCode: '${translation['code'] ?? ''}',
                              verses: verses,
                              attribution: '${translation['attribution'] ?? ''}',
                            ),
                    ),
                  ],
                  if (translation != null && verses.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: _ReaderActionBar(controller: controller, verses: verses),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: const _ReadingProgress(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: controller.session.isSignedIn
                        ? _SavedVerses(controller: controller, theme: theme)
                        : _KeepPrompt(theme: theme),
                  ),
                  if (controller.plans.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const RailHeader(eyebrow: 'Go with a group', title: 'Reading plans'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: Column(
                        children: [
                          for (final plan in controller.plans)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _PlanCard(plan: plan, controller: controller, theme: theme),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (translation != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: _Licensing(translation: translation, theme: theme),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  });

  /// The chapter's own name, taken from the response the server sent rather
  /// than from what the pickers currently show.
  static String chapterHeading(BibleController controller) {
    final data = controller.chapterData.value;
    final book = data?['book'] as String? ?? '';
    final number = data?['number'];
    if (book.isEmpty) return controller.selectedBook.value;
    return number == null ? book : '$book $number';
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Row(children: [const SizedBox(width: 0)]),
    );
  }
}

class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle({
    required this.heading,
    required this.translationName,
    required this.translationCode,
  });

  final String heading;
  final String translationName;
  final String translationCode;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
    child: Column(
      children: [
        AppText(
          heading,
          textAlign: TextAlign.center,
          style: AppTypography.editorialTitle(
            AppColors.deepBlue,
            size: 30,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        AppText(
          '$translationName${translationCode.isEmpty ? '' : ' (${translationCode.toUpperCase()})'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: 190,
          height: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 62,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.royalBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CircleHeaderButton extends StatelessWidget {
  const _CircleHeaderButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.lightBlue,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: AppColors.deepBlue, size: 25),
      ),
    ),
  );
}

/// Version, book, and chapter selectors use the same three simple levels as
/// the reference: one long version capsule, a scrollable book row, and chapter
/// previous/current/next controls.
class _ReadingBar extends StatelessWidget {
  const _ReadingBar({required this.controller});
  final BibleController controller;

  @override
  Widget build(BuildContext context) {
    final selectedTranslation = controller.translations.firstWhereOrNull(
      (row) => row['code'] == controller.selectedTranslation.value,
    );
    final selectedBook = controller.books.firstWhereOrNull(
      (book) => controller.bookKey(book) == controller.selectedBook.value,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: _ReaderSegment(
                icon: AppIcons.book,
                label: selectedBook?['name'] as String? ?? 'Book',
                alignment: MainAxisAlignment.start,
                onTap: () => _showAllBooks(context),
              ),
            ),
            _segmentDivider(),
            Expanded(
              flex: 1,
              child: _ReaderSegment(
                label: '${selectedTranslation?['code'] ?? controller.selectedTranslation.value}'
                    .toUpperCase(),
                alignment: MainAxisAlignment.center,
                onTap: () => _chooseTranslation(context),
              ),
            ),
            _segmentDivider(),
            Expanded(
              flex: 1,
              child: _ReaderSegment(
                icon: AppIcons.calendar,
                label: 'Chapter ${controller.selectedChapter.value}',
                alignment: MainAxisAlignment.end,
                onTap: () => _chooseChapter(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentDivider() => Container(
    width: 1,
    height: 38,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppColors.royalBlue.withValues(alpha: .45),
  );

  Future<void> _chooseTranslation(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TranslationSearchSheet(
        rows: controller.translations.toList(),
        current: controller.selectedTranslation.value,
        onPick: (code) => Navigator.pop(sheetContext, code),
      ),
    );
    if (selected != null && selected != controller.selectedTranslation.value) {
      controller.selectedTranslation.value = selected;
      await controller.loadBooks();
    }
  }

  Future<void> _setChapter(int number) async {
    controller.selectedChapter.value = number;
    await controller.loadChapter();
  }

  Future<void> _chooseChapter(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Obx(() {
          final verses =
              (controller.chapterData.value?['verses'] as List<dynamic>?) ?? const <dynamic>[];
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .58,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: AppText(
                            'Choose a verse',
                            style: TextStyle(
                              color: AppColors.deepBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        DropdownButton<int>(
                          value:
                              controller.chapterNumbers.contains(controller.selectedChapter.value)
                              ? controller.selectedChapter.value
                              : null,
                          hint: const Text('Chapter'),
                          items: controller.chapterNumbers
                              .map(
                                (number) => DropdownMenuItem<int>(
                                  value: number,
                                  child: Text('Chapter $number'),
                                ),
                              )
                              .toList(),
                          onChanged: (number) async {
                            if (number == null || number == controller.selectedChapter.value) {
                              return;
                            }
                            await _setChapter(number);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppText(
                        'Tap a number to open that verse',
                        style: TextStyle(color: AppColors.secondaryText),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (controller.busy.value && verses.isEmpty)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (verses.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No verses available for this chapter.')),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: verses.length,
                        itemBuilder: (context, index) {
                          final verse = verses[index] as Map<String, dynamic>;
                          final number = '${verse['number'] ?? verse['verse'] ?? index + 1}';
                          final selected = controller.selectedVerseNumber.value == number;
                          return Material(
                            color: selected ? AppColors.primaryBlue : AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(13),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(13),
                              onTap: () {
                                controller.selectVerse(number, '${verse['id'] ?? ''}');
                                Navigator.pop(sheetContext);
                              },
                              child: Center(
                                child: Text(
                                  number,
                                  style: TextStyle(
                                    color: selected ? Colors.white : AppColors.deepBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showAllBooks(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.4,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
            ),
            itemCount: controller.books.length,
            itemBuilder: (context, index) {
              final book = controller.books[index];
              return _SelectorPill(
                label: book['name'] as String? ?? '',
                selected: controller.bookKey(book) == controller.selectedBook.value,
                onTap: () => Navigator.pop(context, controller.bookKey(book)),
              );
            },
          ),
        ),
      ),
    );
    if (chosen != null) controller.selectBook(chosen);
  }
}

/// The version picker's search field. It owns its controller so the text
/// editor is torn down with the sheet: disposed by the caller instead, the
/// field is still alive during the sheet's exit animation and reads a controller
/// that has already gone.
class _TranslationSearchSheet extends StatefulWidget {
  const _TranslationSearchSheet({required this.rows, required this.current, required this.onPick});

  final List<Map<String, dynamic>> rows;
  final String current;
  final ValueChanged<String> onPick;

  @override
  State<_TranslationSearchSheet> createState() => _TranslationSearchSheetState();
}

class _TranslationSearchSheetState extends State<_TranslationSearchSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = widget.rows.where((row) {
      if (query.isEmpty) return true;
      return '${row['name'] ?? ''} ${row['code'] ?? ''}'.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search English versions',
                  prefixIcon: Icon(AppIcons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final code = '${row['code'] ?? ''}';
                  return ListTile(
                    title: Text('${row['name'] ?? code}'),
                    subtitle: Text(code.toUpperCase()),
                    trailing: code == widget.current
                        ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                        : null,
                    onTap: () => widget.onPick(code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  const _SelectorPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.trailing,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primaryBlue : AppColors.lightBlue,
    borderRadius: BorderRadius.circular(30),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 15, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.deepBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 14, color: AppColors.deepBlue),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ReaderSegment extends StatelessWidget {
  const _ReaderSegment({
    required this.label,
    required this.alignment,
    required this.onTap,
    this.icon,
  });

  final String label;
  final MainAxisAlignment alignment;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.deepBlue),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChapterControl extends StatelessWidget {
  const _ChapterControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing = false,
    this.onChoose,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool trailing;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: AppColors.mist),
      boxShadow: AppShadows.card(AppColors.mist),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            icon,
            color: onTap == null ? AppColors.secondaryText : AppColors.primaryBlue,
            size: 22,
          ),
        ),
        if (onChoose != null)
          Expanded(
            child: InkWell(
              onTap: onChoose,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.deepBlue),
                    ),
                  ),
                  const Icon(AppIcons.chevronDown, color: AppColors.primaryBlue, size: 20),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.deepBlue),
            ),
          ),
        if (!trailing && onChoose == null) const SizedBox(width: 12),
      ],
    ),
  );
}

/// The address of one verse inside a block.
///
/// A stored passage answers with a reference per verse. A looked-up passage
/// only has its range as a heading, and a range is not a chapter: "John
/// 3:16-18" is read in John 3, so its sixteenth verse is John 3:16 rather than
/// the nonsense of John 3:16-18:16.
String _verseReference({required String heading, required String number, String? fromServer}) {
  if (fromServer != null && fromServer.isNotEmpty) return fromServer;
  final chapter = RegExp(r'^(.*?\s\d{1,3})(?::|$)').firstMatch(heading)?.group(1) ?? heading;
  return '$chapter:$number';
}

/// The chapter as one passage, not as a stack of cards: a single surface, a
/// verse gutter, and scripture set in the reading serif all the way down.
class _ScriptureBlock extends StatelessWidget {
  const _ScriptureBlock({
    required this.heading,
    required this.translationCode,
    required this.verses,
    this.attribution = '',
  });

  final String heading;
  final String translationCode;
  final List<dynamic> verses;

  /// The license line the passage came with, carried to the verse screen so a
  /// kept verse still says where its words came from.
  final String attribution;

  @override
  Widget build(BuildContext context) {
    if (verses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'This chapter has no text in the copy saved on this device. Pull to refresh, '
              'or try again when you are connected to the internet.',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final raw in verses)
            _VerseLine(
              number: '${(raw as Map<String, dynamic>)['number'] ?? raw['verse']}',
              text: '${raw['text'] ?? ''}',
              verseId: '${raw['id'] ?? ''}',
              reference: '${raw['reference'] ?? ''}',
              heading: heading,
              translationCode: translationCode,
              attribution: attribution,
            ),
        ],
      ),
    );
  }
}

/// Tap a verse to select it for the reader actions; long-press opens its detail.
class _VerseLine extends StatelessWidget {
  const _VerseLine({
    required this.number,
    required this.text,
    required this.verseId,
    required this.reference,
    required this.heading,
    required this.translationCode,
    required this.attribution,
  });

  final String number;
  final String text;
  final String verseId;

  /// The server's reference for the verse, used to keep its saved citation.
  final String reference;
  final String heading;
  final String translationCode;
  final String attribution;

  @override
  Widget build(BuildContext context) {
    final appearance = Get.find<AppearanceController>();
    final bible = Get.find<BibleController>();
    return Obx(() {
      final selected = bible.selectedVerseNumber.value == number;
      return InkWell(
        onTap: () => bible.selectVerse(number, verseId),
        onLongPress: () => Get.toNamed(
          AppRoutes.verse,
          arguments: {
            RouteArgs.verse: VerseFocus(
              verseId: verseId,
              reference: _verseReference(heading: heading, number: number, fromServer: reference),
              text: text,
              translationCode: translationCode,
              attribution: attribution,
            ),
          },
        ),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          key: bible.verseRowKey(number),
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 24),
          padding: EdgeInsets.symmetric(horizontal: selected ? 8 : 0),
          decoration: BoxDecoration(
            color: selected ? AppColors.lightBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightBlue,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bible.verseHighlights.containsKey(verseId)
                        ? Color(bible.verseHighlights[verseId]!)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: AppText(
                      text,
                      style: AppTypography.scriptureBody(
                        AppColors.deepBlue,
                        baseSize: 18,
                        scale: appearance.readingScale.value,
                      ).copyWith(height: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _ReaderWavePainter extends CustomPainter {
  const _ReaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(0, size.height * .48)
      ..quadraticBezierTo(size.width * .28, size.height * .15, size.width * .56, size.height * .62)
      ..quadraticBezierTo(size.width * .78, size.height * .92, size.width, size.height * .42)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(back, Paint()..color = AppColors.lightBlue);

    final front = Path()
      ..moveTo(0, size.height * .68)
      ..quadraticBezierTo(size.width * .35, size.height * .25, size.width * .64, size.height * .72)
      ..quadraticBezierTo(size.width * .83, size.height, size.width, size.height * .60)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(front, Paint()..color = AppColors.royalBlue.withValues(alpha: .2));
  }

  @override
  bool shouldRepaint(covariant _ReaderWavePainter oldDelegate) => false;
}

class _ReaderActionBar extends StatelessWidget {
  const _ReaderActionBar({required this.controller, required this.verses});
  final BibleController controller;
  final List<dynamic> verses;

  Map<String, dynamic> get _first => verses.first as Map<String, dynamic>;
  Map<String, dynamic> get _target {
    final selected = controller.selectedVerseNumber.value;
    if (selected.isNotEmpty) {
      for (final raw in verses) {
        final verse = raw as Map<String, dynamic>;
        if ('${verse['number'] ?? verse['verse']}' == selected) return verse;
      }
    }
    return _first;
  }

  String get _id => controller.selectedVerseNumber.value.isEmpty
      ? '${_target['id'] ?? ''}'
      : controller.selectedVerseId.value;
  String get _text => '${_target['text'] ?? ''}';
  String get _reference =>
      '${_target['reference'] ?? '${BibleView.chapterHeading(controller)}:${_target['number'] ?? _target['verse'] ?? 1}'}';

  @override
  Widget build(BuildContext context) => Obx(() {
    final hasSelection = controller.selectedVerseNumber.value.isNotEmpty;
    final actions = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: AppIcons.bookmark,
        label: 'Bookmark',
        onTap: () {
          if (!hasSelection) {
            _promptSelection();
            return;
          }
          if (_id.isNotEmpty) {
            controller.bookmark(_id);
          } else {
            Get.snackbar(
              'Bookmark unavailable',
              'This translation can only be read from an authorized source.',
            );
          }
        },
      ),
      (
        icon: AppIcons.note,
        label: 'Add Note',
        onTap: () {
          if (!hasSelection) {
            _promptSelection();
            return;
          }
          if (_id.isNotEmpty) {
            controller.note(_id);
          } else {
            Get.snackbar(
              'Notes unavailable',
              'This translation can only be read from an authorized source.',
            );
          }
        },
      ),
      (
        icon: AppIcons.edit,
        label: 'Highlight',
        onTap: () {
          if (!hasSelection) {
            _promptSelection();
            return;
          }
          _highlight(context);
        },
      ),
      (
        icon: AppIcons.share,
        label: 'Share',
        onTap: () {
          if (!hasSelection) {
            _promptSelection();
            return;
          }
          _share();
        },
      ),
      (
        icon: AppIcons.copy,
        label: 'Copy',
        onTap: () {
          if (!hasSelection) {
            _promptSelection();
            return;
          }
          _copy();
        },
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.mist),
        boxShadow: AppShadows.card(AppColors.mist),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: AppText(
              hasSelection ? 'Selected: $_reference' : 'Tap a verse to select it',
              style: TextStyle(
                color: hasSelection ? AppColors.primaryBlue : AppColors.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) Container(width: 1, height: 38, color: AppColors.mist),
                Expanded(
                  child: InkWell(
                    onTap: actions[i].onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Icon(actions[i].icon, size: 21, color: AppColors.primaryBlue),
                          const SizedBox(height: 4),
                          AppText(
                            actions[i].label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.deepBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  });

  void _promptSelection() =>
      Get.snackbar('Select a verse', 'Tap a verse in the chapter, then choose an action.');

  Future<void> _highlight(BuildContext context) async {
    if (_id.isEmpty) {
      Get.snackbar(
        'Highlight unavailable',
        'This translation can only be read from an authorized source.',
      );
      return;
    }
    const colors = [Color(0xFFFFF1A8), Color(0xFFD9FBE8), AppColors.mist, Color(0xFFFFDFE6)];
    final chosen = await showModalBottomSheet<Color>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Highlight this verse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final color in colors)
                    InkWell(
                      onTap: () => Navigator.pop(context, color),
                      child: CircleAvatar(backgroundColor: color, radius: 24),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) controller.verseHighlights[_id] = chosen.value;
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: '“$_text”\n$_reference'));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: '“$_text”\n$_reference'));
    Get.snackbar('Copied', 'Verse copied to clipboard.');
  }
}

class _ReadingProgress extends GetView<BibleController> {
  const _ReadingProgress();

  @override
  Widget build(BuildContext context) => Obx(() {
    final progress = controller.readingProgress.value;
    final percentage = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.mist),
        boxShadow: AppShadows.card(AppColors.mist),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.book, color: AppColors.primaryBlue, size: 21),
          const SizedBox(width: 9),
          const AppText(
            'Reading Progress',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.mist,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppText(
            '$percentage%',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  });
}

class _ReadingSkeleton extends StatelessWidget {
  const _ReadingSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    children: const [
      SkeletonBox(height: 20, width: 120),
      SizedBox(height: AppSpacing.lg),
      SkeletonBox(height: 15),
      SizedBox(height: AppSpacing.sm),
      SkeletonBox(height: 15, width: 240),
      SizedBox(height: AppSpacing.sm),
      SkeletonBox(height: 15),
      SizedBox(height: AppSpacing.sm),
      SkeletonBox(height: 15, width: 180),
    ],
  );
}

/// The student's own saved rows, behind one honest header: private, and worth
/// syncing when the network comes back.
class _SavedVerses extends StatelessWidget {
  const _SavedVerses({required this.controller, required this.theme});

  final BibleController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: const IconBadge(icon: AppIcons.bookmarks, size: 40, filled: false),
      title: const AppText('My saved verses and notes'),
      subtitle: controller.pendingOperations.isEmpty
          ? null
          : AppText(
              '${controller.pendingOperations.length} private change(s) waiting to sync.',
              style: theme.textTheme.bodySmall,
            ),
      onExpansionChanged: (open) {
        if (open) controller.loadSaved();
      },
      children: [
        if (controller.bookmarks.isEmpty && controller.notes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AppText('Your saved verses and private notes will appear here.'),
          ),
        ...controller.bookmarks.map(
          (saved) => _SavedRow(
            icon: AppIcons.bookmark,
            iconColor: AppColors.primaryBlue,
            title: saved['reference'] as String? ?? 'Saved verse',
            body: saved['text'] as String? ?? '',
            tooltip: 'Remove bookmark',
            onDelete: () => controller.removeBookmark(saved['id'] as String),
          ),
        ),
        ...controller.notes.map(
          (note) => _SavedRow(
            icon: AppIcons.note,
            iconColor: AppColors.gold,
            title: note['reference'] as String? ?? 'Private note',
            body: note['body'] as String? ?? '',
            tooltip: 'Delete note',
            onTap: () => controller.editNote(note),
            onDelete: () => controller.removeNote(note['id'] as String),
          ),
        ),
      ],
    ),
  );
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.tooltip,
    required this.onDelete,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String tooltip;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusTile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(title, style: theme.textTheme.titleSmall),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      AppText(
                        body,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              AppIconButton(
                icon: AppIcons.delete,
                onTap: onDelete,
                tooltip: tooltip,
                size: 36,
                iconSize: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepPrompt extends StatelessWidget {
  const _KeepPrompt({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        const IconBadge(icon: AppIcons.lock, size: 40, filled: false),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('Keep your bookmarks and notes'),
              const SizedBox(height: 2),
              AppText(
                'Sign in to sync them privately across your devices.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: () => Get.toNamed(AppRoutes.signIn),
          child: const AppText('Sign in'),
        ),
      ],
    ),
  );
}

/// A plan opened: its days, and how far through it the student already is.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.controller, required this.theme});

  final Map<String, dynamic> plan;
  final BibleController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final assignments = (plan['assignments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final done = assignments.where((a) => a['completed'] == true).length;
    final fraction = assignments.isEmpty ? 0.0 : done / assignments.length;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Column(
        children: [
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            leading: ProgressRing(fraction: fraction, size: 42),
            title: AppText(plan['title'] as String, style: theme.textTheme.titleMedium),
            subtitle: AppText(
              '$done of ${assignments.length} days read',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: UdmProgressBar(fraction: fraction),
          ),
          for (final assignment in assignments)
            _PlanDay(
              assignment: assignment,
              onComplete: () => controller.completeAssignment(assignment['id'] as String),
            ),
        ],
      ),
    );
  }
}

class _PlanDay extends StatelessWidget {
  const _PlanDay({required this.assignment, required this.onComplete});

  final Map<String, dynamic> assignment;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = assignment['completed'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            done ? AppIcons.checkCircle : AppIcons.circle,
            color: done ? AppColors.success : AppColors.secondaryText,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Day ${assignment['day']}', style: theme.textTheme.titleSmall),
                AppText(
                  assignment['reference'] as String? ?? '',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (done)
            const MetaPill(label: 'Done', icon: AppIcons.check, tone: AppColors.success)
          else
            AppIconButton(
              icon: AppIcons.check,
              onTap: onComplete,
              tooltip: 'Mark complete',
              size: 36,
              iconSize: 18,
            ),
        ],
      ),
    );
  }
}

class _Licensing extends StatelessWidget {
  const _Licensing({required this.translation, required this.theme});

  final Map<String, dynamic> translation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Panel(
    radius: AppSpacing.radiusTile,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Licensing'),
        const SizedBox(height: AppSpacing.sm),
        AppText(translation['attribution'] as String? ?? '', style: theme.textTheme.bodySmall),
        if ((translation['source_url'] as String? ?? '').startsWith('https://'))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(translation['source_url'] as String),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(AppIcons.external, size: 16),
              label: const AppText('Translation license and source'),
            ),
          ),
      ],
    ),
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => CenteredSlot(
    child: MessagePanel(
      icon: AppIcons.book,
      title: 'Scripture unavailable',
      message: message,
      actionLabel: 'Try again',
      onAction: retry,
    ),
  );
}
