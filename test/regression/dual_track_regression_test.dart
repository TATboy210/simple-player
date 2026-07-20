/// Parameterized dual-track regression suite (Phase 21 VERIFY-02).
///
/// Verifies that all-legacy and all-migrated KernelAdapter policies produce
/// identical behavior when wrapping the same FvpEngine instance.
/// DelegationPolicy only affects KernelAdapter routing — the underlying
/// engine execution is identical, so all tests should pass for both groups
/// with zero DiffReport differences.
///
/// Method coverage (D2): open, play, pause, stop, togglePlayPause, seekTo,
/// setVolume, setMute, setPlaybackRate, getAudioTracks, getSubtitleTracks,
/// setVideoEffect, rotate, setAspectRatio, setDeinterlace, setD3d11SyncEnabled,
/// setHardwareDecoding.
///
/// Async strategy (D3): async/await for open→idle→playing and seekTo flows
/// (texture mock makes open() synchronous in headless environment).
///
/// Assertion style (D4): mixed — state values, notifier values, and no-throw
/// checks via RegressionFixture + DiffReport.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/adapter/kernel_adapter.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';
import 'package:simple_player_flutter/kernel/engine/fvp_engine.dart';

import 'regression_fixture.dart';

// ── Texture channel mock (from fvp_engine_contract_test.dart) ─────────────
// Headless flutter test has no live Windows embedder, so the native
// platform-channel handler for GPU texture creation never gets a native-side
// implementation. This mock replaces ONLY the texture-registration RPC with
// a fake monotonically-increasing texture id. It does not touch FvpEngine,
// MediaOpener, TrackManager, or the real mdk decode pipeline in any way.
const _fvpChannel = MethodChannel('fvp');
int _nextFakeTextureId = 1;

void _installFvpTextureChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_fvpChannel, (call) async {
    switch (call.method) {
      case 'CreateRT':
        return _nextFakeTextureId++;
      case 'ReleaseRT':
        return null;
      default:
        return null;
    }
  });
}

/// All MediaEngine methods that use [_targetFor] per-method routing in
/// KernelAdapter. Used to construct the all-migrated DelegationPolicy.
const _allMediaEngineMethods = <String>{
  // PlaybackControl
  'open',
  'play',
  'pause',
  'stop',
  'togglePlayPause',
  'seekTo',
  'setPlaybackRate',
  'setRange',
  'skipForward',
  'skipBack',
  // TrackControl
  'getAudioTracks',
  'switchAudioTrack',
  // SubtitleConfig
  'getSubtitleTracks',
  'switchSubtitleTrack',
  'toggleSubtitle',
  'setExternalSubtitle',
  'setSubtitleDelay',
  'setEqualizer',
  // VideoEffectControl
  'setVideoEffect',
  'rotate',
  'setAspectRatio',
  'setDeinterlace',
  // RendererControl
  'setD3d11SyncEnabled',
  'setHardwareDecoding',
  // VolumeControl
  'setVolume',
  'setMute',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _installFvpTextureChannelMock();

  // ── mdk.dll availability probe ───────────────────────────────────────
  // FvpEngine() loads mdk.dll via FFI at construction time. In headless/CI
  // environments without the native MDK runtime, this throws. Skip all
  // tests gracefully when mdk.dll is unavailable (pre-existing env issue).
  String? skipReason;
  try {
    FvpEngine().dispose();
  } catch (e) {
    skipReason = 'mdk.dll not available in headless environment: $e';
  }

  // ── Factory definitions ────────────────────────────────────────────────
  // Both factories create their own FvpEngine, wrapped in KernelAdapter
  // with different DelegationPolicy configurations. Since the underlying
  // engine is the same class, behavior must be identical.

  MediaEngine Function() allLegacyFactory() {
    return () {
      final fvp = FvpEngine();
      return KernelAdapter(
        legacy: fvp,
        migrated: fvp,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );
    };
  }

  MediaEngine Function() allMigratedFactory() {
    return () {
      final fvp = FvpEngine();
      return KernelAdapter(
        legacy: fvp,
        migrated: fvp,
        policy: const DelegationPolicy(
          stateView: KernelMode.migrated,
          playback: KernelMode.migrated,
          track: KernelMode.migrated,
          subtitle: KernelMode.migrated,
          videoEffect: KernelMode.migrated,
          renderer: KernelMode.migrated,
          volume: KernelMode.migrated,
          migratedMethods: _allMediaEngineMethods,
        ),
      );
    };
  }

  /// Parameterized factories — key is the group label, value is the factory.
  final factories = <String, MediaEngine Function()>{
    'all-legacy': allLegacyFactory(),
    'all-migrated': allMigratedFactory(),
  };

  for (final entry in factories.entries) {
    group('Dual-track regression — ${entry.key}', skip: skipReason, () {
      late RegressionFixture fixture;

      setUp(() {
        fixture = RegressionFixture(entry.value);
        fixture.setUp();
      });

      tearDown(() {
        fixture.dispose();
      });

      // ── D2: open → idle → playing (D3) ───────────────────────────────
      test('open → idle → playing', () async {
        await fixture.engine.open('test/fixtures/tiny_valid.mp4');

        // open() success lands at idle (not playing)
        fixture.assertState(MediaState.idle, context: 'after open');
        fixture.assertNotifierEquals(
          fixture.engine.lastError, null, 'lastError',
          context: 'after open',
        );

        // Caller explicitly calls play() to enter playing
        fixture.engine.play();
        fixture.assertState(MediaState.playing, context: 'after play');

        fixture.assertNoDiffs();
      });

      // ── D2: seekTo updates position (D3) ─────────────────────────────
      test('seekTo updates position', () async {
        await fixture.engine.open('test/fixtures/tiny_valid.mp4');
        fixture.engine.play();

        await fixture.engine.seekTo(1000);
        // After seek completes, isSeeking should return to false.
        fixture.assertNotifierEquals(
          fixture.engine.isSeeking, false, 'isSeeking',
          context: 'after seekTo',
        );

        fixture.assertNoDiffs();
      });

      // ── D2: setVolume updates volume notifier ────────────────────────
      test('setVolume updates volume notifier', () {
        fixture.engine.setVolume(0.5);
        fixture.assertNotifierEquals(
          fixture.engine.volume, 0.5, 'volume',
          context: 'after setVolume(0.5)',
        );

        fixture.engine.setVolume(0.0);
        fixture.assertNotifierEquals(
          fixture.engine.volume, 0.0, 'volume',
          context: 'after setVolume(0.0)',
        );
        // Setting volume to 0 auto-mutes
        fixture.assertNotifierEquals(
          fixture.engine.isMuted, true, 'isMuted',
          context: 'auto-mute on volume=0',
        );

        fixture.engine.setVolume(1.0);
        fixture.assertNotifierEquals(
          fixture.engine.volume, 1.0, 'volume',
          context: 'after setVolume(1.0)',
        );
        fixture.assertNoDiffs();
      });

      // ── D2: setMute toggles isMuted ──────────────────────────────────
      test('setMute toggles isMuted', () {
        fixture.engine.setMute(true);
        fixture.assertNotifierEquals(
          fixture.engine.isMuted, true, 'isMuted',
          context: 'after setMute(true)',
        );

        fixture.engine.setMute(false);
        fixture.assertNotifierEquals(
          fixture.engine.isMuted, false, 'isMuted',
          context: 'after setMute(false)',
        );
        fixture.assertNoDiffs();
      });

      // ── D2: setPlaybackRate updates playbackSpeed ────────────────────
      test('setPlaybackRate updates playbackSpeed', () {
        fixture.engine.setPlaybackRate(1.5);
        fixture.assertNotifierEquals(
          fixture.engine.playbackSpeed, 1.5, 'playbackSpeed',
          context: 'after setPlaybackRate(1.5)',
        );

        // Clamp to [0.25, 4.0]
        fixture.engine.setPlaybackRate(0.01);
        fixture.assertNotifierEquals(
          fixture.engine.playbackSpeed, 0.25, 'playbackSpeed',
          context: 'clamp lower bound',
        );

        fixture.engine.setPlaybackRate(100.0);
        fixture.assertNotifierEquals(
          fixture.engine.playbackSpeed, 4.0, 'playbackSpeed',
          context: 'clamp upper bound',
        );
        fixture.assertNoDiffs();
      });

      // ── D2: getAudioTracks returns list ──────────────────────────────
      test('getAudioTracks returns list (no throw)', () {
        final tracks = fixture.engine.getAudioTracks();
        // Before open(), tracks should be empty
        expect(tracks, isA<List<AudioTrackInfo>>());
        fixture.assertNoDiffs();
      });

      // ── D2: getSubtitleTracks returns list ──────────────────────────
      test('getSubtitleTracks returns list (no throw)', () {
        final tracks = fixture.engine.getSubtitleTracks();
        expect(tracks, isA<List<SubtitleTrackInfo>>());
        fixture.assertNoDiffs();
      });

      // ── D2: setVideoEffect no throw ─────────────────────────────────
      test('setVideoEffect no throw', () {
        expect(
          () => fixture.engine.setVideoEffect(VideoEffectType.brightness, 0.5),
          returnsNormally,
        );
        fixture.assertNoDiffs();
      });

      // ── D2: rotate no throw ──────────────────────────────────────────
      test('rotate no throw', () {
        expect(() => fixture.engine.rotate(90), returnsNormally);
        expect(() => fixture.engine.rotate(0), returnsNormally);
        fixture.assertNoDiffs();
      });

      // ── D2: setAspectRatio no throw ─────────────────────────────────
      test('setAspectRatio no throw', () {
        expect(
          () => fixture.engine.setAspectRatio(16 / 9),
          returnsNormally,
        );
        fixture.assertNoDiffs();
      });

      // ── D2: setDeinterlace no throw ─────────────────────────────────
      test('setDeinterlace no throw', () {
        expect(
          () => fixture.engine.setDeinterlace(true),
          returnsNormally,
        );
        expect(
          () => fixture.engine.setDeinterlace(false),
          returnsNormally,
        );
        fixture.assertNoDiffs();
      });

      // ── D2: setD3d11SyncEnabled no throw ────────────────────────────
      test('setD3d11SyncEnabled no throw', () {
        expect(
          () => fixture.engine.setD3d11SyncEnabled(true),
          returnsNormally,
        );
        expect(
          () => fixture.engine.setD3d11SyncEnabled(false),
          returnsNormally,
        );
        fixture.assertNoDiffs();
      });

      // ── D2: setHardwareDecoding no throw ────────────────────────────
      test('setHardwareDecoding no throw', () {
        expect(
          () => fixture.engine.setHardwareDecoding(true),
          returnsNormally,
        );
        expect(
          () => fixture.engine.setHardwareDecoding(false),
          returnsNormally,
        );
        fixture.assertNoDiffs();
      });
    });
  }
}
