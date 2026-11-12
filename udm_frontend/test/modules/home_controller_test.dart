import 'package:flutter_test/flutter_test.dart';
import 'package:udm_frontend/app/core/network/failure.dart';
import 'package:udm_frontend/app/core/widgets/state_view.dart';
import 'package:udm_frontend/app/data/models/home_payload.dart';
import 'package:udm_frontend/app/modules/home/home_controller.dart';

import '../support/fakes.dart';

void main() {
  test('a loaded feed becomes ready and is not labelled offline', () async {
    final controller = HomeController(FakeHomeRepository(payload: sampleHome()), fakeSession());
    await controller.load();

    expect(controller.state.value, ViewState.ready);
    expect(controller.data?.devotion?.title, 'A Heart That Listens');
    expect(controller.isOfflineCopy, isFalse);
  });

  test('a day with nothing published shows the empty state', () async {
    final controller = HomeController(
      FakeHomeRepository(payload: const HomePayload(greeting: 'Good evening', articles: [])),
      fakeSession(),
    );
    await controller.load();

    expect(controller.state.value, ViewState.empty);
    expect(controller.data?.isEmpty, isTrue);
  });

  test('a failed request surfaces a readable message', () async {
    final controller = HomeController(
      FakeHomeRepository(failure: const Failure(FailureKind.serverUnavailable, 'The service is down')),
      fakeSession(),
    );
    await controller.load();

    expect(controller.state.value, ViewState.error);
    expect(controller.failureMessage.value, 'The service is down');
  });

  test('a retry clears the previous failure', () async {
    final repository = FakeHomeRepository(failure: const Failure(FailureKind.offline, 'offline'));
    final controller = HomeController(repository, fakeSession());

    await controller.load();
    expect(controller.state.value, ViewState.error);

    repository
      ..failure = null
      ..payload = sampleHome();
    await controller.load();

    expect(controller.state.value, ViewState.ready);
    expect(controller.failureMessage.value, isEmpty);
    expect(repository.loadCalls, 2);
  });

  test('offline copy keeps the content and flags it', () async {
    final controller = HomeController(FakeHomeRepository(payload: sampleHome().asCached()), fakeSession());
    await controller.load();

    expect(controller.state.value, ViewState.ready);
    expect(controller.isOfflineCopy, isTrue);
  });
}
