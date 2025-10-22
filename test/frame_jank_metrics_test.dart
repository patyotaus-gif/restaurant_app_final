import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_app_final/admin/backoffice_schema_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Backoffice schema page stays within frame budget', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final timings = <FrameTiming>[];
    void collectTimings(List<FrameTiming> frameTimings) {
      timings.addAll(frameTimings);
    }

    tester.binding.addTimingsCallback(collectTimings);
    addTearDown(() => tester.binding.removeTimingsCallback(collectTimings));

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BackofficeSchemaPage(),
      ),
    );

    // Allow layout animations to complete.
    await tester.pumpAndSettle();

    // Drive a handful of frames with different durations to simulate user input
    // and capture frame timing metrics.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(timings, isNotEmpty, reason: 'No frame timings were collected');

    double computeRate(Duration Function(FrameTiming) selector) {
      const frameBudget = Duration(milliseconds: 16);
      final framesWithinBudget = timings
          .where((timing) => selector(timing) <= frameBudget)
          .length;
      if (timings.isEmpty) {
        return 0;
      }
      return framesWithinBudget / timings.length * 60;
    }

    double computeAverage(Duration Function(FrameTiming) selector) {
      if (timings.isEmpty) {
        return 0;
      }
      final totalMicros = timings
          .map((timing) => selector(timing).inMicroseconds)
          .reduce((value, element) => value + element);
      return totalMicros / timings.length / 1000;
    }

    expect(
      computeRate((timing) => timing.buildDuration),
      greaterThanOrEqualTo(55),
    );
    expect(
      computeRate((timing) => timing.rasterDuration),
      greaterThanOrEqualTo(55),
    );
    expect(
      computeAverage((timing) => timing.buildDuration),
      lessThan(8),
      reason: 'Build time should stay well below a frame budget',
    );
    expect(
      computeAverage((timing) => timing.rasterDuration),
      lessThan(8),
      reason: 'Rasterizer time should stay well below a frame budget',
    );
  });
}
