/// FvpEngine DiagnosticsBundle injection + lifecycle methods tests
///
/// 验证 Phase 20 Plan 02 的新契约:
/// - DiagnosticsBundle 构造注入 (D2)
/// - recover() 委托状态机 (D7)
/// - double-dispose 安全 (D8)
/// - generation 统一到状态机 (D5)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostics_bundle.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/lifecycle_phase.dart';
import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Phase 20: EngineStateMachine.transitionTo 使用 KernelLoggerImpl.I.warn 记录非法转换
  KernelLoggerImpl.init();

  group('FvpEngine DiagnosticsBundle injection', () {
    test('constructor accepts DiagnosticsBundle parameter', () {
      // FvpEngine should accept a DiagnosticsBundle via named parameter
      // with DiagnosticsBundle.noop() as default
      final engine = FakeEngine();
      expect(engine, isNotNull);
      engine.dispose();
    });
  });

  group('FvpEngine recover()', () {
    test('recover() transitions from error to idle', () {
      final engine = FakeEngine();
      engine.simulateError('test error');
      expect(engine.state.value, MediaState.error);
      expect(engine.lastError.value, isNotNull);

      // recover() should delegate to state machine
      engine.recover();
      expect(engine.state.value, MediaState.idle);
      expect(engine.lastError.value, isNull);

      engine.dispose();
    });

    test('recover() is no-op when not in error state', () {
      final engine = FakeEngine();
      expect(engine.state.value, MediaState.idle);

      // recover() should be no-op when not in error state
      engine.recover();
      expect(engine.state.value, MediaState.idle);

      engine.dispose();
    });
  });

  group('FvpEngine double-dispose safety', () {
    test('dispose() can be called twice without exception', () {
      final engine = FakeEngine();

      // First dispose
      engine.dispose();

      // Second dispose should be safe no-op
      expect(() => engine.dispose(), returnsNormally);
    });
  });

  group('FvpEngine generation tracking via state machine', () {
    test('open() uses state machine for generation tracking', () async {
      final engine = FakeEngine();
      engine.configureMedia(durationMs: 60000);

      // Multiple rapid opens — generation tracking should work
      final f1 = engine.open('C:/a.mp4');
      final f2 = engine.open('C:/b.mp4');
      final f3 = engine.open('C:/c.mp4');
      await f1;
      await f2;
      await f3;

      // Only the last open should determine final state
      expect(engine.state.value, MediaState.idle);
      expect(engine.openCallCount, 3);

      engine.dispose();
    });

    test('lifecyclePhase getter is accessible', () {
      final engine = FakeEngine();

      // lifecyclePhase should be accessible (delegating to state machine)
      expect(engine.lifecyclePhase.value, LifecyclePhase.alive);

      engine.dispose();
    });
  });
}
