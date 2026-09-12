import '../core/models.dart';

/// Evidence-based runtime performance tracker for Flutter applications.
class PerformanceInvestigator {
  PerformanceInvestigator({this.sessionName = 'default-session'});

  final String sessionName;
  final Map<String, List<double>> _traces = <String, List<double>>{};
  final List<String> _marks = <String>[];
  final Map<String, dynamic> _metrics = <String, dynamic>{};

  /// Starts a new session before collecting timing data.
  void startSession(String name) {
    _metrics['session_name'] = name;
  }

  /// Adds a named trace with duration in milliseconds.
  void startTrace(String name) {
    _metrics['trace_$name'] = DateTime.now().microsecondsSinceEpoch;
  }

  /// Completes a trace and stores the observed duration.
  void endTrace(String name, {required num durationMs}) {
    final times = _traces.putIfAbsent(name, () => <double>[]);
    times.add(durationMs.toDouble());
    _metrics['trace_count'] = _traces.length;
    _metrics['slowest_trace_ms'] = _traces.values
        .expand((values) => values)
        .fold<double>(0, (value, element) => element > value ? element : value);
  }

  /// Marks a named event in a session.
  void mark(String name) {
    _marks.add(name);
    _metrics['last_mark'] = name;
  }

  /// Generates the current report from collected performance evidence.
  DiagnosticReport generateReport() {
    final allDurations = _traces.values.expand((values) => values).toList();
    final metrics = <String, dynamic>{
      'trace_count': _traces.length,
      'mark_count': _marks.length,
      'slowest_trace_ms': allDurations.isEmpty
          ? 0.0
          : allDurations.reduce((a, b) => a > b ? a : b),
      'average_trace_ms': allDurations.isEmpty
          ? 0.0
          : allDurations.reduce((a, b) => a + b) / allDurations.length,
      'session_name': sessionName,
    };

    return DiagnosticReport(
      id: 'perf_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'runtime-session',
      issues: const <DiagnosticIssue>[],
      metrics: metrics,
      warnings: const <String>[],
    );
  }
}

/// Derived metrics calculated from measured frame durations.
class FrameTimingSummary {
  const FrameTimingSummary({
    required this.frameCount,
    required this.slowFrameCount,
    required this.severeJankFrameCount,
    required this.averageBuildMs,
    required this.averageRasterMs,
    required this.maxBuildMs,
    required this.maxRasterMs,
    required this.worstFrameMs,
    required this.p50FrameMs,
    required this.p90FrameMs,
    required this.p99FrameMs,
    this.frameBudgetMs = 16.67,
  });

  final int frameCount;
  final int slowFrameCount;
  final int severeJankFrameCount;
  final double averageBuildMs;
  final double averageRasterMs;
  final double maxBuildMs;
  final double maxRasterMs;
  final double worstFrameMs;
  final double p50FrameMs;
  final double p90FrameMs;
  final double p99FrameMs;
  final double frameBudgetMs;

  /// Calculates metrics from measured build/raster samples only.
  factory FrameTimingSummary.fromDurations({
    required List<double> buildMs,
    required List<double> rasterMs,
    double slowFrameThresholdMs = 16.67,
    double severeJankThresholdMs = 33.33,
  }) {
    final count = buildMs.length < rasterMs.length
        ? buildMs.length
        : rasterMs.length;
    final validBuilds = buildMs.take(count).toList();
    final validRasters = rasterMs.take(count).toList();
    final totals = <double>[
      for (var index = 0; index < count; index += 1)
        validBuilds[index] + validRasters[index],
    ];
    final sorted = List<double>.of(totals)..sort();
    final sortedBuilds = List<double>.of(validBuilds)..sort();
    final sortedRasters = List<double>.of(validRasters)..sort();

    return FrameTimingSummary(
      frameCount: count,
      slowFrameCount: totals
          .where((duration) => duration > slowFrameThresholdMs)
          .length,
      severeJankFrameCount: totals
          .where((duration) => duration > severeJankThresholdMs)
          .length,
      averageBuildMs: _average(validBuilds),
      averageRasterMs: _average(validRasters),
      maxBuildMs: sortedBuilds.isEmpty ? 0.0 : sortedBuilds.last,
      maxRasterMs: sortedRasters.isEmpty ? 0.0 : sortedRasters.last,
      worstFrameMs: sorted.isEmpty ? 0.0 : sorted.last,
      p50FrameMs: _percentile(sorted, 0.50),
      p90FrameMs: _percentile(sorted, 0.90),
      p99FrameMs: _percentile(sorted, 0.99),
      frameBudgetMs: slowFrameThresholdMs,
    );
  }

  /// Generates evidence-backed recommendations based only on measured metrics exceeding thresholds.
  List<DiagnosticIssue> generateRecommendations() {
    if (frameCount == 0) return const [];
    final issues = <DiagnosticIssue>[];

    if (p90FrameMs > frameBudgetMs) {
      issues.add(
        DiagnosticIssue(
          id: 'perf_slow_frame_p90',
          category: DiagnosticCategory.frame,
          severity: p90FrameMs > 33.33
              ? DiagnosticSeverity.high
              : DiagnosticSeverity.medium,
          title: '90th percentile frame duration exceeds target budget',
          description:
              'The p90 frame time of ${p90FrameMs.toStringAsFixed(2)}ms exceeds the budget target of ${frameBudgetMs.toStringAsFixed(2)}ms ($slowFrameCount slow frames observed out of $frameCount frames).',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.frameTiming,
              label: 'p90_frame_ms',
              value: '${p90FrameMs.toStringAsFixed(2)} ms',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action: 'Optimize build methods and reduce offscreen GPU layers.',
              details:
                  'Review rebuild frequencies and isolate animated subtrees.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.88,
        ),
      );
    }

    if (averageBuildMs > 8.33 || maxBuildMs > frameBudgetMs) {
      issues.add(
        DiagnosticIssue(
          id: 'perf_build_bottleneck',
          category: DiagnosticCategory.rebuild,
          severity: maxBuildMs > 33.33
              ? DiagnosticSeverity.high
              : DiagnosticSeverity.medium,
          title: 'High widget build duration detected',
          description:
              'Average build time is ${averageBuildMs.toStringAsFixed(2)}ms (peak ${maxBuildMs.toStringAsFixed(2)}ms). Widget builds are consuming a significant portion of the frame budget.',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'average_build_ms',
              value: '${averageBuildMs.toStringAsFixed(2)} ms',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Use const constructors and RepaintBoundary where appropriate.',
              details:
                  'Avoid heavy computational work inside Widget build methods.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.85,
        ),
      );
    }

    if (averageRasterMs > 8.33 || maxRasterMs > frameBudgetMs) {
      issues.add(
        DiagnosticIssue(
          id: 'perf_raster_bottleneck',
          category: DiagnosticCategory.performance,
          severity: maxRasterMs > 33.33
              ? DiagnosticSeverity.high
              : DiagnosticSeverity.medium,
          title: 'GPU rasterization bottleneck detected',
          description:
              'Average raster time is ${averageRasterMs.toStringAsFixed(2)}ms (peak ${maxRasterMs.toStringAsFixed(2)}ms). GPU rasterization is taking longer than expected.',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'average_raster_ms',
              value: '${averageRasterMs.toStringAsFixed(2)} ms',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Check for un-precompiled shaders, saveLayer calls, or large un-cached images.',
              details:
                  'Use Skia / Impeller performance trace tools to profile GPU raster tasks.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.84,
        ),
      );
    }

    return issues;
  }

  Map<String, dynamic> toJson() => {
    'frame_count': frameCount,
    'slow_frame_count': slowFrameCount,
    'severe_jank_frame_count': severeJankFrameCount,
    'average_build_ms': averageBuildMs,
    'average_raster_ms': averageRasterMs,
    'max_build_ms': maxBuildMs,
    'max_raster_ms': maxRasterMs,
    'worst_frame_ms': worstFrameMs,
    'p50_frame_ms': p50FrameMs,
    'p90_frame_ms': p90FrameMs,
    'p99_frame_ms': p99FrameMs,
    'frame_budget_ms': frameBudgetMs,
  };

  factory FrameTimingSummary.fromJson(Map<String, dynamic> json) {
    // 1. Direct summary metrics format
    if (json.containsKey('frame_count') || json.containsKey('p90_frame_ms')) {
      return FrameTimingSummary(
        frameCount: json['frame_count'] as int? ?? 0,
        slowFrameCount: json['slow_frame_count'] as int? ?? 0,
        severeJankFrameCount: json['severe_jank_frame_count'] as int? ?? 0,
        averageBuildMs: (json['average_build_ms'] as num? ?? 0.0).toDouble(),
        averageRasterMs: (json['average_raster_ms'] as num? ?? 0.0).toDouble(),
        maxBuildMs: (json['max_build_ms'] as num? ?? 0.0).toDouble(),
        maxRasterMs: (json['max_raster_ms'] as num? ?? 0.0).toDouble(),
        worstFrameMs: (json['worst_frame_ms'] as num? ?? 0.0).toDouble(),
        p50FrameMs: (json['p50_frame_ms'] as num? ?? 0.0).toDouble(),
        p90FrameMs: (json['p90_frame_ms'] as num? ?? 0.0).toDouble(),
        p99FrameMs: (json['p99_frame_ms'] as num? ?? 0.0).toDouble(),
        frameBudgetMs: (json['frame_budget_ms'] as num? ?? 16.67).toDouble(),
      );
    }

    // 2. Trace events format (DevTools / Chrome Tracing JSON)
    if (json.containsKey('traceEvents') && json['traceEvents'] is List) {
      final events = json['traceEvents'] as List;
      final buildMs = <double>[];
      final rasterMs = <double>[];

      for (final event in events) {
        if (event is Map) {
          final name = event['name']?.toString() ?? '';
          final durMicros = (event['dur'] as num?)?.toDouble() ?? 0.0;
          if (name.contains('Build') ||
              name.contains('VSYNC') ||
              name.contains('Animate')) {
            if (durMicros > 0) buildMs.add(durMicros / 1000.0);
          } else if (name.contains('Raster') ||
              name.contains('GPU') ||
              name.contains('GPURasterizer')) {
            if (durMicros > 0) rasterMs.add(durMicros / 1000.0);
          }
        }
      }

      if (buildMs.isNotEmpty || rasterMs.isNotEmpty) {
        if (buildMs.isEmpty) buildMs.addAll(List.filled(rasterMs.length, 0.0));
        if (rasterMs.isEmpty) rasterMs.addAll(List.filled(buildMs.length, 0.0));
        return FrameTimingSummary.fromDurations(
          buildMs: buildMs,
          rasterMs: rasterMs,
        );
      }
    }

    // 3. Raw frames list format: { "frames": [ { "buildMs": 10.5, "rasterMs": 4.2 }, ... ] }
    if (json.containsKey('frames') && json['frames'] is List) {
      final framesList = json['frames'] as List;
      final buildMs = <double>[];
      final rasterMs = <double>[];
      for (final item in framesList) {
        if (item is Map) {
          final b =
              (item['buildMs'] ??
                      item['build_ms'] ??
                      item['buildDuration'] ??
                      0.0)
                  as num;
          final r =
              (item['rasterMs'] ??
                      item['raster_ms'] ??
                      item['rasterDuration'] ??
                      0.0)
                  as num;
          buildMs.add(b.toDouble());
          rasterMs.add(r.toDouble());
        }
      }
      return FrameTimingSummary.fromDurations(
        buildMs: buildMs,
        rasterMs: rasterMs,
      );
    }

    // Fallback: empty summary
    return const FrameTimingSummary(
      frameCount: 0,
      slowFrameCount: 0,
      severeJankFrameCount: 0,
      averageBuildMs: 0.0,
      averageRasterMs: 0.0,
      maxBuildMs: 0.0,
      maxRasterMs: 0.0,
      worstFrameMs: 0.0,
      p50FrameMs: 0.0,
      p90FrameMs: 0.0,
      p99FrameMs: 0.0,
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    return values.reduce((left, right) => left + right) / values.length;
  }

  static double _percentile(List<double> sorted, double fraction) {
    if (sorted.isEmpty) {
      return 0.0;
    }
    final index = (sorted.length * fraction).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

/// Delta comparison between a baseline and current performance session.
class FrameTimingComparison {
  const FrameTimingComparison({
    required this.baseline,
    required this.current,
    required this.p50DeltaMs,
    required this.p90DeltaMs,
    required this.p99DeltaMs,
    required this.averageBuildDeltaMs,
    required this.averageRasterDeltaMs,
    required this.isRegression,
  });

  final FrameTimingSummary baseline;
  final FrameTimingSummary current;
  final double p50DeltaMs;
  final double p90DeltaMs;
  final double p99DeltaMs;
  final double averageBuildDeltaMs;
  final double averageRasterDeltaMs;
  final bool isRegression;

  static FrameTimingComparison compare({
    required FrameTimingSummary baseline,
    required FrameTimingSummary current,
  }) {
    final p50Delta = current.p50FrameMs - baseline.p50FrameMs;
    final p90Delta = current.p90FrameMs - baseline.p90FrameMs;
    final p99Delta = current.p99FrameMs - baseline.p99FrameMs;
    final buildDelta = current.averageBuildMs - baseline.averageBuildMs;
    final rasterDelta = current.averageRasterMs - baseline.averageRasterMs;
    final isRegress =
        p90Delta > 2.0 || current.slowFrameCount > baseline.slowFrameCount;

    return FrameTimingComparison(
      baseline: baseline,
      current: current,
      p50DeltaMs: p50Delta,
      p90DeltaMs: p90Delta,
      p99DeltaMs: p99Delta,
      averageBuildDeltaMs: buildDelta,
      averageRasterDeltaMs: rasterDelta,
      isRegression: isRegress,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseline': baseline.toJson(),
    'current': current.toJson(),
    'p50_delta_ms': p50DeltaMs,
    'p90_delta_ms': p90DeltaMs,
    'p99_delta_ms': p99DeltaMs,
    'average_build_delta_ms': averageBuildDeltaMs,
    'average_raster_delta_ms': averageRasterDeltaMs,
    'is_regression': isRegression,
  };
}

/// Simple data structure holding raw build and raster durations in milliseconds.
class FrameTimingData {
  const FrameTimingData({required this.buildMs, required this.rasterMs});

  final double buildMs;
  final double rasterMs;
}

/// Collects real Flutter engine frame timings during an application session.
class FrameTimingCollector {
  FrameTimingCollector({this.maxSamples = 120}) : assert(maxSamples > 0);

  final int maxSamples;
  final List<FrameTimingData> _samples = <FrameTimingData>[];
  bool _collecting = false;

  bool get isCollecting => _collecting;
  int get sampleCount => _samples.length;

  /// Starts collecting frame timings. Repeated starts are ignored.
  void start() {
    _collecting = true;
  }

  /// Stops collecting.
  void stop() {
    _collecting = false;
  }

  /// Removes all collected frame samples without changing collection state.
  void reset() {
    _samples.clear();
  }

  /// Manually records a single frame build and raster duration.
  void addSample({required double buildMs, required double rasterMs}) {
    if (!_collecting) return;
    if (_samples.length == maxSamples) {
      _samples.removeAt(0);
    }
    _samples.add(FrameTimingData(buildMs: buildMs, rasterMs: rasterMs));
  }

  /// Callback to receive timings from Flutter's SchedulerBinding or custom timing sources.
  void addTimings(List<dynamic> timings) {
    if (!_collecting) return;
    for (final timing in timings) {
      try {
        final dynamic buildDur = timing.buildDuration;
        final dynamic rasterDur = timing.rasterDuration;
        final double buildMs = buildDur is Duration
            ? buildDur.inMicroseconds / 1000.0
            : (buildDur as num).toDouble();
        final double rasterMs = rasterDur is Duration
            ? rasterDur.inMicroseconds / 1000.0
            : (rasterDur as num).toDouble();
        addSample(buildMs: buildMs, rasterMs: rasterMs);
      } catch (_) {}
    }
  }

  /// Summarizes collected frames into a DiagnosticReport.
  DiagnosticReport generateReport() {
    final buildMs = _samples.map((sample) => sample.buildMs).toList();
    final rasterMs = _samples.map((sample) => sample.rasterMs).toList();
    final summary = FrameTimingSummary.fromDurations(
      buildMs: buildMs,
      rasterMs: rasterMs,
    );
    final recommendations = summary.generateRecommendations();

    return DiagnosticReport(
      id: 'frame_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'runtime-session',
      issues: recommendations,
      metrics: <String, dynamic>{
        'max_samples': maxSamples,
        ...summary.toJson(),
      },
      limitations: _samples.isEmpty
          ? const <String>['No Flutter frame timings were collected.']
          : const <String>[],
    );
  }
}
