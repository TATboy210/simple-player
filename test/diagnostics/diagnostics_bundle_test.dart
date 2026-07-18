/// Unit tests for `DiagnosticsBundle` (ADAPT-02) — construction, the 4
/// noop slots being safely callable, and cascading dispose.
///
/// Phase 16 ships `DiagnosticsBundle.noop()` as deliberate dead code (D2/D3)
/// — no consumer reads the bundle yet. These tests only prove the skeleton
/// is structurally sound: it constructs, every slot is a callable no-op,
/// and dispose() cascades without throwing (mirrors PlayerServices.dispose(),
/// D10).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostics_bundle.dart';

void main() {
  group('DiagnosticsBundle.noop()', () {
    test('constructs without error', () {
      // Arrange + Act
      const bundle = DiagnosticsBundle.noop();

      // Assert
      expect(bundle, isNotNull);
    });

    test('all 4 slots are non-null and callable as no-ops', () {
      // Arrange
      const bundle = DiagnosticsBundle.noop();

      // Act + Assert — logger
      expect(bundle.logger, isNotNull);
      expect(() => bundle.logger.info('x'), returnsNormally);
      expect(() => bundle.logger.debug('x'), returnsNormally);
      expect(() => bundle.logger.warn('x'), returnsNormally);
      expect(
        () => bundle.logger.error('x', error: Exception('e')),
        returnsNormally,
      );

      // Act + Assert — metrics
      expect(bundle.metrics, isNotNull);
      expect(() => bundle.metrics.recordOpen(success: true), returnsNormally);
      expect(bundle.metrics.toJson(), isEmpty);

      // Act + Assert — eventLog
      expect(bundle.eventLog, isNotNull);
      expect(() => bundle.eventLog.add('open'), returnsNormally);
      expect(bundle.eventLog.entries, isEmpty);

      // Act + Assert — memoryMonitor
      expect(bundle.memoryMonitor, isNotNull);
      expect(bundle.memoryMonitor.snapshot(), isNull);
      expect(() => bundle.memoryMonitor.start(), returnsNormally);
    });

    test('dispose() cascades over noop slots without throwing', () {
      // Arrange
      const bundle = DiagnosticsBundle.noop();

      // Act + Assert
      expect(bundle.dispose, returnsNormally);
    });
  });
}
