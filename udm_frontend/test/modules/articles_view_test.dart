import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:udm_frontend/app/core/routes/app_routes.dart';
import 'package:udm_frontend/app/core/theme/app_theme.dart';
import 'package:udm_frontend/app/data/models/article.dart';
import 'package:udm_frontend/app/data/repositories/content_repository.dart';
import 'package:udm_frontend/app/modules/article/articles_controller.dart';
import 'package:udm_frontend/app/modules/article/articles_view.dart';

import '../support/fakes.dart';

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('article library shows published content and filters by category', (tester) async {
    Get.put<ContentRepository>(FakeContentRepository(serverArticles: const [
      Article(id: 'a1', title: 'Everyday Faith', body: 'A short reflection.', category: 'Faith'),
      Article(id: 'a2', title: 'Prayer on Campus', body: 'A guide to prayer.', category: 'Prayer'),
    ]));
    Get.put(ArticlesController(Get.find<ContentRepository>()));

    await tester.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      getPages: [
        GetPage(name: AppRoutes.article, page: () => const Scaffold(body: Text('ARTICLE DETAIL'))),
      ],
      home: const ArticlesView(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Everyday Faith'), findsOneWidget);
    expect(find.text('Latest articles'), findsOneWidget);
    await tester.tap(find.text('Prayer').first);
    await tester.pumpAndSettle();

    expect(find.text('Prayer on Campus'), findsOneWidget);
    expect(find.text('Everyday Faith'), findsNothing);
  });
}
