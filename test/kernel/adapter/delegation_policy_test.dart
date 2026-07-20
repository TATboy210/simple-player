/// DelegationPolicy construction behavior unit tests (Phase 21 plan 08).
///
/// Verifies all() constructor, per-field constructor, migratedMethods behavior,
/// field immutability, and const constructibility.
///
/// Pure Dart tests — no mdk.dll or FakeEngine dependency needed.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/adapter/kernel_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════════════
  // all() constructor
  // ═══════════════════════════════════════════════════════════════════════════

  group('DelegationPolicy.all() constructor', () {
    test('all(legacy) sets all 7 capability fields to legacy', () {
      const policy = DelegationPolicy.all(KernelMode.legacy);

      expect(policy.stateView, KernelMode.legacy);
      expect(policy.playback, KernelMode.legacy);
      expect(policy.track, KernelMode.legacy);
      expect(policy.subtitle, KernelMode.legacy);
      expect(policy.videoEffect, KernelMode.legacy);
      expect(policy.renderer, KernelMode.legacy);
      expect(policy.volume, KernelMode.legacy);
    });

    test('all(migrated) sets all 7 capability fields to migrated', () {
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

    test('all() is const constructible (compile-time)', () {
      // Verify const construction works — this is a compile-time check
      // that also validates at runtime.
      const policy1 = DelegationPolicy.all(KernelMode.legacy);
      const policy2 = DelegationPolicy.all(KernelMode.legacy);

      // Const instances with same args are identical
      expect(identical(policy1, policy2), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Per-field constructor
  // ═══════════════════════════════════════════════════════════════════════════

  group('DelegationPolicy per-field constructor', () {
    test('explicit fields override individually', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.migrated,
        playback: KernelMode.legacy,
        track: KernelMode.migrated,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.migrated,
        renderer: KernelMode.legacy,
        volume: KernelMode.migrated,
      );

      expect(policy.stateView, KernelMode.migrated);
      expect(policy.playback, KernelMode.legacy);
      expect(policy.track, KernelMode.migrated);
      expect(policy.subtitle, KernelMode.legacy);
      expect(policy.videoEffect, KernelMode.migrated);
      expect(policy.renderer, KernelMode.legacy);
      expect(policy.volume, KernelMode.migrated);
    });

    test('migratedMethods defaults to empty set when not provided', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
      );

      expect(policy.migratedMethods, isEmpty);
    });

    test('migratedMethods accepts custom set', () {
      const methods = {'open', 'play', 'seekTo'};
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
        migratedMethods: methods,
      );

      expect(policy.migratedMethods, {'open', 'play', 'seekTo'});
      expect(policy.migratedMethods.length, 3);
    });

    test('all 7 fields are final (immutable)', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
      );

      // Verify field values haven't changed after construction
      // (Immutability is enforced at compile-time by `final` — this is a runtime sanity check)
      expect(policy.stateView, KernelMode.legacy);
      expect(policy.playback, KernelMode.legacy);
      expect(policy.track, KernelMode.legacy);
      expect(policy.subtitle, KernelMode.legacy);
      expect(policy.videoEffect, KernelMode.legacy);
      expect(policy.renderer, KernelMode.legacy);
      expect(policy.volume, KernelMode.legacy);
    });

    test('const per-field constructor works', () {
      // Verify const construction for per-field variant
      const policy = DelegationPolicy(
        stateView: KernelMode.migrated,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
      );

      expect(policy.stateView, KernelMode.migrated);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // migratedMethods behavior
  // ═══════════════════════════════════════════════════════════════════════════

  group('DelegationPolicy.migratedMethods behavior', () {
    test('contains() returns true for methods in set', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
        migratedMethods: {'open', 'play'},
      );

      expect(policy.migratedMethods.contains('open'), isTrue);
      expect(policy.migratedMethods.contains('play'), isTrue);
    });

    test('contains() returns false for methods not in set', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
        migratedMethods: {'open'},
      );

      expect(policy.migratedMethods.contains('pause'), isFalse);
      expect(policy.migratedMethods.contains('stop'), isFalse);
      expect(policy.migratedMethods.contains('seekTo'), isFalse);
    });

    test('empty set means no methods use migrated routing', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
      );

      // No method should be in the set
      expect(policy.migratedMethods.contains('open'), isFalse);
      expect(policy.migratedMethods.contains('play'), isFalse);
      expect(policy.migratedMethods.contains('setVolume'), isFalse);
      expect(policy.migratedMethods.contains('setMute'), isFalse);
    });

    test('migratedMethods is immutable (final Set)', () {
      const policy = DelegationPolicy(
        stateView: KernelMode.legacy,
        playback: KernelMode.legacy,
        track: KernelMode.legacy,
        subtitle: KernelMode.legacy,
        videoEffect: KernelMode.legacy,
        renderer: KernelMode.legacy,
        volume: KernelMode.legacy,
        migratedMethods: {'open'},
      );

      // The set should be the same reference on repeated access
      final first = policy.migratedMethods;
      final second = policy.migratedMethods;
      expect(identical(first, second), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // KernelMode enum
  // ═══════════════════════════════════════════════════════════════════════════

  group('KernelMode enum', () {
    test('has exactly two values: legacy and migrated', () {
      expect(KernelMode.values.length, 2);
      expect(KernelMode.values, contains(KernelMode.legacy));
      expect(KernelMode.values, contains(KernelMode.migrated));
    });
  });
}
