import '../core/models.dart';
import 'package:flutter/scheduler.dart';

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
    required this.averageBuildMs,
    required this.averageRasterMs,
    required this.worstFrameMs,
    required this.p50FrameMs,
    required this.p90FrameMs,
    required this.p99FrameMs,
  });

  final int frameCount;
  final int slowFrameCount;
  final double averageBuildMs;
  final double averageRasterMs;
  final double worstFrameMs;
  final double p50FrameMs;
  final double p90FrameMs;
  final double p99FrameMs;

  /// Calculates metrics from measured build/raster samples only.
  factory FrameTimingSummary.fromDurations({
    required List<double> buildMs,
    required List<double> rasterMs,
    double slowFrameThresholdMs = 16.67,
  }) {
    final count = buildMs.length < rasterMs.length
        ? buildMs.length
        : rasterMs.length;
    final totals = <double>[
      for (var index = 0; index < count; index += 1)
        buildMs[index] + rasterMs[index],
    ];
    final sorted = List<double>.of(totals)..sort();
    return FrameTimingSummary(
      frameCount: count,
      slowFrameCount: totals
          .where((duration) => duration > slowFrameThresholdMs)
          .length,
      averageBuildMs: _average(buildMs.take(count).toList()),
      averageRasterMs: _average(rasterMs.take(count).toList()),
      worstFrameMs: sorted.isEmpty ? 0.0 : sorted.last,
      p50FrameMs: _percentile(sorted, 0.50),
      p90FrameMs: _percentile(sorted, 0.90),
      p99FrameMs: _percentile(sorted, 0.99),
    );
  }

  Map<String, dynamic> toJson() => {
    'frame_count': frameCount,
    'slow_frame_count': slowFrameCount,
    'average_build_ms': averageBuildMs,
    'average_raster_ms': averageRasterMs,
    'worst_frame_ms': worstFrameMs,
    'p50_frame_ms': p50FrameMs,
    'p90_frame_ms': p90FrameMs,
    'p99_frame_ms': p99FrameMs,
  };

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

/// Collects real Flutter engine frame timings during an application session.
///
/// This collector must be started from a Flutter application with initialized
/// bindings. It does not fabricate samples when no frame callback is received.
class FrameTimingCollector {
  FrameTimingCollector({this.maxSamples = 120}) : assert(maxSamples > 0);

  final int maxSamples;
  final List<FrameTiming> _samples = <FrameTiming>[];
  SchedulerBinding? _binding;
  bool _collecting = false;

  bool get isCollecting => _collecting;
  int get sampleCount => _samples.length;

  /// Starts collecting frame timings. Repeated starts are ignored.
  void start() {
    if (_collecting) {
      return;
    }
    _binding = SchedulerBinding.instance;
    _binding!.addTimingsCallback(_onTimings);
    _collecting = true;
  }

  /// Stops collecting and unregisters the timing callback.
  void stop() {
    if (!_collecting) {
      return;
    }
    _binding?.removeTimingsCallback(_onTimings);
    _binding = null;
    _collecting = false;
  }

  /// Removes all collected frame samples without changing collection state.
  void reset() {
    _samples.clear();
  }

  /// Summarizes only frames actually delivered by Flutter.
  DiagnosticReport generateReport() {
    final buildMs = _samples
        .map((sample) => sample.buildDuration.inMicroseconds / 1000)
        .toList();
    final rasterMs = _samples
        .map((sample) => sample.rasterDuration.inMicroseconds / 1000)
        .toList();
    final summary = FrameTimingSummary.fromDurations(
      buildMs: buildMs,
      rasterMs: rasterMs,
    );

    return DiagnosticReport(
      id: 'frame_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      projectName: 'runtime-session',
      metrics: <String, dynamic>{
        'max_samples': maxSamples,
        ...summary.toJson(),
      },
      limitations: _samples.isEmpty
          ? const <String>['No Flutter frame timings were collected.']
          : const <String>[],
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      if (_samples.length == maxSamples) {
        _samples.removeAt(0);
      }
      _samples.add(timing);
    }
  }
}
