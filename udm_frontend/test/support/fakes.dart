import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/data/models/article.dart';
import 'package:udm_frontend/app/data/models/devotional.dart';
import 'package:udm_frontend/app/data/models/featured_verse.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';
import 'package:udm_frontend/app/data/providers/udm_api.dart';
import 'package:udm_frontend/app/data/repositories/home_repository.dart';

/// Test payload shaped exactly like `/api/v1/home/`.
HomePayload sampleHome() => HomePayload(
      greeting: 'Good morning, Grace',
      verse: const FeaturedVerse(
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
      articles: const [Article(id: 'a1', title: 'How to Study a Chapter', body: 'Read once.', category: 'Bible study')],
      serverTime: DateTime.utc(2026, 11, 2, 7, 30),
    );

class FakeUdmApi implements UdmApi {
  HomePayload? homePayload;
  Failure? failure;
  int homeCalls = 0;

  @override
  Future<HomePayload> home() async {
    homeCalls++;
    if (failure != null) throw failure!;
    if (homePayload == null) throw StateError('FakeUdmApi.home() has no payload configured.');
    return homePayload!;
  }

  @override
  Future<Devotional> devotion(String id) async => sampleHome().devotion!;

  @override
  Future<Article> article(String id) async => sampleHome().articles.first;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({this.payload, this.failure});

  HomePayload? payload;
  Failure? failure;
  int loadCalls = 0;

  @override
  Future<HomePayload> load() async {
    loadCalls++;
    if (failure != null) throw failure!;
    if (payload == null) throw StateError('FakeHomeRepository has no payload configured.');
    return payload!;
  }

  @override
  HomePayload? cached() => null;

  @override
  Future<void> clearCache() async {}
}
