import 'dart:convert';
import '../core/models.dart';
import 'performance_investigator.dart';

/// Structured analysis status for performance trace parsing and evaluation.
enum PerformanceAnalysisStatus {
  /// Performance data parsed successfully with valid frame timings.
  valid,

  /// Input was empty, whitespace-only, or contained 0 frames.
  emptyInput,

  /// Input was malformed JSON that failed parsing.
  invalidJson,

  /// Valid JSON structure, but does not match any recognized performance trace schema.
  unsupportedSchema,

  /// Expected fields were missing or null in frame objects.
  missingFields,

  /// Numeric values contained NaN, Infinity, or negative durations.
  invalidValues,

  /// Trace events contained unclosed begin/end ranges or cut-off records.
  truncatedTrace,
}

/// Comprehensive parse result from performance trace/metric input.
class PerformanceParseResult {
  const PerformanceParseResult({
    required this.status,
    this.summary,
    this.issues = const [],
    this.warnings = const [],
    this.limitations = const [],
    this.evidence = const [],
    this.rawFrameCount = 0,
  });

  final PerformanceAnalysisStatus status;
  final FrameTimingSummary? summary;
  final List<DiagnosticIssue> issues;
  final List<String> warnings;
  final List<String> limitations;
  final List<EvidenceReference> evidence;
  final int rawFrameCount;

  bool get isValid => status == PerformanceAnalysisStatus.valid;
}

/// Parser capable of reading DevTools trace events, raw frame lists, and pre-summarized metrics.
class PerformanceInputParser {
  const PerformanceInputParser();

  /// Parses raw JSON text or decoded JSON object into a [PerformanceParseResult].
  static PerformanceParseResult parse(
    dynamic input, {
    double refreshRateHz = 60.0,
    int maxTraceEvents = 50000,
  }) {
    final effectiveRefreshRate = _validateRefreshRate(refreshRateHz);

    if (input == null) {
      return const PerformanceParseResult(
        status: PerformanceAnalysisStatus.emptyInput,
        limitations: ['Performance trace input is null.'],
      );
    }

    dynamic decodedJson = input;
    if (input is String) {
      final trimmed = input.trim();
      if (trimmed.isEmpty) {
        return const PerformanceParseResult(
          status: PerformanceAnalysisStatus.emptyInput,
          limitations: ['Performance trace input string is empty.'],
        );
      }
      try {
        decodedJson = jsonDecode(trimmed);
      } on FormatException catch (e) {
        return PerformanceParseResult(
          status: PerformanceAnalysisStatus.invalidJson,
          limitations: ['Invalid JSON syntax: ${e.message}'],
        );
      }
    }

    if (decodedJson is Map<String, dynamic>) {
      return _parseJsonObject(
        decodedJson,
        refreshRateHz: effectiveRefreshRate,
        maxTraceEvents: maxTraceEvents,
      );
    } else if (decodedJson is List) {
      return _parseJsonArray(
        decodedJson,
        refreshRateHz: effectiveRefreshRate,
        maxTraceEvents: maxTraceEvents,
      );
    }

    return const PerformanceParseResult(
      status: PerformanceAnalysisStatus.unsupportedSchema,
      limitations: [
        'Unsupported performance input structure. Expected JSON object or JSON array.',
      ],
    );
  }

  static double _validateRefreshRate(double refreshRateHz) {
    if (refreshRateHz.isNaN ||
        refreshRateHz.isInfinite ||
        refreshRateHz < 1.0 ||
        refreshRateHz > 240.0) {
      return 60.0;
    }
    return refreshRateHz;
  }

  static PerformanceParseResult _parseJsonObject(
    Map<String, dynamic> json, {
    required double refreshRateHz,
    int maxTraceEvents = 50000,
  }) {
    final warnings = <String>[];
    final limitations = <String>[];

    // Schema 1: DevTools / Chrome Trace Format (traceEvents key)
    if (json.containsKey('traceEvents')) {
      final rawEvents = json['traceEvents'];
      if (rawEvents is! List) {
        return const PerformanceParseResult(
          status: PerformanceAnalysisStatus.unsupportedSchema,
          limitations: ['"traceEvents" key must be a JSON array.'],
        );
      }
      return _parseDevToolsTraceEvents(
        rawEvents,
        refreshRateHz: refreshRateHz,
        maxTraceEvents: maxTraceEvents,
      );
    }

    // Schema 2: Pre-summarized metrics object
    if (json.containsKey('frame_count') ||
        json.containsKey('p90_frame_ms') ||
        json.containsKey('average_build_ms')) {
      return _parseSummarizedMetrics(json, refreshRateHz: refreshRateHz);
    }

    // Schema 3: Object wrapping a frames list: { "frames": [...] }
    if (json.containsKey('frames') && json['frames'] is List) {
      return _parseJsonArray(
        json['frames'] as List,
        refreshRateHz: refreshRateHz,
      );
    }

    if (json.isEmpty) {
      return const PerformanceParseResult(
        status: PerformanceAnalysisStatus.emptyInput,
        limitations: ['JSON object is empty.'],
      );
    }

    warnings.add('Unrecognized top-level JSON fields: ${json.keys.join(', ')}');
    limitations.add(
      'Performance analysis requires recognized traceEvents, frames list, or summary metrics.',
    );

    return PerformanceParseResult(
      status: PerformanceAnalysisStatus.unsupportedSchema,
      warnings: warnings,
      limitations: limitations,
    );
  }

  static PerformanceParseResult _parseDevToolsTraceEvents(
    List<dynamic> events, {
    required double refreshRateHz,
    int maxTraceEvents = 50000,
  }) {
    if (events.isEmpty) {
      return const PerformanceParseResult(
        status: PerformanceAnalysisStatus.emptyInput,
        limitations: ['DevTools traceEvents array is empty.'],
      );
    }

    final totalEvents = events.length;
    var isTruncatedByLimit = false;
    List<dynamic> effectiveEvents = events;
    if (maxTraceEvents > 0 && events.length > maxTraceEvents) {
      effectiveEvents = events.take(maxTraceEvents).toList();
      isTruncatedByLimit = true;
    }

    final buildMs = <double>[];
    final rasterMs = <double>[];
    final openEvents = <String, double>{};
    var hasInvalidValues = false;
    var hasTruncatedEvents = false;

    for (final event in effectiveEvents) {
      if (event is! Map) continue;

      final name = event['name']?.toString() ?? '';
      final ph = event['ph']?.toString() ?? '';
      final ts = _extractTimestamp(event);

      // Duration event: ph == 'X'
      if (ph == 'X') {
        final dur = _extractDurationMs(event);
        if (dur == null || dur.isNaN || dur.isInfinite || dur < 0) {
          if (dur != null) hasInvalidValues = true;
          continue;
        }
        _categorizeDuration(name, dur, buildMs, rasterMs);
      }
      // Begin event: ph == 'B'
      else if (ph == 'B' && ts != null) {
        openEvents[name] = ts;
      }
      // End event: ph == 'E'
      else if (ph == 'E' && ts != null) {
        if (openEvents.containsKey(name)) {
          final startTs = openEvents.remove(name)!;
          final durMs = (ts - startTs) / 1000.0;
          if (durMs >= 0 && !durMs.isNaN && !durMs.isInfinite) {
            _categorizeDuration(name, durMs, buildMs, rasterMs);
          } else {
            hasInvalidValues = true;
          }
        } else {
          hasTruncatedEvents = true;
        }
      }
    }

    if (openEvents.isNotEmpty) {
      hasTruncatedEvents = true;
    }

    if (buildMs.isEmpty && rasterMs.isEmpty) {
      return PerformanceParseResult(
        status: hasTruncatedEvents
            ? PerformanceAnalysisStatus.truncatedTrace
            : (hasInvalidValues
                  ? PerformanceAnalysisStatus.invalidValues
                  : PerformanceAnalysisStatus.emptyInput),
        limitations: const [
          'No valid Flutter UI build or GPU raster events recognized in trace.',
        ],
      );
    }

    final summary = FrameTimingSummary.fromDurations(
      buildMs: buildMs,
      rasterMs: rasterMs,
      refreshRateHz: refreshRateHz,
    );

    final issues = summary.generateRecommendations();
    final warnings = <String>[];
    if (isTruncatedByLimit) {
      warnings.add(
        'DevTools trace events array exceeded limit of $maxTraceEvents events and was truncated ($totalEvents total events).',
      );
    }
    if (hasInvalidValues) {
      warnings.add(
        'Skipped trace events with negative, NaN, or infinite durations.',
      );
    }
    if (hasTruncatedEvents) {
      warnings.add(
        'Trace contained unmatched Begin/End events (truncated trace).',
      );
    }

    return PerformanceParseResult(
      status: PerformanceAnalysisStatus.valid,
      summary: summary,
      issues: issues,
      warnings: warnings,
      rawFrameCount: summary.frameCount,
    );
  }

  static PerformanceParseResult _parseJsonArray(
    List<dynamic> array, {
    required double refreshRateHz,
    int maxTraceEvents = 50000,
  }) {
    if (array.isEmpty) {
      return const PerformanceParseResult(
        status: PerformanceAnalysisStatus.emptyInput,
        limitations: ['Frame duration array is empty.'],
      );
    }

    final totalItems = array.length;
    var isTruncatedByLimit = false;
    List<dynamic> effectiveArray = array;
    if (maxTraceEvents > 0 && array.length > maxTraceEvents) {
      effectiveArray = array.take(maxTraceEvents).toList();
      isTruncatedByLimit = true;
    }

    final buildMs = <double>[];
    final rasterMs = <double>[];
    var hasInvalidValues = false;

    for (final item in effectiveArray) {
      if (item is num) {
        final val = item.toDouble();
        if (val.isNaN || val.isInfinite || val < 0) {
          hasInvalidValues = true;
          continue;
        }
        // Auto-detect microsecond vs millisecond values
        final ms = val > 1000 ? val / 1000.0 : val;
        buildMs.add(ms);
        rasterMs.add(0.0);
      } else if (item is Map) {
        final b = _extractNum(item, [
          'buildMs',
          'build_ms',
          'buildDuration',
          'build',
        ]);
        final r = _extractNum(item, [
          'rasterMs',
          'raster_ms',
          'rasterDuration',
          'raster',
          'gpu',
        ]);

        var bMs = b ?? 0.0;
        var rMs = r ?? 0.0;

        if (bMs.isNaN ||
            bMs.isInfinite ||
            bMs < 0 ||
            rMs.isNaN ||
            rMs.isInfinite ||
            rMs < 0) {
          hasInvalidValues = true;
          continue;
        }

        // Unit conversion if specified
        final unit = item['unit']?.toString().toLowerCase() ?? '';
        if (unit == 'us' || unit == 'micros' || unit == 'microseconds') {
          bMs /= 1000.0;
          rMs /= 1000.0;
        } else if (bMs > 1000 || rMs > 1000) {
          bMs /= 1000.0;
          rMs /= 1000.0;
        }

        buildMs.add(bMs);
        rasterMs.add(rMs);
      }
    }

    if (buildMs.isEmpty && rasterMs.isEmpty) {
      return PerformanceParseResult(
        status: hasInvalidValues
            ? PerformanceAnalysisStatus.invalidValues
            : PerformanceAnalysisStatus.emptyInput,
        limitations: const ['No valid numeric frame durations found in array.'],
      );
    }

    final summary = FrameTimingSummary.fromDurations(
      buildMs: buildMs,
      rasterMs: rasterMs,
      refreshRateHz: refreshRateHz,
    );

    final issues = summary.generateRecommendations();
    final warnings = <String>[];
    if (isTruncatedByLimit) {
      warnings.add(
        'Frame duration array exceeded limit of $maxTraceEvents items and was truncated ($totalItems total items).',
      );
    }
    if (hasInvalidValues) {
      warnings.add(
        'Skipped invalid frame items containing NaN, Infinity, or negative durations.',
      );
    }

    return PerformanceParseResult(
      status: PerformanceAnalysisStatus.valid,
      summary: summary,
      issues: issues,
      warnings: warnings,
      rawFrameCount: summary.frameCount,
    );
  }

  static PerformanceParseResult _parseSummarizedMetrics(
    Map<String, dynamic> json, {
    required double refreshRateHz,
  }) {
    try {
      final summary = FrameTimingSummary.fromJson(
        json,
        refreshRateHz: refreshRateHz,
      );
      final issues = summary.generateRecommendations();

      return PerformanceParseResult(
        status: PerformanceAnalysisStatus.valid,
        summary: summary,
        issues: issues,
        rawFrameCount: summary.frameCount,
      );
    } catch (e) {
      return PerformanceParseResult(
        status: PerformanceAnalysisStatus.missingFields,
        limitations: ['Failed to parse summary metrics: $e'],
      );
    }
  }

  static void _categorizeDuration(
    String name,
    double durMs,
    List<double> buildMs,
    List<double> rasterMs,
  ) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('build') ||
        lowerName.contains('vsync') ||
        lowerName.contains('animate') ||
        lowerName.contains('pipelineproduceargs') ||
        lowerName.contains('engine::beginframe')) {
      buildMs.add(durMs);
    } else if (lowerName.contains('raster') ||
        lowerName.contains('gpu') ||
        lowerName.contains('gpurasterizer') ||
        lowerName.contains('engine::render')) {
      rasterMs.add(durMs);
    }
  }

  static double? _extractTimestamp(Map event) {
    final ts = event['ts'];
    if (ts is num && !ts.isNaN && !ts.isInfinite) {
      return ts.toDouble();
    }
    return null;
  }

  static double? _extractDurationMs(Map event) {
    num? rawDur = event['dur'] as num?;
    if (rawDur == null && event['args'] is Map) {
      rawDur = event['args']['dur'] as num?;
    }
    if (rawDur == null) return null;
    final val = rawDur.toDouble();
    if (val.isNaN || val.isInfinite) return null;
    // DevTools dur is in microseconds
    return val / 1000.0;
  }

  static double? _extractNum(Map map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final val = map[key];
        if (val is num) return val.toDouble();
      }
    }
    return null;
  }
}
