import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_app_final/admin/backoffice_schema_page.dart';
import 'package:restaurant_app_final/admin/backoffice_schema_registry.dart';
import 'package:restaurant_app_final/widgets/dynamic_forms/dynamic_form.dart';

const _menuGoldenKey = ValueKey('menu_form_golden');
const _pageGoldenKey = ValueKey('schema_page_golden');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic forms golden tests', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.deferFirstFrame();
    });

    testWidgets('Menu item blueprint renders as expected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final schema = BackofficeSchemaRegistry.instance.schemaById('menu_item')!;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: RepaintBoundary(
                key: _menuGoldenKey,
                child: DynamicForm(
                  schema: schema,
                  initialValues: const {
                    'name': 'Pad Thai with Shrimp',
                    'category': 'mains',
                    'basePrice': 12.5,
                    'isPublished': true,
                    'allergens': 'Contains shellfish and peanuts',
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await _ensureGoldenExists(
        tester,
        find.byKey(_menuGoldenKey),
        'test/goldens/menu_item_form.png',
      );

      await expectLater(
        find.byKey(_menuGoldenKey),
        matchesGoldenFile('goldens/menu_item_form.png'),
      );
    });

    testWidgets('Backoffice schema page layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _pageGoldenKey,
            child: BackofficeSchemaPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _ensureGoldenExists(
        tester,
        find.byKey(_pageGoldenKey),
        'test/goldens/backoffice_schema_page.png',
      );

      await expectLater(
        find.byKey(_pageGoldenKey),
        matchesGoldenFile('goldens/backoffice_schema_page.png'),
      );
    });
  });
}

Future<void> _ensureGoldenExists(
  WidgetTester tester,
  Finder boundaryFinder,
  String path,
) async {
  final file = File(path);
  if (file.existsSync()) {
    return;
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Failed to encode golden for $path');
  }
  await file.parent.create(recursive: true);
  await file.writeAsBytes(byteData.buffer.asUint8List());
}
