import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/window_bridge/window_resize_diagnostics.dart';

/// RESIZE_DIAG opt-in 门控 — 默认关闭, Release 恒关, 请求时启动并可停止.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  test('compile-time flag defaults to off without --dart-define', () {
    expect(resizeDiagnosticsRequested, isFalse);
  });

  test('returns null when diagnostics are not requested', () {
    final diagnostics = startResizeDiagnosticsIfRequested(
      logger: KernelLogger.I,
      requested: false,
      releaseMode: false,
    );
    expect(diagnostics, isNull);
  });

  test('returns null in release mode even when requested', () {
    final diagnostics = startResizeDiagnosticsIfRequested(
      logger: KernelLogger.I,
      requested: true,
      releaseMode: true,
    );
    expect(diagnostics, isNull);
  });

  test('starts a running collector when requested outside release', () {
    final diagnostics = startResizeDiagnosticsIfRequested(
      logger: KernelLogger.I,
      requested: true,
      releaseMode: false,
    );
    expect(diagnostics, isNotNull);
    expect(diagnostics?.isRunning, isTrue);
    diagnostics?.stop();
    expect(diagnostics?.isRunning, isFalse);
  });
}
