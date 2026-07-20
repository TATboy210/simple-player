/// RegressionFixture — shared test harness for dual-track regression tests
/// (Phase 21 VERIFY-02).
///
/// Wraps a [MediaEngine] factory and a [DiffReport] to provide assertion
/// helpers that collect behavioral differences rather than failing immediately.
/// After all assertions in a test, call [assertNoDiffs] to fail the test if
/// any differences were collected.
///
/// Usage:
/// ```dart
/// final fixture = RegressionFixture(() => FvpEngine());
/// fixture.setUp();
/// // ... exercise engine ...
/// fixture.assertState(MediaState.idle, context: 'after open');
/// fixture.assertNoDiffs();
/// fixture.dispose();
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

import 'diff_report.dart';

/// Collects behavioral differences for a single engine instance under test.
///
/// Designed for parameterized dual-track regression: each factory (all-legacy
/// and all-migrated) gets its own RegressionFixture with the same test body.
/// Differences are accumulated in [report] and asserted at test end via
/// [assertNoDiffs].
class RegressionFixture {
  RegressionFixture(this._factory);

  final MediaEngine Function() _factory;
  late MediaEngine engine;
  final DiffReport report = DiffReport();

  /// Create a fresh engine from the factory.
  void setUp() {
    engine = _factory();
  }

  /// Dispose the engine. Call in tearDown.
  void dispose() {
    engine.dispose();
  }

  /// Assert that [engine.state.value] equals [expected].
  ///
  /// On mismatch, adds a [DiffEntry] to [report] rather than failing
  /// immediately — this allows collecting all differences in a single test
  /// run for comprehensive reporting.
  void assertState(MediaState expected, {String? context}) {
    final actual = engine.state.value;
    if (actual != expected) {
      report.addEntry(DiffEntry(
        method: 'state',
        expected: expected.toString(),
        actual: actual.toString(),
        context: context,
      ));
    }
  }

  /// Assert that a [ValueNotifier]'s current value equals [expected].
  ///
  /// Generic assertion for any ValueNotifier type. Adds [DiffEntry] on
  /// mismatch. [notifierName] identifies the notifier in the report.
  void assertNotifierEquals<T>(
    ValueNotifier<T> notifier,
    T expected,
    String notifierName, {
    String? context,
  }) {
    final actual = notifier.value;
    if (actual != expected) {
      report.addEntry(DiffEntry(
        method: notifierName,
        expected: expected.toString(),
        actual: actual.toString(),
        context: context,
      ));
    }
  }

  /// Assert that a callback was invoked exactly [expected] times.
  ///
  /// Adds [DiffEntry] if [actual] differs from [expected].
  void assertCallbackCount(
    String callback,
    int expected,
    int actual, {
    String? context,
  }) {
    if (actual != expected) {
      report.addEntry(DiffEntry(
        method: callback,
        expected: '$expected invocations',
        actual: '$actual invocations',
        context: context,
      ));
    }
  }

  /// Fail the test if any differences have been collected.
  ///
  /// Call this at the end of each test to verify zero behavioral differences.
  void assertNoDiffs() {
    if (report.hasDiffs) {
      fail(report.toString());
    }
  }
}
