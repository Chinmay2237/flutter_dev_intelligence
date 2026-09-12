import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Milestone 5 Performance Investigator Tests', () {
    test('FrameTimingSummary calculates correct math and percentiles', () {
      final buildMs = [2.0, 4.0, 6.0, 10.0, 20.0];
      final rasterMs = [3.0, 5.0, 7.0, 12.0, 25.0];

      final summary = FrameTimingSummary.fromDurations(
        buildMs: buildMs,
        rasterMs: rasterMs,
      );

      expect(summary.frameCount, 5);
      expect(summary.averageBuildMs, 8.4);
      expect(summary.averageRasterMs, 10.4);
      expect(summary.maxBuildMs, 20.0);
      expect(summary.maxRasterMs, 25.0);

      // Totals: [5.0, 9.0, 13.0, 22.0, 45.0]
      expect(summary.slowFrameCount, 2); // >16.67ms (22.0, 45.0)
      expect(summary.severeJankFrameCount, 1); // >33.33ms (45.0)
      expect(summary.worstFrameMs, 45.0);
      expect(summary.p50FrameMs, 13.0);
      expect(summary.p90FrameMs, 45.0);

      final json = summary.toJson();
      expect(json['frame_count'], 5);
      expect(json['severe_jank_frame_count'], 1);

      final restored = FrameTimingSummary.fromJson(json);
      expect(restored.frameCount, 5);
      expect(restored.p90FrameMs, 45.0);
    });

    test('Generates evidence-backed recommendations for bottlenecks', () {
      // Clean fast session
      final fastSummary = FrameTimingSummary.fromDurations(
        buildMs: [2.0, 2.0, 2.0],
        rasterMs: [3.0, 3.0, 3.0],
      );
      expect(fastSummary.generateRecommendations(), isEmpty);

      // Build bottleneck session
      final buildSlowSummary = FrameTimingSummary.fromDurations(
        buildMs: [15.0, 18.0, 25.0],
        rasterMs: [2.0, 2.0, 2.0],
      );
      final buildRecs = buildSlowSummary.generateRecommendations();
      expect(buildRecs.map((r) => r.id), contains('perf_build_bottleneck'));

      // Raster bottleneck session
      final rasterSlowSummary = FrameTimingSummary.fromDurations(
        buildMs: [2.0, 2.0, 2.0],
        rasterMs: [15.0, 18.0, 25.0],
      );
      final rasterRecs = rasterSlowSummary.generateRecommendations();
      expect(rasterRecs.map((r) => r.id), contains('perf_raster_bottleneck'));
    });

    test('FrameTimingComparison detects regression between sessions', () {
      final baseline = FrameTimingSummary.fromDurations(
        buildMs: [2.0, 3.0, 4.0],
        rasterMs: [3.0, 3.0, 3.0],
      );

      final currentSlow = FrameTimingSummary.fromDurations(
        buildMs: [10.0, 15.0, 20.0],
        rasterMs: [10.0, 10.0, 15.0],
      );

      final comparison = FrameTimingComparison.compare(
        baseline: baseline,
        current: currentSlow,
      );

      expect(comparison.isRegression, isTrue);
      expect(comparison.p90DeltaMs, greaterThan(0));
      expect(comparison.averageBuildDeltaMs, greaterThan(0));

      final json = comparison.toJson();
      expect(json['is_regression'], isTrue);
    });

    test('FrameTimingSummary.fromJson parses DevTools traceEvents format', () {
      final devToolsJson = {
        'traceEvents': [
          {'name': 'VSYNC', 'dur': 18000},
          {'name': 'GPURasterizer::Draw', 'dur': 12000},
          {'name': 'BuildWidget', 'dur': 22000},
          {'name': 'Rasterizer', 'dur': 15000},
        ],
      };

      final summary = FrameTimingSummary.fromJson(devToolsJson);
      expect(summary.frameCount, 2);
      expect(summary.averageBuildMs, 20.0);
      expect(summary.averageRasterMs, 13.5);
    });

    test('FrameTimingSummary.fromJson parses raw frames list format', () {
      final framesJson = {
        'frames': [
          {'buildMs': 10.0, 'rasterMs': 5.0},
          {'buildMs': 20.0, 'rasterMs': 15.0},
        ],
      };

      final summary = FrameTimingSummary.fromJson(framesJson);
      expect(summary.frameCount, 2);
      expect(summary.averageBuildMs, 15.0);
      expect(summary.averageRasterMs, 10.0);
    });
  });
}
