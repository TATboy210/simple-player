/// Notifier identity test (D24 layer 3 / D25 / ADAPT-03) — asserts
/// `KernelAdapter` forwards the wrapped legacy engine's OWN ValueNotifier
/// instances, never a fresh notifier wrapping `x.value`.
///
/// This is THE test that catches Blocking Constraint #6 violations: a
/// rewrapped `ValueNotifier(x.value)` getter would pass value-equality
/// (`equals()`) but fail reference-identity (`same()`) — and silently
/// detach every `ValueListenableBuilder` listener subscribed to the
/// original notifier, freezing the UI on a future cutover. `same()` ships
/// in `package:matcher`, transitively available via `flutter_test`.
///
/// All 13 `EngineStateView` ValueNotifier fields (from
/// lib/kernel/engine/engine_state_view.dart) are asserted — `mediaInfo`
/// (plain getter, not a ValueNotifier) and `dispose()` (method) are
/// excluded, they need no same() check.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/adapter/kernel_adapter.dart';
import 'package:simple_player_flutter/kernel/engine/fvp_engine.dart';

void main() {
  test('KernelAdapter forwards EngineStateView notifiers by identity', () {
    // Arrange — a legacy FvpEngine wrapped by an all-legacy KernelAdapter.
    // Identity checks never call open(), so no texture-channel mock is
    // needed here (constructing FvpEngine alone does not touch the native
    // texture-registration channel).
    final legacy = FvpEngine();
    final adapter = KernelAdapter(
      legacy: legacy,
      migrated: legacy,
      policy: const DelegationPolicy.all(KernelMode.legacy),
    );

    // Act + Assert — every one of the 13 EngineStateView ValueNotifier
    // getters must return the SAME instance as the wrapped legacy engine's
    // notifier (reference identity, not value equality).
    expect(adapter.textureId, same(legacy.textureId));
    expect(adapter.state, same(legacy.state));
    expect(adapter.position, same(legacy.position));
    expect(adapter.duration, same(legacy.duration));
    expect(adapter.volume, same(legacy.volume));
    expect(adapter.isMuted, same(legacy.isMuted));
    expect(adapter.isBuffering, same(legacy.isBuffering));
    expect(adapter.isSeeking, same(legacy.isSeeking));
    expect(adapter.subtitleText, same(legacy.subtitleText));
    expect(adapter.buffered, same(legacy.buffered));
    expect(adapter.aspectRatio, same(legacy.aspectRatio));
    expect(adapter.lastError, same(legacy.lastError));
    expect(adapter.playbackSpeed, same(legacy.playbackSpeed));

    legacy.dispose();
  });
}
