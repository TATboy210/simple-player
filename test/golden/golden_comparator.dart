import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Custom golden file comparator with per-channel pixel tolerance.
///
/// Handles cross-machine rendering differences (font anti-aliasing,
/// GPU precision) to prevent false positives in visual regression tests.
///
/// Based on Flutter's documented tolerant comparator pattern.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(
    super.testFile, {
    this.tolerance = 0.05,
    this.maxMismatchRate = 0.01,
  });

  /// Per-channel tolerance (0.0–1.0). Default 5% = 12.75/255.
  final double tolerance;

  /// Maximum fraction of mismatched pixels allowed. Default 1%.
  final double maxMismatchRate;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenFile = _goldenFile(golden);

    if (!goldenFile.existsSync()) {
      // First run: create the golden file.
      goldenFile.parent.createSync(recursive: true);
      goldenFile.writeAsBytesSync(imageBytes);
      debugPrint('Golden created: $golden');
      return true;
    }

    final expectedBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final actual = await _decodeImage(imageBytes);
    final expected = await _decodeImage(expectedBytes);

    if (actual.width != expected.width || actual.height != expected.height) {
      debugPrint(
        'Golden size mismatch: ${actual.width}x${actual.height} '
        'vs ${expected.width}x${expected.height}',
      );
      return false;
    }

    final actualData = await actual.toByteData();
    final expectedData = await expected.toByteData();
    if (actualData == null || expectedData == null) return false;

    final totalPixels = actual.width * actual.height;
    final threshold = (tolerance * 255).round();
    var mismatched = 0;

    for (var i = 0; i < totalPixels * 4; i += 4) {
      final rDiff =
          (actualData.getUint8(i) - expectedData.getUint8(i)).abs();
      final gDiff =
          (actualData.getUint8(i + 1) - expectedData.getUint8(i + 1)).abs();
      final bDiff =
          (actualData.getUint8(i + 2) - expectedData.getUint8(i + 2)).abs();
      final aDiff =
          (actualData.getUint8(i + 3) - expectedData.getUint8(i + 3)).abs();

      if (rDiff > threshold ||
          gDiff > threshold ||
          bDiff > threshold ||
          aDiff > threshold) {
        mismatched++;
      }
    }

    final mismatchRate = mismatched / totalPixels;
    if (mismatchRate > maxMismatchRate) {
      debugPrint(
        'Golden mismatch: ${(mismatchRate * 100).toStringAsFixed(2)}% pixels '
        'exceeded ${tolerance * 100}% tolerance '
        '(max ${(maxMismatchRate * 100).toStringAsFixed(1)}%)',
      );
      return false;
    }

    return true;
  }

  File _goldenFile(Uri golden) {
    final basePath = p.fromUri(basedir);
    final goldenPath = p.fromUri(golden.path);
    return File(p.join(basePath, goldenPath));
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }
}

/// Register the tolerant golden comparator for the current test file.
///
/// Call in `setUp()` or at the top of `main()`.
void enableTolerantGoldens({double tolerance = 0.05}) {
  goldenFileComparator = TolerantGoldenComparator(
    Uri.parse('test/golden/_dummy_test.dart'),
    tolerance: tolerance,
  );
}

/// Wrap a widget in a consistent dark background for golden tests.
///
/// Uses 800x600 SizedBox with the player's dark theme color.
Widget wrapForGolden(Widget child) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: SizedBox(
          width: 800,
          height: 600,
          child: child,
        ),
      ),
    ),
  );
}
