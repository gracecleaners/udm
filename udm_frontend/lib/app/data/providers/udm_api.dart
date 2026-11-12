import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/auth_interceptor.dart';
import '../models/article.dart';
import '../models/devotion_series.dart';
import '../models/devotional.dart';
import '../models/home_payload.dart';
import '../models/media_collection.dart';
import '../models/media_item.dart';
import '../models/resource_step.dart';
import '../models/resource_topic.dart';
import '../models/session.dart';
import '../models/user_profile.dart';

/// Typed surface of the UDM v1 API. Controllers never call Dio directly.
class UdmApi {
  UdmApi(this._client);

  final ApiClient _client;

  Future<HomePayload> home() => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/home/');
    return HomePayload.fromJson(_json(response));
  });

  /// The server's own change counter. One integer, so an app that has been in
  /// the background can ask whether anything moved before it refetches
  /// everything the student was reading.
  Future<int> contentVersion() => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/content-version/');
    final version = _json(response)['version'];
    if (version is! num) throw const FormatException('Expected a content version.');
    return version.toInt();
  });

  /// The Devotions tab: every series with at least one day a student can read.
  Future<List<DevotionSeries>> devotionSeries() async =>
      (await _list('/devotions/series/')).map(DevotionSeries.fromJson).toList();

  Future<DevotionSeries> devotionSeriesDetail(String id) =>
      _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/devotions/series/$id/');
        return DevotionSeries.fromJson(_json(response));
      });

  Future<Devotional> devotion(String id) => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/devotions/$id/');
    return Devotional.fromJson(_json(response));
  });

  Future<Article> article(String id) => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/articles/$id/');
    return Article.fromJson(_json(response));
  });

  /// The home "Find resources on" list: only guides with a step to read.
  Future<List<ResourceTopic>> resourceTopics() async =>
      (await _list('/resources/')).map(ResourceTopic.fromJson).toList();

  Future<ResourceTopic> resourceTopicDetail(String id) =>
      _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/resources/$id/');
        return ResourceTopic.fromJson(_json(response));
      });

  Future<ResourceStep> resourceStep(String id) => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/resources/steps/$id/');
    return ResourceStep.fromJson(_json(response));
  });

  /// The Learn tab: every shelf with a recording a student can open.
  Future<List<MediaCollection>> mediaCollections() async =>
      (await _list('/media/')).map(MediaCollection.fromJson).toList();

  Future<MediaCollection> mediaCollection(String id) => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/media/$id/');
    return MediaCollection.fromJson(_json(response));
  });

  /// One recording, with this student's own note and place in it attached.
  Future<MediaItem> mediaItem(String id) => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/media/items/$id/');
    return MediaItem.fromJson(_json(response));
  });

  /// The student's note on a recording. Sending blank text deletes it, which is
  /// why there is no separate remove call.
  Future<Map<String, dynamic>> saveMediaNote(String itemId, String text) =>
      _client.guard(() async {
        final response = await _client.dio.put<dynamic>(
          '/media/items/$itemId/note/',
          data: {'text': text},
        );
        return _json(response);
      });

  Future<Map<String, dynamic>> saveMediaWatch(
    String itemId, {
    required int positionSeconds,
    required bool completed,
  }) => _client.guard(() async {
    final response = await _client.dio.put<dynamic>(
      '/media/items/$itemId/watch/',
      data: {'position_seconds': positionSeconds, 'completed': completed},
    );
    return _json(response);
  });

  Future<List<Map<String, dynamic>>> bibleTranslations({String language = 'en'}) =>
      _list('/bible/translations/?language=$language');
  Future<List<Map<String, dynamic>>> bibleBooks(String code) =>
      _list('/bible/$code/books/');
  Future<List<int>> bibleBookChapters(String code, String book) =>
      _client.guard(() async {
        final response = await _client.dio.get<dynamic>(
          '/bible/$code/${Uri.encodeComponent(book)}/chapters/',
        );
        final data = response.data;
        if (data is! List) throw StateError('Expected Bible chapter numbers.');
        return data.whereType<num>().map((value) => value.toInt()).toList();
      });
  Future<Map<String, dynamic>> bibleChapter(
    String code,
    String book,
    int chapter,
  ) => _client.guard(() async {
    final response = await _client.dio.get<dynamic>(
      '/bible/$code/${Uri.encodeComponent(book)}/$chapter/',
    );
    return _json(response);
  });
  Future<List<Map<String, dynamic>>> biblePlans() => _list('/bible/plans/');

  /// One passage by reference, from whichever source this deployment may use.
  /// The server normalizes the spelling and never fails the request because a
  /// licensed source is unavailable: it answers with public-domain text plus
  /// `deep_link_url` and a `fallback` note instead.
  Future<Map<String, dynamic>> biblePassage(
    String reference, {
    String? translation,
  }) => _client.guard(() async {
    final query = <String, String>{'reference': reference};
    if (translation != null && translation.isNotEmpty) {
      query['translation'] = translation;
    }
    final response = await _client.dio.get<dynamic>(
      '/bible/passage/',
      queryParameters: query,
    );
    return _json(response);
  });

  /// The routing matrix: what this backend can print, and what it can only
  /// hand to an authorized site.
  Future<List<Map<String, dynamic>>> biblePassageSources() =>
      _client.guard(() async {
        final response = await _client.dio.get<dynamic>('/bible/sources/');
        final data = response.data;
        if (data is! Map<String, dynamic> || data['results'] is! List) {
          throw const FormatException('Expected a list of Bible sources.');
        }
        return (data['results'] as List).cast<Map<String, dynamic>>();
      });
  Future<void> addBibleBookmark(String verseId) => _client.guard(() async {
    await _client.dio.post<dynamic>(
      '/bible/bookmarks/',
      data: {'verse_id': verseId},
    );
  });
  Future<void> removeBibleBookmark(String id) => _client.guard(() async {
    await _client.dio.delete<dynamic>('/bible/bookmarks/$id/');
  });
  Future<List<Map<String, dynamic>>> bibleBookmarks() =>
      _list('/bible/bookmarks/');
  Future<List<Map<String, dynamic>>> bibleNotes() => _list('/bible/notes/');
  Future<void> saveBibleNote(String verseId, String body) =>
      _client.guard(() async {
        await _client.dio.post<dynamic>(
          '/bible/notes/',
          data: {'verse_id': verseId, 'body': body},
        );
      });
  Future<void> updateBibleNote(String id, String body) =>
      _client.guard(() async {
        await _client.dio.patch<dynamic>(
          '/bible/notes/$id/',
          data: {'body': body},
        );
      });
  Future<void> removeBibleNote(String id) => _client.guard(() async {
    await _client.dio.delete<dynamic>('/bible/notes/$id/');
  });
  Future<void> completeBibleAssignment(String assignmentId) =>
      _client.guard(() async {
        await _client.dio.post<dynamic>(
          '/bible/reading-progress/',
          data: {'assignment': assignmentId},
        );
      });
  Future<void> reviewMemoryVerse(String id) => _client.guard(() async {
    await _client.dio.post<dynamic>(
      '/memory-verses/progress/',
      data: {'memory_verse': id},
    );
  });

  Future<List<Map<String, dynamic>>> universities() => _list('/universities/');
  Future<List<Map<String, dynamic>>> campuses() => _list('/campuses/');
  Future<List<Map<String, dynamic>>> fellowships() => _list('/fellowships/');
  Future<List<Map<String, dynamic>>> discipleshipGroups() => _list('/groups/');
  Future<List<Map<String, dynamic>>> myGroupMemberships() =>
      _list('/groups/memberships/');
  Future<List<Map<String, dynamic>>> groupJoinRequests(String groupId) =>
      _list('/groups/$groupId/join-requests/');
  Future<Map<String, dynamic>> requestGroupMembership(String groupId) =>
      _client.guard(() async {
        final response = await _client.dio.post<dynamic>(
          '/groups/$groupId/join/',
        );
        return _json(response);
      });
  Future<Map<String, dynamic>> decideGroupMembership(
    String groupId,
    String membershipId,
    String status,
  ) => _client.guard(() async {
    final response = await _client.dio.patch<dynamic>(
      '/groups/$groupId/memberships/$membershipId/',
      data: {'status': status},
    );
    return _json(response);
  });
  Future<List<Map<String, dynamic>>> events() => _list('/events/');
  Future<void> registerForEvent(String eventId) => _client.guard(() async {
    await _client.dio.post<dynamic>('/events/$eventId/register/');
  });
  Future<List<Map<String, dynamic>>> prayerRequests() => _list('/prayers/');
  Future<void> createPrayerRequest({
    required String body,
    required String visibility,
    String? groupId,
    required bool shareConsent,
  }) => _client.guard(() async {
    await _client.dio.post<dynamic>(
      '/prayers/',
      data: {
        'body': body,
        'visibility': visibility,
        'group': ?groupId,
        'share_consent': shareConsent,
      },
    );
  });
  Future<void> deletePrayerRequest(String id) => _client.guard(() async {
    await _client.dio.delete<dynamic>('/prayers/$id/');
  });
  Future<List<Map<String, dynamic>>> groupPrayerQueue(String groupId) =>
      _list('/groups/$groupId/prayer/');
  Future<void> moderateGroupPrayer(
    String groupId,
    String prayerId,
    String decision,
  ) => _client.guard(() async {
    await _client.dio.patch<dynamic>(
      '/groups/$groupId/prayer/$prayerId/',
      data: {'moderation_state': decision},
    );
  });

  Future<List<Map<String, dynamic>>> _list(String path) =>
      _client.guard(() async {
        var response = await _client.dio.get<dynamic>(path);
        final rows = <Map<String, dynamic>>[];
        final base = Uri.parse(_client.baseUrl);
        final apiPath = base.path.endsWith('/') ? base.path : '${base.path}/';
        final seen = <String>{};
        while (true) {
          final data = response.data;
          if (data is List) {
            rows.addAll(data.cast<Map<String, dynamic>>());
            return rows;
          }
          if (data is! Map<String, dynamic> || data['results'] is! List) {
            throw const FormatException('Expected a list from the API.');
          }
          rows.addAll((data['results'] as List).cast<Map<String, dynamic>>());
          final next = data['next'];
          if (next == null) return rows;
          if (next is! String || !seen.add(next)) {
            throw const FormatException(
              'The API returned an invalid pagination link.',
            );
          }
          final nextUri = base.resolve(next);
          if (nextUri.origin != base.origin ||
              !nextUri.path.startsWith(apiPath)) {
            throw const FormatException(
              'The API returned an unsafe pagination link.',
            );
          }
          response = await _client.dio.getUri<dynamic>(nextUri);
        }
      });

  /// Sign-in and registration are public endpoints: an expired token sitting in
  /// storage must not turn them into a refresh-and-retry loop.
  Future<Session> signIn({required String email, required String password}) =>
      _session('/auth/token/', {'email': email, 'password': password});

  Future<Session> register({
    required String email,
    required String password,
    required String fullName,
  }) => _session('/auth/register/', {
    'email': email,
    'password': password,
    'full_name': fullName,
  });

  /// Revokes the refresh token server-side. Called with the stored token, which
  /// is why logout still needs the bearer header.
  Future<void> signOut({required String refresh}) => _client.guard(() async {
    await _client.dio.post<dynamic>(
      '/auth/token/logout/',
      data: {'refresh': refresh},
    );
  });

  Future<UserProfile> profile() => _client.guard(() async {
    final response = await _client.dio.get<dynamic>('/users/me/');
    return UserProfile.fromJson(_json(response));
  });

  /// Partial update, so a form that only changed two fields does not blank the
  /// rest by omission.
  Future<UserProfile> updateProfile(Map<String, dynamic> changes) =>
      _client.guard(() async {
        final response = await _client.dio.patch<dynamic>(
          '/users/me/',
          data: changes,
        );
        return UserProfile.fromJson(_json(response));
      });

  Future<void> markComplete({
    required String kind,
    required String contentId,
    String? note,
  }) => _client.guard(() async {
    await _client.dio.post<dynamic>(
      '/progress/',
      data: {'kind': kind, 'content_id': contentId, 'note': ?note},
    );
  });

  Future<Session> _session(String path, Map<String, dynamic> body) =>
      _client.guard(() async {
        final response = await _client.dio.post<dynamic>(
          path,
          data: body,
          options: Options(extra: {AuthInterceptor.skipAuthKey: true}),
        );
        return Session.fromJson(_json(response));
      });

  Map<String, dynamic> _json(dynamic response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw StateError('Expected a JSON object from the API.');
  }
}
