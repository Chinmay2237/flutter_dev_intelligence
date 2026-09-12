import 'dart:io';

import '../core/config.dart';

/// Result of discovering Dart source files for static analysis.
class DiscoveryResult {
  const DiscoveryResult({
    required this.discoveredPaths,
    required this.skippedFiles,
  });

  /// List of normalized, sorted relative file paths ready for analysis.
  final List<String> discoveredPaths;

  /// List of warnings for files skipped due to size limits or filesystem issues.
  final List<String> skippedFiles;
}

/// Discovers, filters, and normalizes Dart source files for AST analysis.
class AstSourceDiscoverer {
  const AstSourceDiscoverer({
    this.maxSizeBytes = 2 * 1024 * 1024, // 2MB limit
  });

  /// Maximum file size in bytes to allow for AST parsing.
  final int maxSizeBytes;

  /// Discovers all matching Dart source files below [rootDirectoryPath].
  Future<DiscoveryResult> discover(
    String rootDirectoryPath, {
    ProjectConfig config = const ProjectConfig(),
  }) async {
    final rootDir = Directory(rootDirectoryPath);
    if (!await rootDir.exists()) {
      return const DiscoveryResult(
        discoveredPaths: <String>[],
        skippedFiles: <String>[],
      );
    }

    final discovered = <String>[];
    final skipped = <String>[];
    final visitedRealPaths = <String>{};

    try {
      final entities = await rootDir
          .list(recursive: true, followLinks: true)
          .toList();

      for (final entity in entities) {
        if (entity is! File) continue;

        final rawPath = entity.path;
        final normPath = normalizePath(rawPath);

        if (!normPath.endsWith('.dart')) continue;

        // Check canonical real path to prevent circular symlink loops or duplicate scanning
        String realPath;
        try {
          realPath = entity.resolveSymbolicLinksSync();
        } catch (_) {
          realPath = entity.absolute.path;
        }

        if (visitedRealPaths.contains(realPath)) {
          continue;
        }
        visitedRealPaths.add(realPath);

        // Path exclusion filters
        if (config.shouldExcludePath(normPath)) {
          continue;
        }

        // Large file safeguard check
        try {
          final size = await entity.length();
          final effectiveLimit =
              (config.maxFileSizeBytes > 0 &&
                  config.maxFileSizeBytes < maxSizeBytes)
              ? config.maxFileSizeBytes
              : maxSizeBytes;
          if (size > effectiveLimit) {
            skipped.add(
              'Skipped large file $normPath (${(size / 1024 / 1024).toStringAsFixed(2)}MB exceeds ${(effectiveLimit / (1024 * 1024)).toStringAsFixed(1)}MB limit).',
            );
            continue;
          }
        } catch (e) {
          skipped.add('Could not read file size for $normPath: $e');
          continue;
        }

        discovered.add(normPath);
      }
    } catch (e) {
      skipped.add('Error during directory traversal of $rootDirectoryPath: $e');
    }

    discovered.sort();

    return DiscoveryResult(discoveredPaths: discovered, skippedFiles: skipped);
  }
}
