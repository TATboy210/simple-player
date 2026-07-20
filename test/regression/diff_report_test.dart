/// Unit tests for DiffEntry and DiffReport (Phase 21 VERIFY-02).
///
/// Validates formatting, accumulation, and hasDiffs behavior before
/// the regression fixture depends on them.
library;

import 'package:flutter_test/flutter_test.dart';

import 'diff_report.dart';

void main() {
  group('DiffEntry', () {
    test('toString formats without context', () {
      const entry = DiffEntry(
        method: 'state',
        expected: 'MediaState.idle',
        actual: 'MediaState.playing',
      );
      expect(entry.toString(), '[state] expected: MediaState.idle, actual: MediaState.playing');
    });

    test('toString formats with context', () {
      const entry = DiffEntry(
        method: 'volume',
        expected: '0.5',
        actual: '0.8',
        context: 'after setVolume(0.5)',
      );
      expect(
        entry.toString(),
        '[volume] expected: 0.5, actual: 0.8 (after setVolume(0.5))',
      );
    });
  });

  group('DiffReport', () {
    test('hasDiffs is false when empty', () {
      final report = DiffReport();
      expect(report.hasDiffs, isFalse);
      expect(report.diffCount, 0);
    });

    test('hasDiffs is true after adding entry', () {
      final report = DiffReport();
      report.addEntry(const DiffEntry(
        method: 'state',
        expected: 'idle',
        actual: 'playing',
      ));
      expect(report.hasDiffs, isTrue);
      expect(report.diffCount, 1);
    });

    test('toString returns summary with no diffs', () {
      final report = DiffReport();
      expect(report.toString(), 'DiffReport: 0 differences');
    });

    test('toString returns formatted diffs', () {
      final report = DiffReport();
      report.addEntry(const DiffEntry(
        method: 'state',
        expected: 'idle',
        actual: 'playing',
      ));
      report.addEntry(const DiffEntry(
        method: 'volume',
        expected: '0.5',
        actual: '0.8',
      ));
      final output = report.toString();
      expect(output, contains('2 difference(s)'));
      expect(output, contains('[state]'));
      expect(output, contains('[volume]'));
    });
  });
}
