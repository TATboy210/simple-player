# v2 Coding Conventions

**Analysis Date:** 2026-06-19

## Naming

| Pattern | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `MpvAdapter`, `PlayerFeature` |
| Functions/Variables | camelCase | `fire()`, `_handleCommand` |
| Private members | _prefix | `_controller`, `_initialized` |
| Constants | camelCase (const) | `titleBarHeight`, `bgGlass` |
| Enums | PascalCase type, camelCase values | `PlaybackState.playing` |
| Sealed classes | PascalCase | `PlayerCommand`, `WindowEvent` |

## Code Style

### Sealed Class Pattern
```dart
sealed class PlayerEvent {
  const PlayerEvent();
}
final class StateChanged extends PlayerEvent { ... }
final class PositionChanged extends PlayerEvent { ... }
```

### Command Handler Pattern
```dart
Future<void> _handleCommand(PlayerCommand cmd) async {
  switch (cmd) {
    case OpenCommand(:final path): await _mpv.load(path);
    case PlayCommand(): await _mpv.play();
    // exhaustive — compiler enforces completeness
  }
}
```

### EventBus Usage
```dart
// Fire
_bus.fire(const StateChanged(PlaybackState.playing));
// Subscribe
_bus.on<StateChanged>().listen((e) => setState(() => _state = e.state));
```

## Design Tokens

All visual values via `Tokens.*`:
```dart
abstract final class Tokens {
  static const double titleBarHeight = 32;
  static const Color bgGlass = Color(0x80000000);
  // ...
}
```

## Error Handling

- Feature handlers: `try { ... } catch (e) { _bus.fire(ErrorOccurred('$e')); }`
- FFI operations: `try { ... } finally { calloc.free(ptr); }`
- Event polling: `try { ... } catch (e) { }` (silent — protects polling loop)
- Logging: `AppLogger.error('Context', 'Message')`

## FFI Memory Management

```dart
// ALWAYS: calloc in try/finally
final ptr = name.toNativeUtf8();
try { _bindings.mpv_set_property_string(_handle, ptr, ...); }
finally { calloc.free(ptr); }
```

## Widget Patterns

### StreamSubscription (lifecycle-safe)
```dart
late final List<StreamSubscription> _subs;
initState() { _subs = [bus.on<StateChanged>().listen(...)]; }
dispose() { for (final s in _subs) s.cancel(); super.dispose(); }
```

### StreamBuilder (reactive)
```dart
StreamBuilder<WindowEvent>(
  stream: bus.on<WindowEvent>(),
  builder: (ctx, snap) { ... },
)
```

## Logging

- Debug: `debugPrint()` only
- Release: `AppLogger.info/warn/error('Tag', 'Message')`
- Never use `print()`

---

*Conventions analysis: 2026-06-19*
