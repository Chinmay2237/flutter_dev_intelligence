import '../core/models.dart';
import 'performance_input_parser.dart';

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

/// Derived metrics calculated from measured frame durations across UI Build and GPU Raster tasks.
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
    required this.p75FrameMs,
    required this.p90FrameMs,
    required this.p95FrameMs,
    required this.p99FrameMs,
    this.minFrameMs = 0.0,
    this.meanFrameMs = 0.0,
    this.buildP90Ms = 0.0,
    this.buildP95Ms = 0.0,
    this.buildP99Ms = 0.0,
    this.rasterP90Ms = 0.0,
    this.rasterP95Ms = 0.0,
    this.rasterP99Ms = 0.0,
    this.refreshRateHz = 60.0,
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
  final double minFrameMs;
  final double meanFrameMs;
  final double p50FrameMs;
  final double p75FrameMs;
  final double p90FrameMs;
  final double p95FrameMs;
  final double p99FrameMs;

  final double buildP90Ms;
  final double buildP95Ms;
  final double buildP99Ms;

  final double rasterP90Ms;
  final double rasterP95Ms;
  final double rasterP99Ms;

  final double refreshRateHz;
  final double frameBudgetMs;

  double get slowFramePercentage =>
      frameCount == 0 ? 0.0 : (slowFrameCount / frameCount) * 100.0;

  double get severeJankFramePercentage =>
      frameCount == 0 ? 0.0 : (severeJankFrameCount / frameCount) * 100.0;

  /// Calculates metrics from measured build/raster duration samples.
  factory FrameTimingSummary.fromDurations({
    required List<double> buildMs,
    required List<double> rasterMs,
    double refreshRateHz = 60.0,
    double? customBudgetMs,
  }) {
    final validRefreshRate =
        (refreshRateHz.isNaN ||
            refreshRateHz.isInfinite ||
            refreshRateHz < 1.0 ||
            refreshRateHz > 240.0)
        ? 60.0
        : refreshRateHz;

    final budgetMs = customBudgetMs ?? (1000.0 / validRefreshRate);
    final severeJankThresholdMs = budgetMs * 2.0;

    // Filter invalid numeric values (NaN, Infinity, < 0)
    final cleanBuilds = buildMs
        .where((v) => !v.isNaN && !v.isInfinite && v >= 0.0)
        .toList();
    final cleanRasters = rasterMs
        .where((v) => !v.isNaN && !v.isInfinite && v >= 0.0)
        .toList();

    final count = cleanBuilds.length > cleanRasters.length
        ? cleanBuilds.length
        : cleanRasters.length;

    if (count == 0) {
      return FrameTimingSummary(
        frameCount: 0,
        slowFrameCount: 0,
        severeJankFrameCount: 0,
        averageBuildMs: 0.0,
        averageRasterMs: 0.0,
        maxBuildMs: 0.0,
        maxRasterMs: 0.0,
        worstFrameMs: 0.0,
        p50FrameMs: 0.0,
        p75FrameMs: 0.0,
        p90FrameMs: 0.0,
        p95FrameMs: 0.0,
        p99FrameMs: 0.0,
        refreshRateHz: validRefreshRate,
        frameBudgetMs: budgetMs,
      );
    }

    final normalizedBuilds = List<double>.generate(
      count,
      (i) => i < cleanBuilds.length ? cleanBuilds[i] : 0.0,
    );
    final normalizedRasters = List<double>.generate(
      count,
      (i) => i < cleanRasters.length ? cleanRasters[i] : 0.0,
    );

    final totalDurations = <double>[
      for (var index = 0; index < count; index += 1)
        normalizedBuilds[index] + normalizedRasters[index],
    ];

    final sortedTotals = List<double>.of(totalDurations)..sort();
    final sortedBuilds = List<double>.of(normalizedBuilds)..sort();
    final sortedRasters = List<double>.of(normalizedRasters)..sort();

    final slowCount = totalDurations.where((d) => d > budgetMs).length;
    final severeCount = totalDurations
        .where((d) => d > severeJankThresholdMs)
        .length;

    return FrameTimingSummary(
      frameCount: count,
      slowFrameCount: slowCount,
      severeJankFrameCount: severeCount,
      averageBuildMs: _average(normalizedBuilds),
      averageRasterMs: _average(normalizedRasters),
      maxBuildMs: sortedBuilds.isEmpty ? 0.0 : sortedBuilds.last,
      maxRasterMs: sortedRasters.isEmpty ? 0.0 : sortedRasters.last,
      worstFrameMs: sortedTotals.isEmpty ? 0.0 : sortedTotals.last,
      minFrameMs: sortedTotals.isEmpty ? 0.0 : sortedTotals.first,
      meanFrameMs: _average(totalDurations),
      p50FrameMs: _percentile(sortedTotals, 0.50),
      p75FrameMs: _percentile(sortedTotals, 0.75),
      p90FrameMs: _percentile(sortedTotals, 0.90),
      p95FrameMs: _percentile(sortedTotals, 0.95),
      p99FrameMs: _percentile(sortedTotals, 0.99),
      buildP90Ms: _percentile(sortedBuilds, 0.90),
      buildP95Ms: _percentile(sortedBuilds, 0.95),
      buildP99Ms: _percentile(sortedBuilds, 0.99),
      rasterP90Ms: _percentile(sortedRasters, 0.90),
      rasterP95Ms: _percentile(sortedRasters, 0.95),
      rasterP99Ms: _percentile(sortedRasters, 0.99),
      refreshRateHz: validRefreshRate,
      frameBudgetMs: budgetMs,
    );
  }

  /// Generates evidence-backed recommendations based on measured metrics exceeding thresholds.
  List<DiagnosticIssue> generateRecommendations() {
    if (frameCount == 0) return const [];
    final issues = <DiagnosticIssue>[];

    // Rule 1: Systemic slow frames (p90 exceeds frame budget)
    if (p90FrameMs > frameBudgetMs) {
      final severity = p90FrameMs > (frameBudgetMs * 2.0)
          ? DiagnosticSeverity.high
          : DiagnosticSeverity.medium;
      issues.add(
        DiagnosticIssue(
          id: 'perf_slow_frame_p90',
          category: DiagnosticCategory.frame,
          severity: severity,
          title: '90th percentile frame duration exceeds target budget',
          description:
              'The p90 frame time of ${p90FrameMs.toStringAsFixed(2)}ms exceeds the budget target of ${frameBudgetMs.toStringAsFixed(2)}ms '
              '($slowFrameCount slow frames out of $frameCount frames, ${slowFramePercentage.toStringAsFixed(1)}%).',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.frameTiming,
              label: 'p90_frame_ms',
              value: '${p90FrameMs.toStringAsFixed(2)} ms',
            ),
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'frame_budget_ms',
              value:
                  '${frameBudgetMs.toStringAsFixed(2)} ms (${refreshRateHz.toStringAsFixed(0)} Hz)',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Optimize heavy build methods and isolate rebuild subtrees.',
              details:
                  'Use const constructors, RepaintBoundary, and avoid expensive computation during layout.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.90,
        ),
      );
    }

    // Rule 2: High widget build bottleneck (CPU/rebuild pressure)
    if (averageBuildMs > (frameBudgetMs * 0.5) || buildP90Ms > frameBudgetMs) {
      final severity = maxBuildMs > (frameBudgetMs * 2.0)
          ? DiagnosticSeverity.high
          : DiagnosticSeverity.medium;
      issues.add(
        DiagnosticIssue(
          id: 'perf_build_bottleneck',
          category: DiagnosticCategory.rebuild,
          severity: severity,
          title: 'High widget build duration detected',
          description:
              'Average build time is ${averageBuildMs.toStringAsFixed(2)}ms (p90 ${buildP90Ms.toStringAsFixed(2)}ms, max ${maxBuildMs.toStringAsFixed(2)}ms). '
              'Widget builds are consuming an excessive portion of the frame budget.',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'average_build_ms',
              value: '${averageBuildMs.toStringAsFixed(2)} ms',
            ),
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'build_p90_ms',
              value: '${buildP90Ms.toStringAsFixed(2)} ms',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Refactor heavy widget builds and cache immutable subtree widgets.',
              details:
                  'Move synchronous I/O or JSON parsing out of Widget build methods into background isolates.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.88,
        ),
      );
    }

    // Rule 3: High GPU raster bottleneck (Raster/Shader/Image pressure)
    if (averageRasterMs > (frameBudgetMs * 0.5) ||
        rasterP90Ms > frameBudgetMs) {
      final severity = maxRasterMs > (frameBudgetMs * 2.0)
          ? DiagnosticSeverity.high
          : DiagnosticSeverity.medium;
      issues.add(
        DiagnosticIssue(
          id: 'perf_raster_bottleneck',
          category: DiagnosticCategory.performance,
          severity: severity,
          title: 'GPU rasterization bottleneck detected',
          description:
              'Average raster time is ${averageRasterMs.toStringAsFixed(2)}ms (p90 ${rasterP90Ms.toStringAsFixed(2)}ms, max ${maxRasterMs.toStringAsFixed(2)}ms). '
              'GPU rasterization is taking longer than expected.',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'average_raster_ms',
              value: '${averageRasterMs.toStringAsFixed(2)} ms',
            ),
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'raster_p90_ms',
              value: '${rasterP90Ms.toStringAsFixed(2)} ms',
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
          confidence: 0.86,
        ),
      );
    }

    // Rule 4: Severe jank (frames taking > 2x budget)
    if (severeJankFrameCount > 0 && severeJankFramePercentage > 5.0) {
      issues.add(
        DiagnosticIssue(
          id: 'perf_severe_jank',
          category: DiagnosticCategory.frame,
          severity: DiagnosticSeverity.high,
          title: 'Severe frame jank detected',
          description:
              'Observed $severeJankFrameCount severe jank frames (${severeJankFramePercentage.toStringAsFixed(1)}% of total frames) '
              'exceeding twice the frame budget (${(frameBudgetMs * 2.0).toStringAsFixed(2)}ms).',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'severe_jank_count',
              value: '$severeJankFrameCount frames',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Audit main thread blocking calls during user scrolling or navigation.',
              details:
                  'Ensure database transactions and network decodes run asynchronously.',
              riskLevel: FixRiskLevel.medium,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.92,
        ),
      );
    }

    // Rule 5: Transient peak spike (Single frame spike without high p90)
    if (worstFrameMs > (frameBudgetMs * 3.0) && p90FrameMs <= frameBudgetMs) {
      issues.add(
        DiagnosticIssue(
          id: 'perf_frame_spike_transient',
          category: DiagnosticCategory.frame,
          severity: DiagnosticSeverity.low,
          title: 'Isolated transient frame duration spike',
          description:
              'A peak frame duration spike of ${worstFrameMs.toStringAsFixed(2)}ms was observed, '
              'but the p90 frame time (${p90FrameMs.toStringAsFixed(2)}ms) remains within budget. '
              'This represents a transient peak rather than systemic frame jank.',
          source: 'runtime frame timing',
          evidence: [
            EvidenceReference(
              type: EvidenceType.performanceMetric,
              label: 'worst_frame_ms',
              value: '${worstFrameMs.toStringAsFixed(2)} ms',
            ),
          ],
          suggestions: const [
            FixSuggestion(
              action:
                  'Monitor peak initialization spikes during app cold boot or route changes.',
              details:
                  'Pre-warm assets and defer non-critical background initialization.',
              riskLevel: FixRiskLevel.low,
              isSafeToAutomate: false,
              requiresUserConfirmation: true,
            ),
          ],
          confidence: 0.75,
        ),
      );
    }

    return issues;
  }

  Map<String, dynamic> toJson() => {
    'frame_count': frameCount,
    'slow_frame_count': slowFrameCount,
    'severe_jank_frame_count': severeJankFrameCount,
    'slow_frame_percentage': slowFramePercentage,
    'severe_jank_frame_percentage': severeJankFramePercentage,
    'average_build_ms': averageBuildMs,
    'average_raster_ms': averageRasterMs,
    'max_build_ms': maxBuildMs,
    'max_raster_ms': maxRasterMs,
    'worst_frame_ms': worstFrameMs,
    'min_frame_ms': minFrameMs,
    'mean_frame_ms': meanFrameMs,
    'p50_frame_ms': p50FrameMs,
    'p75_frame_ms': p75FrameMs,
    'p90_frame_ms': p90FrameMs,
    'p95_frame_ms': p95FrameMs,
    'p99_frame_ms': p99FrameMs,
    'build_p90_ms': buildP90Ms,
    'build_p95_ms': buildP95Ms,
    'build_p99_ms': buildP99Ms,
    'raster_p90_ms': rasterP90Ms,
    'raster_p95_ms': rasterP95Ms,
    'raster_p99_ms': rasterP99Ms,
    'refresh_rate_hz': refreshRateHz,
    'frame_budget_ms': frameBudgetMs,
  };

  factory FrameTimingSummary.fromJson(
    Map<String, dynamic> json, {
    double refreshRateHz = 60.0,
  }) {
    // Delegates parsing to PerformanceInputParser for robust status handling across all schemas
    final parseResult = PerformanceInputParser.parse(
      json,
      refreshRateHz: refreshRateHz,
    );
    if (parseResult.summary != null) {
      return parseResult.summary!;
    }

    return FrameTimingSummary(
      frameCount: (json['frame_count'] as int?) ?? 0,
      slowFrameCount: (json['slow_frame_count'] as int?) ?? 0,
      severeJankFrameCount: (json['severe_jank_frame_count'] as int?) ?? 0,
      averageBuildMs: (json['average_build_ms'] as num? ?? 0.0).toDouble(),
      averageRasterMs: (json['average_raster_ms'] as num? ?? 0.0).toDouble(),
      maxBuildMs: (json['max_build_ms'] as num? ?? 0.0).toDouble(),
      maxRasterMs: (json['max_raster_ms'] as num? ?? 0.0).toDouble(),
      worstFrameMs: (json['worst_frame_ms'] as num? ?? 0.0).toDouble(),
      p50FrameMs: (json['p50_frame_ms'] as num? ?? 0.0).toDouble(),
      p75FrameMs: (json['p75_frame_ms'] as num? ?? 0.0).toDouble(),
      p90FrameMs: (json['p90_frame_ms'] as num? ?? 0.0).toDouble(),
      p95FrameMs: (json['p95_frame_ms'] as num? ?? 0.0).toDouble(),
      p99FrameMs: (json['p99_frame_ms'] as num? ?? 0.0).toDouble(),
      refreshRateHz: refreshRateHz,
      frameBudgetMs: 1000.0 / refreshRateHz,
    );
  }

  static double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  static double _percentile(List<double> sorted, double fraction) {
    if (sorted.isEmpty) return 0.0;
    if (sorted.length == 1) return sorted.first;
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
  DiagnosticReport generateReport({double refreshRateHz = 60.0}) {
    final buildMs = _samples.map((sample) => sample.buildMs).toList();
    final rasterMs = _samples.map((sample) => sample.rasterMs).toList();
    final summary = FrameTimingSummary.fromDurations(
      buildMs: buildMs,
      rasterMs: rasterMs,
      refreshRateHz: refreshRateHz,
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
