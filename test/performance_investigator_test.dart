@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dev_intelligence/flutter_dev_intelligence.dart';

void main() {
  group('Phase 7 — Performance Investigator Hardening', () {
    group('1. Input Validation & Status Handling', () {
      test('handles empty and whitespace string inputs gracefully', () {
        final resultEmpty = PerformanceInputParser.parse('');
        expect(resultEmpty.status, PerformanceAnalysisStatus.emptyInput);
        expect(resultEmpty.isValid, isFalse);

        final resultWhitespace = PerformanceInputParser.parse('   \n\t  ');
        expect(resultWhitespace.status, PerformanceAnalysisStatus.emptyInput);
        expect(resultWhitespace.isValid, isFalse);
      });

      test('handles invalid JSON string without throwing raw exception', () {
        final result = PerformanceInputParser.parse('{ malformed json ...');
        expect(result.status, PerformanceAnalysisStatus.invalidJson);
        expect(result.isValid, isFalse);
        expect(result.limitations.first, contains('Invalid JSON syntax'));
      });

      test('handles unsupported JSON top-level shape gracefully', () {
        final result = PerformanceInputParser.parse(
          '{"foo": "bar", "baz": 123}',
        );
        expect(result.status, PerformanceAnalysisStatus.unsupportedSchema);
        expect(result.isValid, isFalse);
        expect(
          result.warnings.first,
          contains('Unrecognized top-level JSON fields'),
        );
      });

      test('filters invalid numeric values (negative, NaN, Infinity)', () {
        final result = PerformanceInputParser.parse({
          'frames': [
            {'buildMs': -10.0, 'rasterMs': 5.0},
            {'buildMs': 12.0, 'rasterMs': 4.0},
            {'buildMs': 16.0, 'rasterMs': 8.0},
          ],
        });

        expect(result.status, PerformanceAnalysisStatus.valid);
        expect(result.summary, isNotNull);
        expect(result.summary!.frameCount, 2); // Discarded negative frame item
        expect(result.warnings.first, contains('Skipped invalid frame items'));
      });

      test('detects truncated trace with unmatched Begin/End events', () {
        final result = PerformanceInputParser.parse({
          'traceEvents': [
            {'name': 'Build', 'ph': 'B', 'ts': 1000},
            // Missing 'E' event
          ],
        });

        expect(result.status, PerformanceAnalysisStatus.truncatedTrace);
        expect(result.isValid, isFalse);
      });
    });

    group('2. Percentile Calculations & Metrics', () {
      test('computes exact percentiles for known frame distribution', () {
        final build = [2.0, 4.0, 6.0, 8.0, 10.0];
        final raster = [1.0, 2.0, 3.0, 4.0, 5.0];
        // Total durations: 3.0, 6.0, 9.0, 12.0, 15.0

        final summary = FrameTimingSummary.fromDurations(
          buildMs: build,
          rasterMs: raster,
          refreshRateHz: 60.0,
        );

        expect(summary.frameCount, 5);
        expect(summary.minFrameMs, 3.0);
        expect(summary.worstFrameMs, 15.0);
        expect(summary.meanFrameMs, 9.0);
        expect(summary.p50FrameMs, 9.0);
        expect(summary.p75FrameMs, 12.0);
        expect(summary.p90FrameMs, 15.0);
        expect(summary.p95FrameMs, 15.0);
        expect(summary.p99FrameMs, 15.0);
      });

      test('handles single-item frame array correctly', () {
        final summary = FrameTimingSummary.fromDurations(
          buildMs: [8.5],
          rasterMs: [4.2],
          refreshRateHz: 60.0,
        );

        expect(summary.frameCount, 1);
        expect(summary.minFrameMs, 12.7);
        expect(summary.worstFrameMs, 12.7);
        expect(summary.p50FrameMs, 12.7);
        expect(summary.p90FrameMs, 12.7);
        expect(summary.p99FrameMs, 12.7);
      });

      test('handles empty frame array safely', () {
        final summary = FrameTimingSummary.fromDurations(
          buildMs: [],
          rasterMs: [],
        );

        expect(summary.frameCount, 0);
        expect(summary.p50FrameMs, 0.0);
        expect(summary.p90FrameMs, 0.0);
        expect(summary.worstFrameMs, 0.0);
        expect(summary.generateRecommendations(), isEmpty);
      });
    });

    group('3. Configurable Refresh Rate & Frame Budget', () {
      test('calculates correct budget for 60Hz, 90Hz, and 120Hz', () {
        final s60 = FrameTimingSummary.fromDurations(
          buildMs: [10.0],
          rasterMs: [5.0],
          refreshRateHz: 60.0,
        );
        expect(s60.frameBudgetMs, closeTo(16.67, 0.01));

        final s90 = FrameTimingSummary.fromDurations(
          buildMs: [10.0],
          rasterMs: [5.0],
          refreshRateHz: 90.0,
        );
        expect(s90.frameBudgetMs, closeTo(11.11, 0.01));

        final s120 = FrameTimingSummary.fromDurations(
          buildMs: [10.0],
          rasterMs: [5.0],
          refreshRateHz: 120.0,
        );
        expect(s120.frameBudgetMs, closeTo(8.33, 0.01));
      });

      test('validates unreasonable refresh rates and falls back to 60Hz', () {
        final sInvalid = FrameTimingSummary.fromDurations(
          buildMs: [10.0],
          rasterMs: [5.0],
          refreshRateHz: -50.0,
        );
        expect(sInvalid.refreshRateHz, 60.0);
        expect(sInvalid.frameBudgetMs, closeTo(16.67, 0.01));
      });
    });

    group('4. Build vs Raster Bottleneck Analysis', () {
      test('identifies CPU/Widget build bottleneck', () {
        final summary = FrameTimingSummary.fromDurations(
          buildMs: [25.0, 28.0, 22.0, 24.0],
          rasterMs: [2.0, 3.0, 2.0, 3.0],
          refreshRateHz: 60.0,
        );

        final issues = summary.generateRecommendations();
        expect(issues.map((i) => i.id), contains('perf_build_bottleneck'));
        expect(
          issues.map((i) => i.id),
          isNot(contains('perf_raster_bottleneck')),
        );
      });

      test('identifies GPU rasterization bottleneck', () {
        final summary = FrameTimingSummary.fromDurations(
          buildMs: [2.0, 3.0, 2.0, 3.0],
          rasterMs: [25.0, 28.0, 22.0, 24.0],
          refreshRateHz: 60.0,
        );

        final issues = summary.generateRecommendations();
        expect(issues.map((i) => i.id), contains('perf_raster_bottleneck'));
        expect(
          issues.map((i) => i.id),
          isNot(contains('perf_build_bottleneck')),
        );
      });

      test('distinguishes single peak spike from systemic jank', () {
        // 9 normal frames, 1 single peak spike
        final build = [4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 50.0];
        final raster = [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 10.0];

        final summary = FrameTimingSummary.fromDurations(
          buildMs: build,
          rasterMs: raster,
          refreshRateHz: 60.0,
        );

        final issues = summary.generateRecommendations();
        expect(issues.map((i) => i.id), contains('perf_frame_spike_transient'));
        expect(issues.map((i) => i.id), isNot(contains('perf_slow_frame_p90')));
      });

      test('identifies severe jank when multiple frames take > 2x budget', () {
        final build = [30.0, 35.0, 40.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0];
        final raster = [10.0, 10.0, 10.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0];

        final summary = FrameTimingSummary.fromDurations(
          buildMs: build,
          rasterMs: raster,
          refreshRateHz: 60.0,
        );

        final issues = summary.generateRecommendations();
        expect(issues.map((i) => i.id), contains('perf_severe_jank'));
      });
    });

    group('5. Schema Trace Parsing & Fixtures Verification', () {
      test('parses DevTools trace JSON fixture', () async {
        final file = File('test/fixtures/performance/devtools_trace.json');
        final content = await file.readAsString();

        final result = PerformanceInputParser.parse(content);
        expect(result.status, PerformanceAnalysisStatus.valid);
        expect(result.summary, isNotNull);
        expect(result.summary!.frameCount, greaterThan(0));
      });

      test('parses raw frame array fixture', () async {
        final file = File('test/fixtures/performance/raw_frames_list.json');
        final content = await file.readAsString();

        final result = PerformanceInputParser.parse(content);
        expect(result.status, PerformanceAnalysisStatus.valid);
        expect(result.summary!.frameCount, 5);
      });

      test('parses pre-summarized metrics fixture', () async {
        final file = File(
          'test/fixtures/performance/pre_summarized_metrics.json',
        );
        final content = await file.readAsString();

        final result = PerformanceInputParser.parse(content);
        expect(result.status, PerformanceAnalysisStatus.valid);
        expect(result.summary!.frameCount, 100);
        expect(result.summary!.p90FrameMs, 24.2);
      });
    });
  });
}
