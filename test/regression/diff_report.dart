/// DiffReport — collects and formats behavioral differences for dual-track
/// regression testing (Phase 21 VERIFY-02).
///
/// Each [DiffEntry] records a single discrepancy between expected and actual
/// values. [DiffReport] accumulates entries and provides a human-readable
/// summary for test failure messages.
library;

/// A single behavioral difference entry.
///
/// Records the method under test, the expected value, the actual observed
/// value, and an optional context string for disambiguation.
class DiffEntry {
  const DiffEntry({
    required this.method,
    required this.expected,
    required this.actual,
    this.context,
  });

  /// The method or operation that produced the difference.
  final String method;

  /// The expected value (stringified).
  final String expected;

  /// The actual observed value (stringified).
  final String actual;

  /// Optional context — e.g. notifier name, call sequence number.
  final String? context;

  @override
  String toString() {
    final ctx = context != null ? ' ($context)' : '';
    return '[$method] expected: $expected, actual: $actual$ctx';
  }
}

/// Accumulates [DiffEntry] items and produces a summary report.
///
/// Usage:
/// ```dart
/// final report = DiffReport();
/// if (engine.state.value != expectedState) {
///   report.addEntry(DiffEntry(
///     method: 'state',
///     expected: expectedState.toString(),
///     actual: engine.state.value.toString(),
///   ));
/// }
/// assert(!report.hasDiffs, report.toString());
/// ```
class DiffReport {
  final List<DiffEntry> _diffs = [];

  /// Add a difference entry to the report.
  void addEntry(DiffEntry entry) {
    _diffs.add(entry);
  }

  /// Whether any differences have been recorded.
  bool get hasDiffs => _diffs.isNotEmpty;

  /// Number of recorded differences.
  int get diffCount => _diffs.length;

  /// Human-readable summary of all recorded differences.
  @override
  String toString() {
    if (_diffs.isEmpty) return 'DiffReport: 0 differences';
    final lines = _diffs.map((e) => '  ${e.toString()}').join('\n');
    return 'DiffReport: ${_diffs.length} difference(s):\n$lines';
  }
}
