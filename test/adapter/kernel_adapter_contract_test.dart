/// Contract test mount point — mounts all 7 ISP interface contract groups
/// against `KernelAdapter` wrapping a real `FvpEngine` (D24 layer 2).
///
/// This is the identical `run*ContractTests` reuse seam documented in
/// `test/contracts/contract_test_runner.dart`: only the factory changes
/// (`FvpEngine()` -> `KernelAdapter(legacy: fvp, migrated: fvp, ...)`), the
/// test bodies never reference a concrete engine type. Passing here proves
/// that all 7 sub-interface contracts forward faithfully through the
/// Strangler Fig seam (ADAPT-01) while `DelegationPolicy.all(KernelMode.legacy)`
/// routes 100% of calls to the wrapped `FvpEngine` — behavior identical to
/// mounting the contracts directly against `FvpEngine` (see the analog,
/// `test/engine/fvp_engine_contract_test.dart`).
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/adapter/kernel_adapter.dart';
import 'package:simple_player_flutter/kernel/engine/fvp_engine.dart';

import '../contracts/contract_test_runner.dart';

// Headless `flutter test` runs the Dart VM only — there is no live Windows
// embedder, so the native platform-channel handler that `package:fvp`
// registers for GPU texture creation (`CreateRT`/`ReleaseRT` on the `fvp`
// channel, see MethodChannelFvp.createTexture) never gets a native-side
// implementation. Without a mock, every open() on a real FvpEngine reaches
// MediaOpener.open() -> Player.updateTexture() -> createTexture() and
// throws MissingPluginException, which FvpEngine.open() catches and reports
// as a generic PlaybackError -- masking the fact that decode (prepare(),
// mediaInfo) genuinely succeeded.
//
// KernelAdapter wraps a real FvpEngine under the hood (Phase 16: legacy ==
// migrated == the same FvpEngine instance, all-legacy policy), so it hits
// the exact same headless native-texture gap as the direct FvpEngine mount.
// This mock replaces ONLY the texture-registration RPC with a fake
// monotonically-increasing texture id — copied verbatim from
// test/engine/fvp_engine_contract_test.dart to preserve D13 (contract tests
// gate the REAL FvpEngine, never a fake engine) through the adapter seam.
const _fvpChannel = MethodChannel('fvp');
int _nextFakeTextureId = 1;

void _installFvpTextureChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_fvpChannel, (call) async {
        switch (call.method) {
          case 'CreateRT':
            // Real native side returns a texture id (int) registered with the
            // Flutter engine's texture registry. Headless tests never render a
            // frame, so any stable non-negative int satisfies callers that only
            // check `>= 0` / store it for later ReleaseRT.
            return _nextFakeTextureId++;
          case 'ReleaseRT':
            // dispose()/updateTexture(width: -1) call this; no return value used.
            return null;
          default:
            return null;
        }
      });
}

/// Local factory — wraps a fresh `FvpEngine` in a `KernelAdapter` with
/// Phase 16's dead-routing policy (100% legacy, ADAPT-04 satisfied
/// elsewhere per D20/16-05, not by an adapter-layer test here).
KernelAdapter makeAdapter() {
  final fvp = FvpEngine();
  return KernelAdapter(
    legacy: fvp,
    migrated: fvp,
    policy: const DelegationPolicy.all(KernelMode.legacy),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  runEngineStateViewContractTests(makeAdapter);
  runPlaybackControlContractTests(makeAdapter);
  runTrackControlContractTests(makeAdapter);
  runSubtitleConfigContractTests(makeAdapter);
  runVideoEffectControlContractTests(makeAdapter);
  runRendererControlContractTests(makeAdapter);
  runVolumeControlContractTests(makeAdapter);
}
