import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

/// RendererControl contract tests (D13 parameterized over a factory).
///
/// Mirrors the frozen `///` contract tags on [RendererControl]:
/// `setD3d11SyncEnabled`/`setHardwareDecoding` both have
/// `modifies: 无 ValueNotifier` — neither writes back to any
/// [EngineStateView] getter (D3D11Configurator is a delegate, not reflected
/// in state). Both are therefore asserted via `returnsNormally` only
/// (D20 static-behavior-only — no rendering-pipeline-visible side effect
/// without a live D3D11 surface).
///
/// D13: parameterized over a `MediaEngine Function()` factory — never
/// instantiates a concrete engine directly, so Phase 21 can reuse this
/// exact test body against `NewFvpEngine`.
void runRendererControlContractTests(MediaEngine Function() createEngine) {
  group('RendererControl contract', () {
    late MediaEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('setD3d11SyncEnabled()', () {
      test('returns normally for both enable states (modifies: 无 ValueNotifier)', () {
        expect(() => engine.setD3d11SyncEnabled(true), returnsNormally);
        expect(() => engine.setD3d11SyncEnabled(false), returnsNormally);
      });
    });

    group('setHardwareDecoding()', () {
      test('returns normally for both enable states (modifies: 无 ValueNotifier)', () {
        expect(() => engine.setHardwareDecoding(true), returnsNormally);
        expect(() => engine.setHardwareDecoding(false), returnsNormally);
      });
    });
  });
}
