import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/modules/content_version/content_version_controller.dart';

import '../support/fakes.dart';

/// A screen that records the stamp its data carries, the way Home and the
/// Devotions grid do after reading their repository.
class _PayloadStampedScreen extends GetxController with RefetchesOnContentChange {
  _PayloadStampedScreen({this.stamp});

  /// The version of whatever this screen is showing; null until it is set.
  int? stamp;
  int loads = 0;

  @override
  Future<void> load() async {
    loads++;
    stampLoadedContent(stamp);
  }
}

/// A screen that has no stamp of its own, so it takes the number the server was
/// on a moment ago — the Bible and Learn tabs.
class _CurrentStampedScreen extends GetxController with RefetchesOnContentChange {
  int loads = 0;

  @override
  Future<void> load() async {
    loads++;
    stampCurrentContent();
  }
}

void main() {
  late FakeUdmApi api;

  setUp(() {
    Get.testMode = true;
    api = FakeUdmApi()..contentVersionValue = 7;
  });

  tearDown(Get.reset);

  /// Puts the stamp controller first, because a screen subscribes to it while
  /// it initialises.
  ContentVersionController putVersions() =>
      Get.put<ContentVersionController>(ContentVersionController(api), permanent: true);

  test('the stamp is unknown until the server answers', () async {
    final versions = putVersions();

    expect(versions.known.value, isNull);
    await versions.poll();
    expect(versions.known.value, 7);
  });

  test('an offline poll keeps the last number seen', () async {
    final versions = putVersions();
    await versions.poll();

    api
      ..contentVersionValue = 9
      ..failure = const Failure(FailureKind.offline, 'No connection');
    await versions.poll();

    expect(versions.known.value, 7);
  });

  test('a screen that fetched before the first stamp adopts it without refetching', () async {
    final versions = putVersions();
    final screen = _PayloadStampedScreen();
    Get.put(screen);

    // The launch order the app really has: the feed is already on screen while
    // the version request is still on its way.
    await screen.load();
    await versions.poll();

    expect(screen.loads, 1);
    expect(screen.loadedUnder.value, 7);
  });

  test('a ministry edit reaches a screen that is already open', () async {
    final versions = putVersions();
    await versions.poll();
    final screen = _PayloadStampedScreen(stamp: 7);
    Get.put(screen);
    await screen.load();
    expect(screen.loads, 1);

    // A worker saves a devotion: the number moves, so does the screen.
    api.contentVersionValue = 8;
    await versions.poll();

    expect(screen.loads, 2);
  });

  test('the same number twice does not set the app refetching', () async {
    final versions = putVersions();
    final screen = _PayloadStampedScreen(stamp: 7);
    Get.put(screen);
    await versions.poll();
    await screen.load();

    await versions.poll();
    await versions.poll();

    expect(screen.loadedUnder.value, 7);
    expect(screen.loads, 1);
    // One request per poll: the number travels, the library does not.
    expect(api.contentVersionCalls, 4);
  });

  test('a screen that read an older copy refetches the moment the server moves', () async {
    api.contentVersionValue = 4;
    final versions = putVersions();
    // The student read this grid on Thursday, when the library was on 4.
    final screen = _PayloadStampedScreen(stamp: 4);
    Get.put(screen);
    await screen.load();
    await versions.poll();

    expect(screen.loads, 1);
    expect(screen.loadedUnder.value, 4);

    // Monday: the ministry has published, and these are the rows the device
    // takes in when it reloads.
    screen.stamp = 11;
    api.contentVersionValue = 11;
    await versions.poll();

    expect(screen.loads, 2);
    expect(screen.loadedUnder.value, 11);

    // It settles there: one edit, one reload.
    await versions.poll();
    expect(screen.loads, 2);
  });

  test('a tab with no stamp of its own follows the server number', () async {
    final versions = putVersions();
    await versions.poll();
    final screen = _CurrentStampedScreen();
    Get.put(screen);
    await screen.load();

    expect(screen.loadedUnder.value, 7);

    api.contentVersionValue = 9;
    await versions.poll();

    expect(screen.loads, 2);
    expect(screen.loadedUnder.value, 9);
  });

  test('the poller publishes only a change', () async {
    final versions = putVersions();
    final seen = <int?>[];
    ever(versions.known, seen.add);

    await versions.poll();
    await versions.poll();
    api.contentVersionValue = 8;
    await versions.poll();

    expect(seen, [7, 8]);
  });
}
