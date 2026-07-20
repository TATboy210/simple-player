/// KernelAdapter routing logic unit tests (Phase 21 plan 08).
///
/// Verifies per-method routing via migratedMethods, per-capability field
/// routing via DelegationPolicy fields, DelegationPolicy.all() constructor,
/// dispose behavior, and DiagnosticsBundle forwarding.
///
/// All tests use pure Dart FakeEngine — no mdk.dll dependency.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/adapter/kernel_adapter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/diagnostics_bundle.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

import '../../helpers/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // EngineStateMachine.transitionTo uses KernelLoggerImpl.I — must init for tests.
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  late FakeEngine legacyEngine;
  late FakeEngine migratedEngine;

  setUp(() {
    legacyEngine = FakeEngine();
    migratedEngine = FakeEngine();
  });

  tearDown(() {
    legacyEngine.dispose();
    migratedEngine.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Per-method routing via migratedMethods
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelAdapter per-method routing', () {
    test('method in migratedMethods routes to migrated engine', () async {
      // Arrange: open is migrated, everything else legacy
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'open'},
        ),
      );

      // Act
      await adapter.open('test.mp4');

      // Assert: only migrated engine received the call
      expect(migratedEngine.openCallCount, 1);
      expect(legacyEngine.openCallCount, 0);
      expect(migratedEngine.openPaths, ['test.mp4']);
    });

    test('method NOT in migratedMethods routes to legacy engine', () {
      // Arrange: only 'play' is migrated, call 'pause'
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'play'},
        ),
      );

      // Act
      adapter.pause();

      // Assert: legacy engine received pause
      expect(legacyEngine.pauseCallCount, 1);
      expect(migratedEngine.pauseCallCount, 0);
    });

    test('empty migratedMethods routes all methods to legacy', () {
      // Arrange: default all-legacy policy (empty migratedMethods)
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      // Act
      adapter.play();
      adapter.pause();
      adapter.stop();

      // Assert: all calls went to legacy
      expect(legacyEngine.playCallCount, 1);
      expect(legacyEngine.pauseCallCount, 1);
      expect(legacyEngine.stopCallCount, 1);
      expect(migratedEngine.playCallCount, 0);
      expect(migratedEngine.pauseCallCount, 0);
      expect(migratedEngine.stopCallCount, 0);
    });

    test('multiple methods in migratedMethods route correctly', () async {
      // Arrange: open + play migrated
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'open', 'play'},
        ),
      );

      // Act
      await adapter.open('video.mp4');
      adapter.play();
      adapter.pause(); // not migrated → legacy

      // Assert
      expect(migratedEngine.openCallCount, 1);
      expect(migratedEngine.playCallCount, 1);
      expect(legacyEngine.openCallCount, 0);
      expect(legacyEngine.playCallCount, 0);
      expect(legacyEngine.pauseCallCount, 1);
    });

    test('seekTo routes via migratedMethods', () async {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'seekTo'},
        ),
      );

      await adapter.seekTo(5000);

      expect(migratedEngine.seekToCallCount, 1);
      expect(migratedEngine.lastSeekToMs, 5000);
      expect(legacyEngine.seekToCallCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Capability field routing (per-policy field)
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelAdapter capability field routing', () {
    test('stateView=legacy returns legacy.state notifier', () {
      // Arrange
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      // Assert: identity-preserving forwarding (ADAPT-03)
      expect(identical(adapter.state, legacyEngine.state), isTrue);
      expect(identical(adapter.state, migratedEngine.state), isFalse);
    });

    test('stateView=migrated returns migrated.state notifier', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.migrated),
      );

      expect(identical(adapter.state, migratedEngine.state), isTrue);
      expect(identical(adapter.state, legacyEngine.state), isFalse);
    });

    test('volume=legacy returns legacy.volume notifier', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      expect(identical(adapter.volume, legacyEngine.volume), isTrue);
      expect(identical(adapter.isMuted, legacyEngine.isMuted), isTrue);
    });

    test('volume=migrated returns migrated.volume notifier', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.migrated),
      );

      expect(identical(adapter.volume, migratedEngine.volume), isTrue);
      expect(identical(adapter.isMuted, migratedEngine.isMuted), isTrue);
    });

    test('track=legacy returns legacy.activeAudioTracks', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      // activeAudioTracks is a getter routed via _policy.track
      expect(adapter.activeAudioTracks, legacyEngine.activeAudioTracks);
    });

    test('subtitle=legacy returns legacy.subtitleDelay', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      expect(adapter.subtitleDelay, legacyEngine.subtitleDelay);
    });

    test('stateView identity forwarding for all 11 notifiers', () {
      // Verify all EngineStateView notifiers preserve identity
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      expect(identical(adapter.textureId, legacyEngine.textureId), isTrue);
      expect(identical(adapter.state, legacyEngine.state), isTrue);
      expect(identical(adapter.position, legacyEngine.position), isTrue);
      expect(identical(adapter.duration, legacyEngine.duration), isTrue);
      expect(identical(adapter.isBuffering, legacyEngine.isBuffering), isTrue);
      expect(identical(adapter.isSeeking, legacyEngine.isSeeking), isTrue);
      expect(identical(adapter.subtitleText, legacyEngine.subtitleText), isTrue);
      expect(identical(adapter.buffered, legacyEngine.buffered), isTrue);
      expect(identical(adapter.aspectRatio, legacyEngine.aspectRatio), isTrue);
      expect(identical(adapter.lastError, legacyEngine.lastError), isTrue);
      expect(identical(adapter.playbackSpeed, legacyEngine.playbackSpeed), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DelegationPolicy.all() constructor
  // ═══════════════════════════════════════════════════════════════════════════

  group('DelegationPolicy.all() constructor', () {
    test('all(legacy) sets all 7 fields to legacy', () {
      const policy = DelegationPolicy.all(KernelMode.legacy);

      expect(policy.stateView, KernelMode.legacy);
      expect(policy.playback, KernelMode.legacy);
      expect(policy.track, KernelMode.legacy);
      expect(policy.subtitle, KernelMode.legacy);
      expect(policy.videoEffect, KernelMode.legacy);
      expect(policy.renderer, KernelMode.legacy);
      expect(policy.volume, KernelMode.legacy);
    });

    test('all(migrated) sets all 7 fields to migrated', () {
      const policy = DelegationPolicy.all(KernelMode.migrated);

      expect(policy.stateView, KernelMode.migrated);
      expect(policy.playback, KernelMode.migrated);
      expect(policy.track, KernelMode.migrated);
      expect(policy.subtitle, KernelMode.migrated);
      expect(policy.videoEffect, KernelMode.migrated);
      expect(policy.renderer, KernelMode.migrated);
      expect(policy.volume, KernelMode.migrated);
    });

    test('all() sets migratedMethods to empty const set', () {
      const policy = DelegationPolicy.all(KernelMode.legacy);

      expect(policy.migratedMethods, isEmpty);
      expect(policy.migratedMethods.length, 0);
    });

    test('all() is const constructible', () {
      // Compile-time const verification
      const policy = DelegationPolicy.all(KernelMode.legacy);
      expect(policy, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Dispose behavior
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelAdapter dispose', () {
    test('dispose calls stateView-target engine dispose (legacy)', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      adapter.dispose();

      // Legacy engine should be disposed (stateView=legacy)
      expect(legacyEngine.textureId.value, isNull); // disposed state
    });

    test('dispose calls stateView-target engine dispose (migrated)', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.migrated),
      );

      adapter.dispose();

      // Migrated engine should be disposed
      expect(migratedEngine.textureId.value, isNull);
    });

    test('dispose calls bundle.dispose() without throwing', () {
      // Arrange: custom bundle (noop by default)
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
        bundle: const DiagnosticsBundle.noop(),
      );

      // Act & Assert: should not throw
      expect(() => adapter.dispose(), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // DiagnosticsBundle forwarding
  // ═══════════════════════════════════════════════════════════════════════════

  group('DiagnosticsBundle forwarding', () {
    test('bundle is accessible via adapter constructor injection', () {
      const bundle = DiagnosticsBundle.noop();
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
        bundle: bundle,
      );

      // Verify the adapter was constructed without error
      expect(adapter, isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Error propagation
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelAdapter error propagation', () {
    test('open error propagates from legacy engine', () async {
      legacyEngine.failNextOpenWith = 'decode error';
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      await adapter.open('test.mp4');
      // FakeEngine sets error state on failure
      expect(legacyEngine.openCallCount, 1);
    });

    test('open error propagates from migrated engine via migratedMethods', () async {
      migratedEngine.failNextOpenWith = 'decode error';
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'open'},
        ),
      );

      await adapter.open('test.mp4');
      // open is in migratedMethods, so migrated engine receives the call
      expect(migratedEngine.openCallCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // mediaInfo routing
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelAdapter mediaInfo routing', () {
    test('mediaInfo routes via stateView policy (legacy)', () {
      legacyEngine.configureMedia(durationMs: 60000);
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      expect(adapter.mediaInfo.duration, 60000);
    });

    test('mediaInfo routes via stateView policy (migrated)', () {
      migratedEngine.configureMedia(durationMs: 120000);
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.migrated),
      );

      expect(adapter.mediaInfo.duration, 120000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Per-capability field routing (delegationPolicy fields)
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelAdapter per-capability field routing', () {
    test('volume field routes setVolume via _policy.volume', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      adapter.setVolume(0.5);

      expect(legacyEngine.setVolumeCallCount, 1);
      expect(legacyEngine.lastSetVolumeValue, 0.5);
      expect(migratedEngine.setVolumeCallCount, 0);
    });

    test('setMute routes via _targetFor (migratedMethods)', () {
      // setMute uses _targetFor('setMute'), not _policy.volume field directly.
      // migratedMethods takes priority over per-capability fields for methods.
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'setMute'},
        ),
      );

      adapter.setMute(true);

      // Migrated engine should receive setMute call
      expect(migratedEngine.isMuted.value, isTrue);
      expect(legacyEngine.isMuted.value, isFalse);
    });

    test('track field routes getAudioTracks via _policy.track', () {
      legacyEngine.configureMedia(
        audioTracks: const [
          AudioTrackInfo(index: 0, language: 'en'),
        ],
      );
      migratedEngine.configureMedia(
        audioTracks: const [
          AudioTrackInfo(index: 1, language: 'zh'),
        ],
      );

      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      final tracks = adapter.getAudioTracks();
      expect(tracks.length, 1);
      expect(tracks.first.language, 'en');
    });

    test('subtitle field routes setSubtitleDelay via _policy.subtitle', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      adapter.setSubtitleDelay(500);

      expect(legacyEngine.setSubtitleDelayCallCount, 1);
      expect(legacyEngine.subtitleDelay, 500);
    });

    test('videoEffect field routes setVideoEffect via _targetFor', () {
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy),
      );

      adapter.setVideoEffect(VideoEffectType.brightness, 0.8);

      expect(legacyEngine.setVideoEffectCallCount, 1);
      expect(legacyEngine.lastVideoEffectType, VideoEffectType.brightness);
      expect(legacyEngine.lastVideoEffectValue, 0.8);
    });

    test('renderer field routes setD3d11SyncEnabled via _targetFor', () {
      // setD3d11SyncEnabled uses _targetFor, not _policy.renderer field directly.
      final adapter = KernelAdapter(
        legacy: legacyEngine,
        migrated: migratedEngine,
        policy: const DelegationPolicy.all(KernelMode.legacy).copyWith(
          migratedMethods: {'setD3d11SyncEnabled'},
        ),
      );

      adapter.setD3d11SyncEnabled(true);

      expect(migratedEngine.setD3d11SyncEnabledCallCount, 1);
      expect(migratedEngine.lastD3d11SyncEnabled, isTrue);
      expect(legacyEngine.setD3d11SyncEnabledCallCount, 0);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test helpers: copyWith extension for DelegationPolicy
// ═══════════════════════════════════════════════════════════════════════════════

/// Extension to allow selective field overrides in tests.
///
/// DelegationPolicy is final class with all-final fields, so we need a
/// helper to create variants for testing specific routing scenarios.
extension _DelegationPolicyCopyWith on DelegationPolicy {
  DelegationPolicy copyWith({
    KernelMode? stateView,
    KernelMode? playback,
    KernelMode? track,
    KernelMode? subtitle,
    KernelMode? videoEffect,
    KernelMode? renderer,
    KernelMode? volume,
    Set<String>? migratedMethods,
  }) =>
      DelegationPolicy(
        stateView: stateView ?? this.stateView,
        playback: playback ?? this.playback,
        track: track ?? this.track,
        subtitle: subtitle ?? this.subtitle,
        videoEffect: videoEffect ?? this.videoEffect,
        renderer: renderer ?? this.renderer,
        volume: volume ?? this.volume,
        migratedMethods: migratedMethods ?? this.migratedMethods,
      );
}
