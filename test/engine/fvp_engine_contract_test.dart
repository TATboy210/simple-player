/// Contract test mount point — mounts all 7 ISP interface contract groups
/// against the REAL FvpEngine (D13: real implementation is the gate
/// subject, never FakeEngine).
///
/// This is the migration gate for BASE-04: `flutter test
/// test/engine/fvp_engine_contract_test.dart` must exit 0 against the
/// frozen contracts on the old FvpEngine (sc4). Phase 21 will mount the
/// identical `run*ContractTests` functions against `NewFvpEngine` by
/// changing only the factory below (VERIFY-01 reuse seam).
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
// This mock replaces ONLY the texture-registration RPC with a fake
// monotonically-increasing texture id. It does not touch FvpEngine,
// MediaOpener, TrackManager, or the real mdk decode pipeline in any way —
// prepare()/mediaInfo/state-machine logic all still run against the real
// native mdk/ffmpeg libraries loaded via the DLLs on the process's search
// path. This preserves D13 (contract tests gate the REAL FvpEngine, never
// a fake engine) while working around a headless-test-environment
// limitation that has no bearing on the ISP contracts under test.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  runEngineStateViewContractTests(() => FvpEngine());
  runPlaybackControlContractTests(() => FvpEngine());
  runTrackControlContractTests(() => FvpEngine());
  runSubtitleConfigContractTests(() => FvpEngine());
  runVideoEffectControlContractTests(() => FvpEngine());
  runRendererControlContractTests(() => FvpEngine());
  runVolumeControlContractTests(() => FvpEngine());
}
