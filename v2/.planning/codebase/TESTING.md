# v2 Testing

**Analysis Date:** 2026-06-19

## Framework

- `flutter_test` (SDK)
- No mocking library configured

## Test Files (4 files, 174 lines)

| File | Lines | Coverage |
|------|-------|----------|
| `test/core/player_events_test.dart` | 48 | PlayerEvent sealed class, StateChanged, PositionChanged, TrackInfo |
| `test/feature/player_command_test.dart` | 48 | PlayerCommand const constructibility, exhaustive switch |
| `test/infra/event_bus_test.dart` | 48 | EventBus fire/on delivery, type filtering |
| `test/widget_test.dart` | 30 | Placeholder (references non-existent MyApp) |

## Coverage Matrix

| Module | Unit Tests | Widget Tests | Status |
|--------|-----------|-------------|--------|
| Core types | ✅ | — | Covered |
| EventBus | ✅ | — | Covered |
| MpvAdapter | ❌ | — | **HIGH RISK** |
| MpvBindings | ❌ | — | **HIGH RISK** |
| WindowService | ❌ | — | Needs integration runner |
| PlayerFeature | ❌ (data only) | — | Command dispatch untested |
| WindowFeature | ❌ | — | Fully untested |
| PlayerScreen | ❌ | ❌ | Fully untested |
| TitleBar | ❌ | ❌ | Fully untested |
| AppLogger | ❌ | — | Fully untested |
| C++ render plugin | ❌ | — | Needs native test harness |

## Testing Patterns

### AAA Pattern (Arrange-Act-Assert)
```dart
test('fires StateChanged on play', () {
  // Arrange
  final bus = EventBus();
  // Act
  bus.fire(const StateChanged(PlaybackState.playing));
  // Assert
  expect(bus.on<StateChanged>(), emits(isA<StateChanged>()));
});
```

## Gaps (Priority Order)

1. **MpvAdapter** — FFI memory safety, event polling, property observation
2. **PlayerFeature** — command dispatch, error handling
3. **WindowService** — fullscreen toggle, resize debounce, animation guard
4. **Widget tests** — PlayerScreen event subscription, TitleBar StreamBuilder
5. **Integration tests** — end-to-end flow from UI command to mpv state

## Recommendations

- Add `mockito` or hand-written fakes for MpvBindings
- Fix stale `widget_test.dart` (references MyApp, not App)
- Target 80% coverage on Feature + Infrastructure layers

---

*Testing analysis: 2026-06-19 — Understand-Anything*
