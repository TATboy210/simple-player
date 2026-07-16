/// Unit tests for [EngineMetrics].
///
/// Covers: counters, computed properties (averageSeekTime, openSuccessRate),
/// record methods, reset, toJson.
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_metrics.dart';

void main() {
  late EngineMetrics metrics;

  setUp(() {
    metrics = EngineMetrics();
  });

  group('EngineMetrics', () {
    group('initial state', () {
      test('all counters are zero', () {
        expect(metrics.framesDropped, 0);
        expect(metrics.decodeErrors, 0);
        expect(metrics.bufferUnderruns, 0);
        expect(metrics.openAttempts, 0);
        expect(metrics.openFailures, 0);
      });

      test('averageSeekTime is zero when no seeks', () {
        expect(metrics.averageSeekTime, Duration.zero);
      });

      test('openSuccessRate is zero when no attempts', () {
        expect(metrics.openSuccessRate, 0);
      });
    });

    group('recordOpen', () {
      test('increments attempts on success', () {
        metrics.recordOpen(success: true);
        expect(metrics.openAttempts, 1);
        expect(metrics.openFailures, 0);
      });

      test('increments attempts and failures on failure', () {
        metrics.recordOpen(success: false);
        expect(metrics.openAttempts, 1);
        expect(metrics.openFailures, 1);
      });

      test('calculates success rate correctly', () {
        metrics.recordOpen(success: true);
        metrics.recordOpen(success: true);
        metrics.recordOpen(success: false);
        expect(metrics.openSuccessRate, closeTo(2 / 3, 0.001));
      });

      test('all failures gives 0% success rate', () {
        metrics.recordOpen(success: false);
        metrics.recordOpen(success: false);
        expect(metrics.openSuccessRate, 0);
      });

      test('all successes gives 100% success rate', () {
        metrics.recordOpen(success: true);
        metrics.recordOpen(success: true);
        expect(metrics.openSuccessRate, 1.0);
      });
    });

    group('recordSeek', () {
      test('calculates average seek time', () {
        metrics.recordSeek(const Duration(milliseconds: 100));
        metrics.recordSeek(const Duration(milliseconds: 200));
        expect(metrics.averageSeekTime, const Duration(milliseconds: 150));
      });

      test('single seek returns that duration', () {
        metrics.recordSeek(const Duration(milliseconds: 50));
        expect(metrics.averageSeekTime, const Duration(milliseconds: 50));
      });

      test('integer division for average', () {
        metrics.recordSeek(const Duration(milliseconds: 100));
        metrics.recordSeek(const Duration(milliseconds: 200));
        metrics.recordSeek(const Duration(milliseconds: 300));
        expect(metrics.averageSeekTime, const Duration(milliseconds: 200));
      });
    });

    group('recordFrameDrop', () {
      test('increments by 1 by default', () {
        metrics.recordFrameDrop();
        expect(metrics.framesDropped, 1);
      });

      test('increments by custom count', () {
        metrics.recordFrameDrop(5);
        expect(metrics.framesDropped, 5);
      });

      test('accumulates across calls', () {
        metrics.recordFrameDrop(3);
        metrics.recordFrameDrop(2);
        expect(metrics.framesDropped, 5);
      });
    });

    group('recordDecodeError', () {
      test('increments decode errors', () {
        metrics.recordDecodeError();
        metrics.recordDecodeError();
        expect(metrics.decodeErrors, 2);
      });
    });

    group('recordBufferUnderrun', () {
      test('increments buffer underruns', () {
        metrics.recordBufferUnderrun();
        expect(metrics.bufferUnderruns, 1);
      });
    });

    group('reset', () {
      test('clears all counters', () {
        metrics.recordFrameDrop(5);
        metrics.recordDecodeError();
        metrics.recordBufferUnderrun();
        metrics.recordOpen(success: true);
        metrics.recordOpen(success: false);
        metrics.recordSeek(const Duration(milliseconds: 100));

        metrics.reset();

        expect(metrics.framesDropped, 0);
        expect(metrics.decodeErrors, 0);
        expect(metrics.bufferUnderruns, 0);
        expect(metrics.openAttempts, 0);
        expect(metrics.openFailures, 0);
        expect(metrics.averageSeekTime, Duration.zero);
        expect(metrics.openSuccessRate, 0);
      });
    });

    group('toJson', () {
      test('exports all fields', () {
        metrics.recordFrameDrop(3);
        metrics.recordDecodeError();
        metrics.recordBufferUnderrun();
        metrics.recordOpen(success: true);
        metrics.recordOpen(success: false);
        metrics.recordSeek(const Duration(milliseconds: 100));
        metrics.recordSeek(const Duration(milliseconds: 200));

        final json = metrics.toJson();
        expect(json['framesDropped'], 3);
        expect(json['decodeErrors'], 1);
        expect(json['bufferUnderruns'], 1);
        expect(json['averageSeekTimeMs'], 150);
        expect(json['openAttempts'], 2);
        expect(json['openFailures'], 1);
        expect(json['openSuccessRate'], '50.0');
      });

      test('returns zero values when empty', () {
        final json = metrics.toJson();
        expect(json['framesDropped'], 0);
        expect(json['decodeErrors'], 0);
        expect(json['bufferUnderruns'], 0);
        expect(json['averageSeekTimeMs'], 0);
        expect(json['openAttempts'], 0);
        expect(json['openFailures'], 0);
        expect(json['openSuccessRate'], '0.0');
      });
    });
  });
}
