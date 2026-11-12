import 'package:udm_frontend/app/core/localization/localized_snackbar.dart';
import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/network/failure.dart';
import '../../core/storage/local_cache.dart';
import '../../data/providers/udm_api.dart';
import '../content_version/content_version_controller.dart';
import '../settings/app_language_controller.dart';
import '../session/session_controller.dart';

class BibleController extends GetxController with RefetchesOnContentChange {
  BibleController(this.api, this.cache, this.session);

  final UdmApi api;
  final LocalCache cache;
  final SessionController session;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final translations = <Map<String, dynamic>>[].obs;
  final books = <Map<String, dynamic>>[].obs;
  final chapterNumbers = <int>[].obs;
  final chapterData = Rxn<Map<String, dynamic>>();
  final plans = <Map<String, dynamic>>[].obs;
  final bookmarks = <Map<String, dynamic>>[].obs;
  final notes = <Map<String, dynamic>>[].obs;
  final pendingOperations = <Map<String, dynamic>>[].obs;
  final busy = false.obs;
  final offline = false.obs;
  final message = ''.obs;
  final selectedTranslation = ''.obs;
  final selectedBook = ''.obs;
  final selectedChapter = 1.obs;
  final translationQuery = ''.obs;
  final sources = <Map<String, dynamic>>[].obs;
  final passage = Rxn<Map<String, dynamic>>();
  final passageBusy = false.obs;
  final passageOffline = false.obs;
  final passageMessage = ''.obs;
  final passageQuery = ''.obs;
  final passageTranslation = ''.obs;
  String? _accountEmail;
  Worker? _sessionWorker;
  Worker? _languageWorker;

  @override
  void onInit() {
    super.onInit();
    _captureAccount();
    _languageWorker = ever(Get.find<AppLanguageController>().locale, (_) => load());
    _sessionWorker = ever(session.status, (status) {
      if (status == SessionStatus.signedIn) {
        _captureAccount();
        _syncPending().then((_) async {
          await loadSaved();
          await loadPlans();
        });
      }
    });
    load();
  }

  @override
  void onClose() {
    _sessionWorker?.dispose();
    _languageWorker?.dispose();
    super.onClose();
  }

  void _captureAccount() {
    final email = session.profile.value?.email;
    if (email != null && email.isNotEmpty) _accountEmail = email;
  }

  @override
  Future<void> load() async {
    busy.value = true;
    message.value = '';
    _captureAccount();
    await _syncPending();
    final language = Get.find<AppLanguageController>().locale.value.languageCode;
    final catalogCacheKey = 'bible.translations.$language';
    try {
      translations.assignAll(await api.bibleTranslations(language: language));
      await cache.writeJson(catalogCacheKey, {
        'items': translations.toList(),
      });
    } on Failure catch (failure) {
      translations.assignAll(_cachedList(catalogCacheKey));
      if (translations.isEmpty) message.value = failure.message;
    }
    // Loaded before the catalog check: looking a reference up needs no synced
    // rows, so an empty translation catalog must not hide the search.
    await loadSources();
    stampCurrentContent();
    if (translations.isNotEmpty) {
      if (selectedTranslation.value.isEmpty ||
          !translations.any((t) => t['code'] == selectedTranslation.value)) {
        selectedTranslation.value = translations.first['code'] as String;
      }
      await loadBooks();
      await loadPlans();
      if (session.isSignedIn) await loadSaved();
    }
    busy.value = false;
  }

  Future<void> loadBooks() async {
    try {
      books.assignAll(await api.bibleBooks(selectedTranslation.value));
      await cache.writeJson('bible.books.${selectedTranslation.value}', {
        'items': books.toList(),
      });
    } on Failure catch (failure) {
      books.assignAll(_cachedList('bible.books.${selectedTranslation.value}'));
      if (books.isEmpty) message.value = failure.message;
    }
    if (books.isNotEmpty) {
      if (!books.any((b) => bookKey(b) == selectedBook.value)) {
        selectedBook.value = bookKey(books.first);
      }
      await loadBookChapters();
      if (chapterNumbers.isNotEmpty) await loadChapter();
    } else {
      selectedBook.value = '';
      chapterData.value = null;
    }
  }

  String bookKey(Map<String, dynamic> book) {
    final providerId = book['provider_id'] as String?;
    if (providerId != null && providerId.isNotEmpty) return providerId;
    return book['name'] as String;
  }

  Future<void> selectBook(String book) async {
    selectedBook.value = book;
    selectedChapter.value = 1;
    await loadBookChapters();
    if (chapterNumbers.isNotEmpty) await loadChapter();
  }

  Future<void> loadBookChapters() async {
    if (selectedBook.value.isEmpty) return;
    final key =
        'bible.chapters.${selectedTranslation.value}.${selectedBook.value}';
    try {
      chapterNumbers.assignAll(
        await api.bibleBookChapters(
          selectedTranslation.value,
          selectedBook.value,
        ),
      );
      await cache.writeJson(key, {'items': chapterNumbers.toList()});
    } on Failure catch (failure) {
      final items = cache.readJson(key)?['items'] as List<dynamic>? ?? const [];
      chapterNumbers.assignAll(
        items.whereType<num>().map((item) => item.toInt()),
      );
      if (chapterNumbers.isEmpty) message.value = failure.message;
    }
    if (!chapterNumbers.contains(selectedChapter.value) &&
        chapterNumbers.isNotEmpty) {
      selectedChapter.value = chapterNumbers.first;
    }
  }

  /// Which versions this deployment can print, and which it can only hand to an
  /// authorized site. The picker is built from the server, never from a list
  /// baked into the app, so a key added to `.env` shows up without a release.
  Future<void> loadSources() async {
    try {
      sources.assignAll(await api.biblePassageSources());
      await cache.writeJson(_sourcesCacheKey, {'items': sources.toList()});
    } on Failure {
      sources.assignAll(_cachedList(_sourcesCacheKey));
    }
    final chosen = _sourceFor(passageTranslation.value);
    if (chosen == null) {
      passageTranslation.value =
          _sourceFor(selectedTranslation.value)?['code'] as String? ?? 'kjv';
    }
  }

  Map<String, dynamic>? _sourceFor(String code) {
    if (code.isEmpty) return null;
    final wanted = code.toLowerCase();
    return sources.firstWhereOrNull(
      (row) => '${row['code']}'.toLowerCase() == wanted,
    );
  }

  /// Resolves any spelling of a reference through the backend's passage router.
  Future<void> searchPassage([String? reference]) async {
    final text = (reference ?? passageQuery.value).trim();
    passageQuery.value = text;
    if (text.isEmpty) {
      passage.value = null;
      passageOffline.value = false;
      passageMessage.value = 'Type a reference, for example John 3:16.';
      return;
    }
    final code = passageTranslation.value;
    final key = _passageCacheKey(text, code);
    passageBusy.value = true;
    passageMessage.value = '';
    try {
      final fresh = await api.biblePassage(text, translation: code);
      passage.value = fresh;
      passageOffline.value = false;
      // The response says whether the text it served may live on the device;
      // a licensed source that forbids caching is not our choice to override.
      if (fresh['offline_allowed'] == true) await cache.writeJson(key, fresh);
    } on Failure catch (failure) {
      final cached = cache.readJson(key);
      if (cached != null) {
        passage.value = cached;
        passageOffline.value = true;
      } else {
        passage.value = null;
        passageOffline.value = false;
        passageMessage.value = failure.message;
      }
    } finally {
      passageBusy.value = false;
    }
  }

  Future<void> selectPassageVersion(String code) async {
    if (code == passageTranslation.value) return;
    passageTranslation.value = code;
    if (passageQuery.value.trim().isNotEmpty) await searchPassage();
  }

  void clearPassage() {
    passage.value = null;
    passageOffline.value = false;
    passageMessage.value = '';
  }

  List<Map<String, dynamic>> get visibleTranslations {
    final query = translationQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      final matches = translations
          .where((translation) {
            final searchText =
                '${translation['name'] ?? ''} ${translation['code'] ?? ''} ${translation['language'] ?? ''}'
                    .toLowerCase();
            return searchText.contains(query);
          })
          .take(60)
          .toList();
      final selected = translations.firstWhereOrNull(
        (translation) => translation['code'] == selectedTranslation.value,
      );
      if (selected != null && !matches.contains(selected)) {
        matches.add(selected);
      }
      return matches;
    }
    final selected = translations.firstWhereOrNull(
      (translation) => translation['code'] == selectedTranslation.value,
    );
    final result = translations.take(39).toList();
    if (selected != null && !result.contains(selected)) result.add(selected);
    return result;
  }

  Future<void> loadChapter() async {
    if (selectedBook.value.isEmpty) return;
    final key = _cacheKey;
    final offlineAllowed =
        translations.firstWhereOrNull(
          (t) => t['code'] == selectedTranslation.value,
        )?['offline_allowed'] ==
        true;
    busy.value = true;
    try {
      final fresh = await api.bibleChapter(
        selectedTranslation.value,
        selectedBook.value,
        selectedChapter.value,
      );
      chapterData.value = fresh;
      offline.value = false;
      message.value = '';
      if (offlineAllowed) await cache.writeJson(key, fresh);
    } on Failure catch (failure) {
      final cached = offlineAllowed ? cache.readJson(key) : null;
      if (cached != null) {
        chapterData.value = cached;
        offline.value = true;
        message.value = 'Offline copy · ${failure.message}';
      } else {
        chapterData.value = null;
        message.value = failure.message;
      }
    } finally {
      busy.value = false;
    }
  }

  Future<void> loadPlans() async {
    final plansCacheKey = 'bible.plans.${Get.find<AppLanguageController>().locale.value.languageCode}';
    try {
      plans.assignAll(await api.biblePlans());
      if (session.isSignedIn) {
        await _writeCompletedIds(_completedIds(plans));
      }
      await cache.writeJson(plansCacheKey, {'items': _publicPlans(plans)});
    } on Failure {
      plans.assignAll(_cachedList(plansCacheKey));
    }
    final completedIds = session.isSignedIn
        ? await _readCompletedIds()
        : <String>{};
    if (session.isSignedIn) {
      completedIds.addAll(
        (await _readPending())
            .where((op) => op['kind'] == 'plan_progress')
            .map((op) => op['assignment_id'] as String),
      );
    }
    plans.assignAll(_withCompletedAssignments(plans, completedIds));
  }

  List<String> _completedIds(List<Map<String, dynamic>> source) => source
      .expand((plan) => plan['assignments'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((assignment) => assignment['completed'] == true)
      .map((assignment) => assignment['id'] as String)
      .toSet()
      .toList();

  List<Map<String, dynamic>> _publicPlans(List<Map<String, dynamic>> source) =>
      source.map((plan) {
        final assignments = (plan['assignments'] as List<dynamic>? ?? const [])
            .map(
              (item) => {...item as Map<String, dynamic>, 'completed': false},
            )
            .toList();
        return {...plan, 'assignments': assignments};
      }).toList();

  List<Map<String, dynamic>> _withCompletedAssignments(
    List<Map<String, dynamic>> source,
    Set<String> completedIds,
  ) => source.map((plan) {
    final assignments = (plan['assignments'] as List<dynamic>? ?? const []).map(
      (item) {
        final assignment = Map<String, dynamic>.from(
          item as Map<String, dynamic>,
        );
        assignment['completed'] = completedIds.contains(assignment['id']);
        return assignment;
      },
    ).toList();
    return {...plan, 'assignments': assignments};
  }).toList();

  Future<Set<String>> _readCompletedIds() async {
    final raw = await _secureStorage.read(
      key: '$_savedKey.completed_assignments',
    );
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toSet();
    } on FormatException {
      await _secureStorage.delete(key: '$_savedKey.completed_assignments');
      return {};
    }
  }

  Future<void> _writeCompletedIds(Iterable<String> ids) async {
    await _secureStorage.write(
      key: '$_savedKey.completed_assignments',
      value: jsonEncode(ids.toSet().toList()),
    );
  }

  List<Map<String, dynamic>> _cachedList(String key) =>
      (cache.readJson(key)?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  Future<void> loadSaved() async {
    if (!session.isSignedIn) return;
    try {
      final savedBookmarks = await api.bibleBookmarks();
      final savedNotes = await api.bibleNotes();
      bookmarks.assignAll(savedBookmarks);
      notes.assignAll(savedNotes);
      await _secureStorage.write(
        key: '$_savedKey.bookmarks',
        value: jsonEncode(bookmarks),
      );
      await _secureStorage.write(
        key: '$_savedKey.notes',
        value: jsonEncode(notes),
      );
    } on Failure {
      bookmarks.assignAll(await _readPrivateList('$_savedKey.bookmarks'));
      notes.assignAll(await _readPrivateList('$_savedKey.notes'));
    }
  }

  Future<List<Map<String, dynamic>>> _readPrivateList(String key) async {
    final raw = await _secureStorage.read(key: key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } on FormatException {
      await _secureStorage.delete(key: key);
      return [];
    }
  }

  Future<void> bookmark(String verseId) async {
    if (!session.isSignedIn) {
      showLocalizedSnackbar(
        'Sign in required',
        'Sign in to save bookmarks to your account.',
      );
      return;
    }
    _captureAccount();
    try {
      await api.addBibleBookmark(verseId);
      await loadSaved();
      showLocalizedSnackbar('Saved', 'Verse added to your bookmarks.');
    } on Failure catch (failure) {
      if (!_canRetry(failure)) {
        showLocalizedSnackbar('Could not save bookmark', failure.message);
        return;
      }
      await _queue({'kind': 'bookmark', 'verse_id': verseId});
      showLocalizedSnackbar(
        'Saved for sync',
        'Bookmark will sync when you are back online.',
      );
    }
  }

  Future<void> removeBookmark(String id) async {
    _captureAccount();
    try {
      await api.removeBibleBookmark(id);
      await loadSaved();
    } on Failure catch (failure) {
      if (!_canRetry(failure)) {
        showLocalizedSnackbar('Could not remove bookmark', failure.message);
        return;
      }
      bookmarks.removeWhere((bookmark) => bookmark['id'] == id);
      await _queue({'kind': 'remove_bookmark', 'bookmark_id': id});
      showLocalizedSnackbar(
        'Saved for sync',
        'Bookmark removal will sync when you are back online.',
      );
    }
  }

  Future<void> note(String verseId, {String initial = ''}) async {
    if (!session.isSignedIn) {
      showLocalizedSnackbar('Sign in required', 'Sign in to keep private Bible notes.');
      return;
    }
    _captureAccount();
    final input = TextEditingController(text: initial);
    final body = await Get.dialog<String>(
      AlertDialog(
        title: const AppText('Private note'),
        content: TextField(
          controller: input,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a note for yourself',
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const AppText('Cancel')),
          FilledButton(
            onPressed: () => Get.back(result: input.text.trim()),
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    input.dispose();
    if (body == null || body.isEmpty) return;
    try {
      await api.saveBibleNote(verseId, body);
      await loadSaved();
      showLocalizedSnackbar('Saved privately', 'Your note is only visible to you.');
    } on Failure catch (failure) {
      if (!_canRetry(failure)) {
        showLocalizedSnackbar('Could not save note', failure.message);
        return;
      }
      await _queue({'kind': 'note', 'verse_id': verseId, 'body': body});
      showLocalizedSnackbar(
        'Saved for sync',
        'Private note will sync when you are back online.',
      );
    }
  }

  Future<void> editNote(Map<String, dynamic> note) async {
    _captureAccount();
    final input = TextEditingController(text: note['body'] as String? ?? '');
    final body = await Get.dialog<String>(
      AlertDialog(
        title: AppText('Note · ${note['reference']}'),
        content: TextField(controller: input, maxLines: 4),
        actions: [
          TextButton(onPressed: Get.back, child: const AppText('Cancel')),
          FilledButton(
            onPressed: () => Get.back(result: input.text.trim()),
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    input.dispose();
    if (body == null || body.isEmpty) return;
    try {
      await api.updateBibleNote(note['id'] as String, body);
      await loadSaved();
    } on Failure catch (failure) {
      if (!_canRetry(failure)) {
        showLocalizedSnackbar('Could not update note', failure.message);
        return;
      }
      final index = notes.indexWhere((saved) => saved['id'] == note['id']);
      if (index >= 0) notes[index] = {...notes[index], 'body': body};
      await _queue({
        'kind': 'update_note',
        'note_id': note['id'],
        'body': body,
      });
      showLocalizedSnackbar(
        'Saved for sync',
        'Your change will sync when you are back online.',
      );
    }
  }

  Future<void> removeNote(String id) async {
    _captureAccount();
    try {
      await api.removeBibleNote(id);
      await loadSaved();
    } on Failure catch (failure) {
      if (!_canRetry(failure)) {
        showLocalizedSnackbar('Could not remove note', failure.message);
        return;
      }
      notes.removeWhere((note) => note['id'] == id);
      await _queue({'kind': 'remove_note', 'note_id': id});
      showLocalizedSnackbar(
        'Saved for sync',
        'Note removal will sync when you are back online.',
      );
    }
  }

  Future<void> completeAssignment(String id) async {
    if (!session.isSignedIn) {
      showLocalizedSnackbar(
        'Sign in required',
        'Sign in to save reading plan progress.',
      );
      return;
    }
    _captureAccount();
    try {
      await api.completeBibleAssignment(id);
      await loadPlans();
    } on Failure catch (failure) {
      if (!_canRetry(failure)) {
        showLocalizedSnackbar('Could not save progress', failure.message);
        return;
      }
      await _queue({'kind': 'plan_progress', 'assignment_id': id});
      await loadPlans();
      showLocalizedSnackbar(
        'Saved for sync',
        'Reading progress will sync when you are back online.',
      );
    }
  }

  Future<void> _queue(Map<String, dynamic> operation) async {
    final ops = await _readPending();
    final dedupeKey =
        operation['verse_id'] ??
        operation['assignment_id'] ??
        operation['note_id'] ??
        operation['bookmark_id'];
    final existing = ops.indexWhere(
      (op) =>
          op['kind'] == operation['kind'] &&
          (op['verse_id'] ??
                  op['assignment_id'] ??
                  op['note_id'] ??
                  op['bookmark_id']) ==
              dedupeKey,
    );
    if (existing < 0) {
      ops.add(operation);
    } else {
      ops[existing] = operation;
    }
    await _writePending(ops);
    pendingOperations.assignAll(ops);
  }

  Future<void> _syncPending() async {
    if (!session.isSignedIn) return;
    final ops = await _readPending();
    final remaining = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        if (op['kind'] == 'bookmark') {
          await api.addBibleBookmark(op['verse_id'] as String);
        } else if (op['kind'] == 'note') {
          await api.saveBibleNote(
            op['verse_id'] as String,
            op['body'] as String,
          );
        } else if (op['kind'] == 'update_note') {
          await api.updateBibleNote(
            op['note_id'] as String,
            op['body'] as String,
          );
        } else if (op['kind'] == 'remove_note') {
          await api.removeBibleNote(op['note_id'] as String);
        } else if (op['kind'] == 'remove_bookmark') {
          await api.removeBibleBookmark(op['bookmark_id'] as String);
        } else if (op['kind'] == 'plan_progress') {
          await api.completeBibleAssignment(op['assignment_id'] as String);
        }
      } on Failure catch (failure) {
        final isAlreadyDeleted =
            failure.kind == FailureKind.notFound &&
            (op['kind'] == 'remove_note' || op['kind'] == 'remove_bookmark');
        if (!isAlreadyDeleted) remaining.add(op);
      }
    }
    await _writePending(remaining);
    pendingOperations.assignAll(remaining);
  }

  Future<List<Map<String, dynamic>>> _readPending() async {
    final raw = await _secureStorage.read(key: _pendingKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } on FormatException {
      await _secureStorage.delete(key: _pendingKey);
      return [];
    }
  }

  Future<void> _writePending(List<Map<String, dynamic>> operations) async {
    if (operations.isEmpty) {
      await _secureStorage.delete(key: _pendingKey);
    } else {
      await _secureStorage.write(
        key: _pendingKey,
        value: jsonEncode(operations),
      );
    }
  }

  bool _canRetry(Failure failure) =>
      failure.isOffline ||
      failure.kind == FailureKind.serverUnavailable ||
      failure.statusCode == 429;

  String get _cacheKey =>
      'bible.chapter.${selectedTranslation.value}.${Uri.encodeComponent(selectedBook.value)}.${selectedChapter.value}';
  String get _sourcesCacheKey => 'bible.passage.sources';
  String _passageCacheKey(String reference, String code) =>
      'bible.passage.${code.isEmpty ? 'default' : code}.'
      '${reference.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '')}';
  String get _pendingKey => 'bible.pending.${_accountEmail ?? 'signed-out'}';
  String get _savedKey => 'bible.saved.${_accountEmail ?? 'signed-out'}';
}
