import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:udm_frontend/app/core/network/api_client.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:udm_frontend/app/core/storage/local_cache.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/storage/token_store.dart';
import 'package:udm_frontend/app/data/models/article.dart';
import 'package:udm_frontend/app/data/models/content_kind.dart';
import 'package:udm_frontend/app/data/models/devotion_day.dart';
import 'package:udm_frontend/app/data/models/devotion_series.dart';
import 'package:udm_frontend/app/data/models/devotional.dart';
import 'package:udm_frontend/app/data/models/media_collection.dart';
import 'package:udm_frontend/app/data/models/media_item.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';
import 'package:udm_frontend/app/data/models/memory_verse.dart';
import 'package:udm_frontend/app/data/models/resource_step.dart';
import 'package:udm_frontend/app/data/models/resource_topic.dart';
import 'package:udm_frontend/app/data/models/resume_item.dart';
import 'package:udm_frontend/app/data/models/session.dart';
import 'package:udm_frontend/app/data/models/todays_reading.dart';
import 'package:udm_frontend/app/data/models/user_notification.dart';
import 'package:udm_frontend/app/data/models/user_profile.dart';
import 'package:udm_frontend/app/data/models/walk_summary.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/data/repositories/auth_repository.dart';
import 'package:udm_frontend/app/data/repositories/content_repository.dart';
import 'package:udm_frontend/app/data/repositories/devotions_repository.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';
import 'package:udm_frontend/app/data/repositories/media_repository.dart';
import 'package:udm_frontend/app/data/repositories/resources_repository.dart';
import 'package:udm_frontend/app/data/repositories/settings_repository.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';
import 'package:udm_frontend/app/modules/notifications/notifications_controller.dart';
import 'package:udm_frontend/app/modules/session/session_controller.dart';
import 'package:udm_frontend/app/modules/settings/appearance_controller.dart';

/// Test payload shaped exactly like `/api/v1/home/`. Pass [reading] to move the
/// day of the plan the dashboard carries, or [withoutReading] for a ministry
/// that has not marked a plan as the daily one yet.
HomePayload sampleHome({TodaysReading? reading, bool withoutReading = false}) =>
    HomePayload(
      greeting: 'Good morning, Grace',
      memoryVerse: const MemoryVerse(
        id: 'v1',
        reference: 'Romans 12:2',
        text: 'Be not conformed to this world.',
        translationCode: 'kjv',
      ),
      devotion: const Devotional(
        id: 'd1',
        title: 'A Heart That Listens',
        scriptureReference: '1 Samuel 3:1-10',
        body: 'Eli was half asleep.\n\nListening is taught.',
        reflectionQuestions: ['What makes God\'s voice hard to hear?'],
      ),
      articles: const [
        Article(
          id: 'a1',
          title: 'How to Study a Chapter',
          body: 'Read once.',
          category: 'Bible study',
        ),
      ],
      reading: withoutReading ? null : (reading ?? sampleReading()),
      resources: sampleResourceTopics(),
      serverTime: DateTime.utc(2026, 11, 2, 7, 30),
    );

/// The daily plan exactly as `/home/` answers it: the day the student is on,
/// written in the four sections the ministry authors, with the plan's length
/// beside it so the progress line has something to be drawn from.
TodaysReading sampleReading({
  bool completed = false,
  int completedDays = 2,
}) => TodaysReading(
  planTitle: 'Romans in a month',
  total: 30,
  completed: completedDays + (completed ? 1 : 0),
  day: ReadingDay(
    id: 'day-3',
    day: 3,
    title: 'The righteous shall live by faith',
    reference: 'Romans 1:16-17',
    verseReference: 'Romans 1:17',
    verseText: 'The just shall live by faith.',
    whatItSays: 'Paul is not ashamed, because the gospel is the power of God.',
    whatToLearn:
        'Faith is what the gospel produces in you, not what you produce first.',
    completed: completed,
  ),
);

/// The home "Find resources on" list as the ministry leaves it: named guides in
/// the order they put them in, each holding the number of steps it has live.
List<ResourceTopic> sampleResourceTopics() => const [
  ResourceTopic(
    id: 'r1',
    title: 'Receive Christ',
    summary: 'Five short steps through what God has already done.',
    order: 1,
    stepCount: 5,
  ),
  ResourceTopic(id: 'r2', title: 'New Believer', order: 2, stepCount: 5),
  ResourceTopic(id: 'r3', title: 'Prayer', order: 3, stepCount: 3),
];

/// One guide opened: the server sorts the unnumbered starting point first, and
/// a row carries no body until the step itself is asked for.
ResourceTopic sampleResourceTopic() => const ResourceTopic(
  id: 'r1',
  title: 'Receive Christ',
  summary: 'Five short steps through what God has already done.',
  order: 1,
  stepCount: 4,
  contentVersion: 9,
  steps: [
    ResourceStep(
      id: 'i1',
      title: 'He is near',
      scriptureReference: 'Acts 17:27-28',
      excerpt: 'The verse that opens the guide.',
      readingMinutes: 3,
    ),
    ResourceStep(
      id: 's1',
      title: 'All turned aside',
      order: 1,
      scriptureReference: 'Romans 3:10-12',
      readingMinutes: 4,
    ),
    ResourceStep(
      id: 's2',
      title: 'Love reached across',
      order: 2,
      scriptureReference: 'John 3:16',
      readingMinutes: 5,
      videoUrl: 'https://videos.udm.ac.ug/receive-christ-love.mp4',
    ),
    ResourceStep(
      id: 's3',
      title: 'Calling on Him',
      order: 3,
      scriptureReference: 'Romans 10:13',
      readingMinutes: 6,
    ),
  ],
);

/// A step read on its own: the passage, and the guide it sits in. The video is
/// off by default because most steps have none curated, and the reader must
/// show no play control for those.
ResourceStep sampleResourceStep({String videoUrl = ''}) => ResourceStep(
  id: 's2',
  title: 'Love reached across',
  order: 2,
  scriptureReference: 'John 3:16',
  excerpt: 'What the verse says before it is read.',
  body: 'God so loved the world.\n\nThat is the whole argument of the guide.',
  readingMinutes: 5,
  videoUrl: videoUrl,
  topicId: 'r1',
  topicTitle: 'Receive Christ',
  topicStepCount: 4,
);

/// `/api/v1/devotions/series/` as the ministry team leaves it: one series with
/// cover art on the ministry's host, one that is only a title for now.
List<DevotionSeries> sampleSeriesGrid() => const [
  DevotionSeries(
    id: 's1',
    title: 'The Book of James',
    description: 'Faith that shows up on Monday.',
    coverImageUrl: 'https://files.udm.ac.ug/series/james.jpg',
    order: 1,
    dayCount: 7,
  ),
  DevotionSeries(id: 's2', title: 'Christmas', order: 2, dayCount: 1),
];

/// What `/api/v1/devotions/` answers for the Devotions tab: the devotionals the
/// ministry publishes on their own, newest first, so the first row is the
/// day's reading and the rest sit behind it. One carries art on the ministry's
/// host, one has none at all, and one has neither an excerpt nor a picture.
List<Devotional> sampleDevotionalFeed() => const [
  Devotional(
    id: 'd10',
    title: 'Trust God in Every Season',
    scriptureReference: 'Ecclesiastes 3:1',
    excerpt: 'To every thing there is a season.',
    body:
        'There is a time for everything.\n\nTrust is what makes a season bear.',
    imageUrl: 'https://files.udm.ac.ug/devotions/seasons.jpg',
    readingMinutes: 4,
  ),
  Devotional(
    id: 'd9',
    title: 'A Heart That Listens',
    scriptureReference: '1 Samuel 3:1-10',
    excerpt: 'Listening is taught, not caught.',
    body: 'Eli was half asleep.\n\nListening is taught.',
    readingMinutes: 5,
  ),
  Devotional(
    id: 'd8',
    title: 'Salt and Light',
    scriptureReference: 'Matthew 5:13-16',
    body: 'You are the salt of the earth.',
    readingMinutes: 6,
  ),
];

/// What `/api/v1/media/` answers for the Learn tab: two shelves in the order
/// the ministry set them, each with its recordings on it.
List<MediaCollection> sampleMediaShelves() => [
  MediaCollection(
    id: 'c1',
    title: 'SOMA',
    description: 'Study, Observe, Meditate, and Apply the Scriptures.',
    order: 1,
    imageUrl: 'https://files.udm.ac.ug/media/soma.jpg',
    itemCount: 2,
    items: [sampleRecording()],
  ),
  const MediaCollection(id: 'c2', title: 'Podcast', order: 3, itemCount: 1),
];

/// One recording with everything a shelf row and a page can show: the
/// ministry's own link, a runtime, and the write-up under it.
MediaItem sampleRecording({
  String id = 'm1',
  String note = '',
  int? resumeAt,
  bool watched = false,
  String downloadUrl = '',
  String? youtubeVideoId = 'QHJZ8pZzZfE',
}) => MediaItem(
  id: id,
  title: 'True faith sides with God | Hebrews 11:29-31',
  author: 'Edgar Karuma',
  excerpt: 'Hebrews 11 is not a list of heroes. It is a list of listeners.',
  body: 'Moses chose the people over the palace.\n\nFaith sides with God before it understands why.',
  order: 1,
  publishAt: DateTime.utc(2026, 10, 21, 9),
  durationSeconds: 940,
  imageUrl: 'https://i.ytimg.com/vi/QHJZ8pZzZfE/hqdefault.jpg',
  youtubeVideoId: youtubeVideoId,
  youtubeUrl: youtubeVideoId == null ? '' : 'https://youtu.be/$youtubeVideoId',
  downloadUrl: downloadUrl,
  watched: watched,
  resumeAt: resumeAt,
  note: note,
  collectionId: 'c1',
  collectionTitle: 'SOMA',
  collectionItemCount: 2,
);

/// One series opened: the server sorts the unnumbered Introduction first.
DevotionSeries sampleSeriesDetail() => const DevotionSeries(
  id: 's1',
  title: 'The Book of James',
  description: 'Faith that shows up on Monday.',
  coverImageUrl: 'https://files.udm.ac.ug/series/james.jpg',
  order: 1,
  dayCount: 3,
  days: [
    DevotionDay(
      id: 'i1',
      title: 'Who wrote this, and why',
      scriptureReference: 'James 1:1',
      readingMinutes: 4,
    ),
    DevotionDay(
      id: 'd1',
      title: 'Count it all joy',
      day: 1,
      scriptureReference: 'James 1:2-4',
      readingMinutes: 5,
    ),
    DevotionDay(
      id: 'd2',
      title: 'Ask in faith',
      day: 2,
      scriptureReference: 'James 1:5-8',
      readingMinutes: 6,
    ),
  ],
);

/// Two notices as `/api/v1/notifications/` answers them: one the student has
/// not opened, one already read.
final List<UserNotification> sampleNotifications = [
  UserNotification(
    id: 'n1',
    title: 'Camp service tonight',
    body: 'The worship team starts at 7 at the main hall.',
    kind: 'announcement',
    destination: '/community',
    createdAt: DateTime.utc(2026, 11, 2, 15),
  ),
  UserNotification(
    id: 'n2',
    title: 'Romans in a month is on day 3',
    body: 'Your reading for today is waiting.',
    kind: 'reading',
    destination: '',
    createdAt: DateTime.utc(2026, 10, 31, 9),
    readAt: DateTime.utc(2026, 11, 1, 8),
  ),
];

/// The inbox half of [UdmApi], carried by every API fake so a screen that reads
/// the bell has the same three answers as the server. A test that wants an
/// unread badge sets [notificationRows] and [unreadCountValue] rather than
/// reaching for a network.
mixin FakeNotifications {
  List<UserNotification> notificationRows = sampleNotifications;
  int unreadCountValue = 1;
  int notificationCalls = 0;

  /// Tokens the app handed the ministry, and those it asked it to forget.
  final List<String> devicesRegistered = [];
  final List<String> devicesUnregistered = [];

  Failure? notificationsFailure;

  Future<({List<UserNotification> items, int unreadCount})>
  notifications() async {
    notificationCalls++;
    if (notificationsFailure != null) throw notificationsFailure!;
    return (items: notificationRows, unreadCount: unreadCountValue);
  }

  Future<UserNotification> markNotificationRead(String id) async {
    if (notificationsFailure != null) throw notificationsFailure!;
    final updated = notificationRows
        .map(
          (item) => item.id == id
              ? UserNotification(
                  id: item.id,
                  title: item.title,
                  body: item.body,
                  kind: item.kind,
                  destination: item.destination,
                  createdAt: item.createdAt,
                  readAt: item.readAt ?? DateTime.utc(2026, 11, 2, 16),
                )
              : item,
        )
        .toList();
    notificationRows = updated;
    unreadCountValue = updated.where((item) => !item.isRead).length;
    return updated.firstWhere((item) => item.id == id);
  }

  Future<void> markAllNotificationsRead() async {
    if (notificationsFailure != null) throw notificationsFailure!;
    notificationRows = notificationRows
        .map(
          (item) => UserNotification(
            id: item.id,
            title: item.title,
            body: item.body,
            kind: item.kind,
            destination: item.destination,
            createdAt: item.createdAt,
            readAt: item.readAt ?? DateTime.utc(2026, 11, 2, 16),
          ),
        )
        .toList();
    unreadCountValue = 0;
  }

  Future<void> registerNotificationDevice({
    required String token,
    required String platform,
  }) async {
    if (notificationsFailure != null) throw notificationsFailure!;
    devicesRegistered.add('$platform:$token');
  }

  Future<void> unregisterNotificationDevice(String token) async {
    if (notificationsFailure != null) throw notificationsFailure!;
    devicesUnregistered.add(token);
  }
}

class FakeUdmApi with FakeNotifications implements UdmApi {
  HomePayload? homePayload;
  Failure? failure;
  int homeCalls = 0;

  /// What `/content-version/` answers. Screens poll it, so a test that wants to
  /// look like the ministry just published moves this number between calls.
  int contentVersionValue = 1;
  int contentVersionCalls = 0;

  /// What `/devotions/series/` and one series detail answer.
  List<DevotionSeries> seriesRows = const [];
  DevotionSeries? seriesDetail;
  int seriesCalls = 0;
  int seriesDetailCalls = 0;

  /// What `/resources/`, one guide and one step answer.
  List<ResourceTopic> resourceTopicRows = const [];
  ResourceTopic? resourceTopicRow;
  ResourceStep? resourceStepRow;
  int resourceTopicCalls = 0;
  int resourceStepCalls = 0;

  /// What `/auth/token/` and `/auth/register/` hand back.
  Session? session;

  /// What `/users/me/` answers, and what a PATCH merges into it.
  UserProfile? serverProfile;

  /// Set to make every auth endpoint fail, offline or rejected alike.
  Failure? authFailure;

  Map<String, dynamic>? lastProfilePatch;

  /// Where a saved profile's picture went, so an upload test can say which file
  /// the app handed the API rather than only that it handed something.
  String? lastPhotoPath;
  String? lastPhotoName;
  String? revokedRefresh;
  final List<String> completions = [];
  int profileCalls = 0;

  @override
  Future<HomePayload> home() async {
    homeCalls++;
    if (failure != null) throw failure!;
    if (homePayload == null)
      throw StateError('FakeUdmApi.home() has no payload configured.');
    return homePayload!;
  }

  @override
  Future<Devotional> devotion(String id) async => sampleHome().devotion!;

  /// What `/devotions/` answers: the devotionals the ministry publishes on
  /// their own, newest first, which is what the Devotions tab opens on.
  List<Devotional> devotionalRows = sampleDevotionalFeed();
  int devotionalCalls = 0;

  @override
  Future<List<Devotional>> devotionals() async {
    devotionalCalls++;
    if (failure != null) throw failure!;
    return devotionalRows;
  }

  @override
  Future<Article> article(String id) async => sampleHome().articles.first;

  @override
  Future<int> contentVersion() async {
    contentVersionCalls++;
    if (failure != null) throw failure!;
    return contentVersionValue;
  }

  @override
  Future<List<DevotionSeries>> devotionSeries() async {
    seriesCalls++;
    if (failure != null) throw failure!;
    return seriesRows;
  }

  @override
  Future<DevotionSeries> devotionSeriesDetail(String id) async {
    seriesDetailCalls++;
    if (failure != null) throw failure!;
    if (seriesDetail == null) {
      throw StateError('FakeUdmApi has no series detail configured.');
    }
    return seriesDetail!;
  }

  @override
  Future<List<ResourceTopic>> resourceTopics() async {
    resourceTopicCalls++;
    if (failure != null) throw failure!;
    return resourceTopicRows;
  }

  @override
  Future<ResourceTopic> resourceTopicDetail(String id) async {
    if (failure != null) throw failure!;
    if (resourceTopicRow == null) {
      throw StateError('FakeUdmApi has no resource guide detail configured.');
    }
    return resourceTopicRow!;
  }

  @override
  Future<ResourceStep> resourceStep(String id) async {
    resourceStepCalls++;
    if (failure != null) throw failure!;
    if (resourceStepRow == null)
      throw StateError('FakeUdmApi has no resource step configured.');
    return resourceStepRow!;
  }

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async => _session();

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String fullName,
    String? photoPath,
    String? photoName,
  }) async => _session();

  Session _session() {
    if (authFailure != null) throw authFailure!;
    if (session == null)
      throw StateError('FakeUdmApi has no session configured.');
    return session!;
  }

  @override
  Future<void> signOut({required String refresh}) async {
    if (authFailure != null) throw authFailure!;
    revokedRefresh = refresh;
  }

  @override
  Future<UserProfile> profile() async {
    profileCalls++;
    if (authFailure != null) throw authFailure!;
    if (serverProfile == null)
      throw StateError('FakeUdmApi has no profile configured.');
    return serverProfile!;
  }

  @override
  Future<UserProfile> updateProfile(
    Map<String, dynamic> changes, {
    String? photoPath,
    String? photoName,
  }) async {
    if (authFailure != null) throw authFailure!;
    if (serverProfile == null)
      throw StateError('FakeUdmApi has no profile configured.');
    lastProfilePatch = changes;
    lastPhotoPath = photoPath;
    lastPhotoName = photoName;
    serverProfile = UserProfile.fromJson({
      ...serverProfile!.toJson(),
      ...changes,
    });
    return serverProfile!;
  }

  @override
  Future<void> markComplete({
    required String kind,
    required String contentId,
    String? note,
  }) async {
    if (authFailure != null) throw authFailure!;
    completions.add('$kind:$contentId');
  }

  // --- the Learn tab -------------------------------------------------------
  List<MediaCollection> mediaShelves = sampleMediaShelves();
  MediaCollection? mediaShelfRow;
  MediaItem? mediaItemRow;
  Failure? mediaFailure;

  /// What the app tried to store privately, in order.
  final List<({String id, String text})> mediaNotes = [];
  final List<({String id, int positionSeconds, bool completed})> mediaWatches =
      [];

  void _failMedia() {
    if (mediaFailure != null) throw mediaFailure!;
  }

  @override
  Future<List<MediaCollection>> mediaCollections() async {
    _failMedia();
    return mediaShelves;
  }

  @override
  Future<MediaCollection> mediaCollection(String id) async {
    _failMedia();
    if (mediaShelfRow == null) {
      throw StateError('FakeUdmApi has no shelf configured.');
    }
    return mediaShelfRow!;
  }

  @override
  Future<MediaItem> mediaItem(String id) async {
    _failMedia();
    if (mediaItemRow == null) {
      throw StateError('FakeUdmApi has no recording configured.');
    }
    return mediaItemRow!;
  }

  @override
  Future<Map<String, dynamic>> saveMediaNote(String itemId, String text) async {
    _failMedia();
    mediaNotes.add((id: itemId, text: text));
    return {
      'text': text,
      'updated_at': text.isEmpty
          ? null
          : DateTime.utc(2026, 11, 12, 15).toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> saveMediaWatch(
    String itemId, {
    required int positionSeconds,
    required bool completed,
  }) async {
    _failMedia();
    mediaWatches.add((
      id: itemId,
      positionSeconds: positionSeconds,
      completed: completed,
    ));
    return {'position_seconds': positionSeconds, 'completed': completed};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Everything the shell's five tabs ask for at once, including the Bible
/// reader, so a test can host the whole app without a network. Anything the
/// shell does not render is left to `noSuchMethod`, which fails loudly instead
/// of silently answering with null.
class FakeShellApi with FakeNotifications implements UdmApi {
  int contentVersionCalls = 0;

  @override
  Future<int> contentVersion() async {
    contentVersionCalls++;
    return 3;
  }

  @override
  Future<HomePayload> home() async => sampleHome();

  @override
  Future<List<DevotionSeries>> devotionSeries() async => sampleSeriesGrid();

  @override
  Future<List<Devotional>> devotionals() async => sampleDevotionalFeed();

  @override
  Future<List<ResumeItem>> mediaResume() async => const [];

  @override
  Future<DevotionSeries> devotionSeriesDetail(String id) async =>
      sampleSeriesDetail();

  @override
  Future<List<ResourceTopic>> resourceTopics() async => sampleResourceTopics();

  @override
  Future<List<MediaCollection>> mediaCollections() async =>
      sampleMediaShelves();

  @override
  Future<List<Map<String, dynamic>>> bibleTranslations({
    String language = 'en',
  }) async => const [
    {
      'id': 't1',
      'code': 'kjv',
      'name': 'King James Version',
      'offline_allowed': true,
      'attribution': 'King James Version (public domain).',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> bibleBooks(String code) async => const [
    {
      'id': 'b1',
      'name': 'John',
      'provider_id': 'JHN',
      'order': 43,
      'testament': 'new',
      'chapter_count': 21,
    },
  ];

  @override
  Future<List<int>> bibleBookChapters(String code, String book) async => const [
    1,
  ];

  @override
  Future<Map<String, dynamic>> bibleChapter(
    String code,
    String book,
    int chapter,
  ) async => const {
    'id': 'c1',
    'book': 'John',
    'number': 1,
    'translation': 'kjv',
    'verses': [
      {'id': 'v1', 'verse': 1, 'text': 'In the beginning was the Word.'},
    ],
  };

  @override
  Future<List<Map<String, dynamic>>> biblePassageSources() async => const [
    {
      'code': 'kjv',
      'name': 'King James Version',
      'text_available': true,
      'offline_allowed': true,
      'configured': true,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> biblePlans() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({this.payload, this.failure, this.memorizeFailure});

  HomePayload? payload;
  Failure? failure;
  Failure? memorizeFailure;
  int loadCalls = 0;

  /// Verses the student pressed "Mark memorized" on, in the order the app was
  /// asked to send them.
  final List<String> memorized = [];

  /// The private rows under the public feed. Empty is the anonymous answer, and
  /// the screen reads an empty list as no section at all.
  List<ResumeItem> started = const [];
  List<ReadHistoryRow> finished = const [];

  /// The account's own numbers, as `/progress/summary/` answers them.
  WalkSummary numbers = const WalkSummary();
  Failure? summaryFailure;
  int summaryCalls = 0;
  int historyCalls = 0;

  @override
  Future<HomePayload> load() async {
    loadCalls++;
    if (failure != null) throw failure!;
    if (payload == null)
      throw StateError('FakeHomeRepository has no payload configured.');
    return payload!;
  }

  @override
  Future<void> markVerseMemorized(String verseId) async {
    if (memorizeFailure != null) throw memorizeFailure!;
    memorized.add(verseId);
  }

  /// Plan days the student marked read, in the order the app was asked.
  final List<String> readingsRead = [];
  Failure? readingFailure;

  @override
  Future<void> markReadingFinished(String assignmentId) async {
    if (readingFailure != null) throw readingFailure!;
    readingsRead.add(assignmentId);
  }

  @override
  Future<List<ResumeItem>> resume() async => started;

  @override
  Future<List<ReadHistoryRow>> history() async {
    historyCalls++;
    if (failure != null) throw failure!;
    return finished;
  }

  @override
  Future<WalkSummary> summary() async {
    summaryCalls++;
    if (summaryFailure != null) throw summaryFailure!;
    return numbers;
  }

  @override
  HomePayload? cached() => null;

  @override
  Future<void> clearCache() async {}
}

/// A session standing where the test needs it, without a restore round trip:
/// a controller only ever asks it whether the student is signed in.
SessionController fakeSession({bool signedIn = false}) {
  final client = ApiClient(
    dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1/api/v1')),
    tokenStore: InMemoryTokenStore(),
  );
  final session = SessionController(
    FakeAuthRepository(
      profile: signedIn ? sampleProfile() : null,
      hasSessionValue: signedIn,
    ),
    client,
  );
  session.status.value = signedIn
      ? SessionStatus.signedIn
      : SessionStatus.signedOut;
  return session;
}

/// A signed-in student exactly as `GET /api/v1/users/me/` answers for one whose
/// onboarding answers are still blank.
UserProfile sampleProfile() => const UserProfile(
  email: 'grace@udm.ac.ug',
  displayName: 'Grace Nabukeera',
  fullName: 'Grace Nabukeera',
  preferredTranslationCode: 'kjv',
);

Session sampleSession({String refresh = 'stored-refresh'}) => Session(
  tokens: StoredTokens(access: 'fresh-access', refresh: refresh),
  user: const AuthUser(
    id: 'u1',
    email: 'grace@udm.ac.ug',
    displayName: 'Grace Nabukeera',
    emailVerified: false,
  ),
);

/// Stands in for the keystore so session tests never touch a platform channel.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  StoredTokens? _tokens;

  int clears = 0;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async {
    clears++;
    _tokens = null;
  }
}

/// Session state the screens can be driven against, without a network or a
/// keystore.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.profile, this.hasSessionValue = false});

  UserProfile? profile;
  bool hasSessionValue;

  /// Thrown by sign-in, registration, restore and save.
  Failure? failure;

  /// False models an offline sign-out: forgotten locally, not revoked remotely.
  bool revokeSucceeds = true;

  int signInCalls = 0;
  int registerCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;
  Map<String, dynamic>? savedChanges;

  /// The picture a save carried, when it carried one.
  XFile? savedPhoto;

  @override
  Future<bool> hasSession() async => hasSessionValue;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return _result();
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
    XFile? photo,
  }) async {
    registerCalls++;
    return _result();
  }

  @override
  Future<UserProfile?> restore() async {
    restoreCalls++;
    return hasSessionValue ? _result() : null;
  }

  @override
  Future<UserProfile> save(UserProfile draft, {XFile? photo}) async {
    savedChanges = draft.patchPayload();
    savedPhoto = photo;
    profile = draft;
    return _result();
  }

  @override
  Future<bool> signOut() async {
    signOutCalls++;
    hasSessionValue = false;
    profile = null;
    return revokeSucceeds;
  }

  @override
  Future<void> forget() async => hasSessionValue = false;

  @override
  UserProfile? cachedProfile() => profile;

  Future<UserProfile> _result() async {
    if (failure != null) throw failure!;
    if (profile == null)
      throw StateError('FakeAuthRepository has no profile configured.');
    return profile!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeContentRepository implements ContentRepository {
  FakeContentRepository({
    this.serverDevotional,
    this.serverStep,
    this.serverArticle,
    this.serverArticles = const [],
  });

  Devotional? serverDevotional;
  ResourceStep? serverStep;
  Article? serverArticle;
  List<Article> serverArticles;
  Failure? failure;
  Failure? progressFailure;
  final List<String> completions = [];

  @override
  Future<Devotional> devotional(String id) async {
    if (failure != null) throw failure!;
    if (serverDevotional == null)
      throw StateError('FakeContentRepository has no devotional configured.');
    return serverDevotional!;
  }

  @override
  Future<ResourceStep> resourceStep(String id) async {
    if (failure != null) throw failure!;
    if (serverStep == null)
      throw StateError(
        'FakeContentRepository has no resource step configured.',
      );
    return serverStep!;
  }

  @override
  Future<Article> article(String id) async {
    if (failure != null) throw failure!;
    if (serverArticle == null)
      throw StateError('FakeContentRepository has no article configured.');
    return serverArticle!;
  }

  @override
  Future<List<Article>> articles() async {
    if (failure != null) throw failure!;
    return serverArticles;
  }

  @override
  Future<void> recordCompletion({
    required ContentKind kind,
    required String id,
  }) async {
    if (progressFailure != null) throw progressFailure!;
    completions.add('${kind.value}:$id');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// The stamp every content screen looks up when it initialises. Polling is
/// turned off and replaced by [emit], so a test decides exactly when a ministry
/// edit lands rather than waiting on a request.
class FakeContentVersionController extends ContentVersionController {
  FakeContentVersionController() : super(FakeUdmApi());

  void emit(int version) => known.value = version;

  @override
  Future<void> poll() async {}
}

class FakeDevotionsRepository implements DevotionsRepository {
  FakeDevotionsRepository({
    this.gridRows = const [],
    this.seriesRow,
    this.cachedRows,
    this.devotionalRows = const [],
    this.cachedDevotionalRows,
    this.failure,
  });

  List<DevotionSeries> gridRows;
  DevotionSeries? seriesRow;

  /// What `/devotions/` answers: the day's reading and the ones behind it.
  List<Devotional> devotionalRows;
  List<Devotional>? cachedDevotionalRows;

  /// What this device saved on an earlier visit.
  List<DevotionSeries>? cachedRows;

  Failure? failure;
  int gridCalls = 0;
  int devotionalCalls = 0;

  @override
  Future<List<DevotionSeries>> grid() async {
    gridCalls++;
    if (failure != null) {
      if (cachedRows != null) return cachedRows!;
      throw failure!;
    }
    return gridRows;
  }

  @override
  Future<List<Devotional>> devotionals() async {
    devotionalCalls++;
    if (failure != null) {
      if (cachedDevotionalRows != null) return cachedDevotionalRows!;
      throw failure!;
    }
    return devotionalRows;
  }

  @override
  Future<DevotionSeries> series(String id) async {
    if (failure != null) {
      if (seriesRow != null && seriesRow!.fromCache) return seriesRow!;
      throw failure!;
    }
    if (seriesRow == null)
      throw StateError('FakeDevotionsRepository has no series configured.');
    return seriesRow!;
  }

  @override
  List<DevotionSeries>? cachedGrid() => cachedRows;

  @override
  List<Devotional>? cachedDevotionals() => cachedDevotionalRows;

  @override
  DevotionSeries? cachedSeries(String id) =>
      seriesRow != null && seriesRow!.fromCache ? seriesRow : null;
}

/// The Learn tab's repository, with the private half of a recording kept in
/// plain lists a test can read back.
class FakeMediaRepository implements MediaRepository {
  FakeMediaRepository({
    this.shelfRows = const [],
    this.shelfRow,
    this.itemRow,
    this.cachedShelfRows,
    this.failure,
    this.noteFailure,
    this.watchFailure,
  });

  List<MediaCollection> shelfRows;
  MediaCollection? shelfRow;
  MediaItem? itemRow;

  /// What this device saved on an earlier visit.
  List<MediaCollection>? cachedShelfRows;

  Failure? failure;
  Failure? noteFailure;
  Failure? watchFailure;
  int shelvesCalls = 0;

  /// What the student's own account says they stopped partway through.
  List<ResumeItem> resumeRows = const [];
  int resumeCalls = 0;

  /// Every note and every place the app tried to save, in order.
  final List<({String id, String text})> savedNotes = [];
  final List<({String id, int positionSeconds, bool completed})> savedWatches =
      [];

  @override
  Future<List<MediaCollection>> shelves() async {
    shelvesCalls++;
    if (failure != null) {
      if (cachedShelfRows != null) return cachedShelfRows!;
      throw failure!;
    }
    return shelfRows;
  }

  @override
  Future<MediaCollection> shelf(String id) async {
    if (failure != null) {
      if (shelfRow != null && shelfRow!.fromCache) return shelfRow!;
      throw failure!;
    }
    if (shelfRow != null) return shelfRow!;
    // A shelf the tab just listed is readable by its own id — that is how the
    // Learn heading fetches the featured shelf's recordings. Only an id this
    // fake was never given anything about is the mistake it reports.
    for (final row in shelfRows) {
      if (row.id == id) return row;
    }
    throw StateError('FakeMediaRepository has no shelf configured.');
  }

  @override
  Future<MediaItem> item(String id) async {
    if (failure != null) {
      if (itemRow != null && itemRow!.fromCache) return itemRow!;
      throw failure!;
    }
    if (itemRow == null)
      throw StateError('FakeMediaRepository has no recording configured.');
    return itemRow!;
  }

  @override
  Future<({String text, DateTime? updatedAt})> saveNote(
    String id,
    String text,
  ) async {
    if (noteFailure != null) throw noteFailure!;
    savedNotes.add((id: id, text: text));
    return (
      text: text,
      updatedAt: text.isEmpty ? null : DateTime.utc(2026, 11, 12, 15),
    );
  }

  @override
  Future<({int positionSeconds, bool completed})> saveWatch(
    String id, {
    required int positionSeconds,
    required bool completed,
  }) async {
    if (watchFailure != null) throw watchFailure!;
    savedWatches.add((
      id: id,
      positionSeconds: positionSeconds,
      completed: completed,
    ));
    return (positionSeconds: positionSeconds, completed: completed);
  }

  @override
  Future<List<ResumeItem>> resume() async {
    resumeCalls++;
    if (failure != null) throw failure!;
    return resumeRows;
  }

  @override
  List<MediaCollection>? cachedShelves() => cachedShelfRows;

  @override
  MediaCollection? cachedShelf(String id) =>
      shelfRow != null && shelfRow!.fromCache ? shelfRow : null;

  @override
  MediaItem? cachedItem(String id) =>
      itemRow != null && itemRow!.fromCache ? itemRow : null;
}

class FakeResourcesRepository implements ResourcesRepository {
  FakeResourcesRepository({
    this.topicRows = const [],
    this.topicRow,
    this.cachedTopicRows,
    this.cachedTopicRow,
    this.failure,
  });

  List<ResourceTopic> topicRows;
  ResourceTopic? topicRow;

  /// What this device saved on an earlier visit.
  List<ResourceTopic>? cachedTopicRows;
  ResourceTopic? cachedTopicRow;

  Failure? failure;

  /// How often the list of guides was asked for, as against one guide opened.
  int topicsCalls = 0;
  int topicCalls = 0;

  @override
  Future<List<ResourceTopic>> topics() async {
    topicsCalls++;
    if (failure != null) {
      if (cachedTopicRows != null) return cachedTopicRows!;
      throw failure!;
    }
    return topicRows;
  }

  @override
  Future<ResourceTopic> topic(String id) async {
    topicCalls++;
    if (failure != null) {
      if (cachedTopicRow != null) return cachedTopicRow!;
      throw failure!;
    }
    if (topicRow == null)
      throw StateError('FakeResourcesRepository has no guide configured.');
    return topicRow!;
  }

  @override
  List<ResourceTopic>? cachedTopics() => cachedTopicRows;

  @override
  ResourceTopic? cachedTopic(String id) =>
      cachedTopicRow?.id == id ? cachedTopicRow : null;

  @override
  Future<int> registerView(String id) async {
    if (failure != null) throw failure!;
    return 1;
  }

  @override
  Future<Uint8List> downloadPdf(String url) async {
    if (failure != null) throw failure!;
    return Uint8List(0);
  }

  @override
  Future<List<ResourceStep>> newBelieverSteps() async {
    if (failure != null) throw failure!;
    return const [];
  }
}

/// The device looks every reading screen now asks for: light or dark, and how
/// large the text is. Registered permanently, the way the app registers it
/// before the first frame, because a screen that reads a preference has no
/// business inventing one.
AppearanceController putAppearance(LocalCache cache) =>
    Get.put(AppearanceController(SettingsRepository(cache)), permanent: true);

/// The inbox controller home's bell and the notifications screen read.
/// `configureDependencies()` puts it permanently in the real app; a widget test
/// hosts its screens without that pass, so it puts the same object here, wired
/// to whatever API and session the test already registered.
NotificationsController putNotifications({
  UdmApi? api,
  SessionController? session,
}) {
  final resolvedApi =
      api ?? (Get.isRegistered<UdmApi>() ? Get.find<UdmApi>() : FakeUdmApi());
  final resolvedSession =
      session ??
      (Get.isRegistered<SessionController>()
          ? Get.find<SessionController>()
          : fakeSession());
  return Get.put<NotificationsController>(
    NotificationsController(resolvedApi, resolvedSession),
    permanent: true,
  );
}
