# Phase 10: Window Optimization - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 8 (3 new, 5 modified)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kernel/bridge/window_bootstrap.dart` (NEW) | utility | request-response | `lib/kernel/bridge/window_service.dart` | exact |
| `lib/main.dart` (MODIFY) | config | request-response | self (startup flow) | exact |
| `lib/app.dart` (MODIFY) | component | request-response | self (DI wiring) | exact |
| `lib/features/player/player_services.dart` (MODIFY) | service | CRUD | self (constructor injection) | exact |
| `lib/features/player/player_feature.dart` (MODIFY) | component | request-response | self (pass-through) | exact |
| `lib/kernel/bridge/window_service.dart` (MODIFY) | service | event-driven | self (onWindowClose) | exact |
| `test/kernel/bridge/window_bootstrap_test.dart` (NEW) | test | request-response | `test/kernel/persistence/settings_store_test.dart` | exact |
| `test/helpers/fake_screen_retriever.dart` (NEW) | test helper | request-response | `test/helpers/fake_window_service.dart` | exact |

## Pattern Assignments

### `lib/kernel/bridge/window_bootstrap.dart` (NEW — utility, request-response)

**Analog:** `lib/kernel/bridge/window_service.dart`

**Imports pattern** (lines 1-10):
```dart
import 'package:flutter/widgets.dart' show Size, Offset;
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../persistence/settings_store.dart';
import '../utils/log.dart';
```

**Static utility pattern** — WindowService uses static `removeBorderImmediate()` (line 55-85). WindowBootstrap should follow the same static-only pattern since it has no instance state:
```dart
/// Startup window geometry restoration with multi-monitor safety.
///
/// Static utility — reads saved geometry from [SettingsStore],
/// validates against current monitor topology, and applies
/// position/size before windowManager.show().
class WindowBootstrap {
  WindowBootstrap._(); // no instantiation
  // ... static methods
}
```

**Error handling pattern** (lines 120-138 in window_service `_scheduleGeometrySave`):
```dart
try {
  // ... operation
} on Exception catch (e) {
  debugPrint('WindowBootstrap: $operation failed: $e');
  // graceful fallback — continue with defaults
}
```

**Async pattern** — all window_manager calls are async Future<void>:
```dart
static Future<void> restoreOrCenter(AppSettings settings) async {
  if (settings.windowX != null && settings.windowY != null &&
      _isOnVisibleDisplay(settings)) {
    await windowManager.setPosition(
      Offset(settings.windowX!, settings.windowY!),
    );
    await windowManager.setSize(
      Size(settings.windowWidth, settings.windowHeight),
    );
  } else {
    await windowManager.setSize(
      Size(settings.windowWidth, settings.windowHeight),
    );
    await windowManager.center();
  }
  await windowManager.ensureVisible();
}
```

**Multi-monitor check** — uses screen_retriever (already a transitive dependency):
```dart
static Future<bool> _isOnVisibleDisplay(AppSettings settings) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    final windowRect = Rect.fromLTWH(
      settings.windowX!, settings.windowY!,
      settings.windowWidth, settings.windowHeight,
    );
    for (final display in displays) {
      final displayRect = Rect.fromLTWH(
        display.visiblePosition!.dx,
        display.visiblePosition!.dy,
        display.visibleSize!.width,
        display.visibleSize!.height,
      );
      if (windowRect.overlaps(displayRect)) {
        final overlap = windowRect.intersect(displayRect);
        if (overlap.width >= 100 && overlap.height >= 100) return true;
      }
    }
    return false;
  } on Exception catch (e) {
    debugPrint('WindowBootstrap: display check failed: $e');
    return true; // fail-open — let ensureVisible() handle it
  }
}
```

**Fullscreen clear on startup** — per D-02, clear isFullscreen to avoid crash-lock:
```dart
static Future<void> clearFullscreenIfSaved(AppSettings settings) async {
  if (settings.isFullscreen) {
    await SettingsStore.saveIsFullscreen(false);
  }
}
```

---

### `lib/main.dart` (MODIFY — config, request-response)

**Current state** (lines 17-31): Hardcoded `WindowOptions(size: Size(960, 540), center: true)` ignores saved geometry.

**Modification pattern** — insert geometry restore inside `waitUntilReadyToShow` callback, after `removeBorderImmediate()` but before `show()`:

```dart
// BEFORE (lines 17-31):
windowManager.waitUntilReadyToShow(windowOptions, () async {
  await WindowService.removeBorderImmediate();
  await windowManager.show();
  await windowManager.focus();
});

// AFTER:
windowManager.waitUntilReadyToShow(windowOptions, () async {
  await WindowService.removeBorderImmediate();

  // Restore saved geometry (Phase 10)
  final settings = await SettingsStore.load();
  await WindowBootstrap.restoreOrCenter(settings);

  await windowManager.show();
  await windowManager.focus();

  // Post-show: restore maximized state
  if (settings.isMaximized) {
    // maximize after show + ensureVisible (done inside restoreOrCenter)
  }
});
```

**New imports to add:**
```dart
import 'kernel/bridge/window_bootstrap.dart';
```

**Note:** `SettingsStore.load()` is already called later (line 45 `SettingsStore.prewarm`). The early `load()` inside the callback is needed BEFORE `show()`. The later `prewarm()` call caches the prefs instance for subsequent reads — no conflict.

---

### `lib/app.dart` (MODIFY — component, DI wiring)

**Current state** (line 33): `final WindowService _windowService = WindowService()..init();` — creates first instance.

**Bug:** PlayerServices (line 34 in player_services.dart) creates a second `WindowService()..init()`.

**Fix pattern** — inject the singleton WindowService through the widget tree:

```dart
// BEFORE (line 33):
final WindowService _windowService = WindowService()..init();

// AFTER — no change to _windowService creation, but pass it down:
// DeferredPlayerFeature needs a new windowService parameter
child: DeferredPlayerFeature(
  coordinator: widget.coordinator,
  windowService: _windowService,  // NEW: inject singleton
  onSettings: ...,
  onSettingsSecondary: ...,
),
```

**ValueListenableBuilder pattern** (lines 160-176) — already wraps `_windowService.isFullscreen` and `_windowService.isMaximized`. No change needed here since the same instance is used.

---

### `lib/features/player/player_services.dart` (MODIFY — service, constructor injection)

**Current state** (lines 34-35): Creates its own WindowService:
```dart
windowService = WindowService();
windowService.init();
```

**Fix pattern** — accept WindowService via constructor, remove internal creation:

```dart
// BEFORE:
class PlayerServices {
  late final WindowService windowService;
  // ...
  Future<void> init() async {
    // ...
    windowService = WindowService();
    windowService.init();
  }
}

// AFTER:
class PlayerServices {
  final WindowService windowService;
  PlayerServices({required this.windowService});
  // ...
  Future<void> init() async {
    // ... remove windowService creation lines
  }
}
```

**Import pattern** (line 3): Already imports `window_service.dart` — no change.

---

### `lib/features/player/player_feature.dart` (MODIFY — component, pass-through)

**Current state** (line 57): `_services = PlayerServices();`

**Fix pattern** — accept WindowService and pass to PlayerServices:

```dart
// Constructor needs new parameter:
class PlayerFeature extends StatefulWidget {
  final WindowService windowService;  // NEW
  // ... existing params
}

// initState:
_services = PlayerServices(windowService: widget.windowService);
```

**DeferredPlayerFeature** also needs the pass-through:
```dart
// DeferredPlayerFeature constructor:
final WindowService windowService;  // NEW

// build() passes it through:
return player_feature.PlayerFeature(
  windowService: widget.windowService,  // NEW
  // ... existing params
);
```

---

### `lib/kernel/bridge/window_service.dart` (MODIFY — service, event-driven)

**Current state:** `onWindowClose` not overridden — geometry save only via 500ms debounce in `_scheduleGeometrySave()`.

**Add onWindowClose override** (after line 118, following WindowListener pattern):
```dart
@override
void onWindowClose() {
  // Save geometry immediately — debounce timer may not have fired
  _saveGeometryImmediate();
}

Future<void> _saveGeometryImmediate() async {
  if (_disposed) return;
  try {
    final pos = await windowManager.getPosition();
    final size = windowSize.value;
    await SettingsStore.saveWindowGeometry(
      width: size.width,
      height: size.height,
      x: pos.dx,
      y: pos.dy,
      isMaximized: isMaximized.value,
    );
  } on Exception catch (e) {
    debugPrint('WindowService: immediate geometry save failed: $e');
  }
}
```

**Pattern source:** Same as `_scheduleGeometrySave()` (lines 121-138) but without Timer debounce and without the fullscreen/maximized skip guard.

---

### `test/kernel/bridge/window_bootstrap_test.dart` (NEW — test)

**Analog:** `test/kernel/persistence/settings_store_test.dart`

**Test structure pattern** (lines 1-8 of settings_store_test):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WindowBootstrap', () {
    // ... test groups
  });
}
```

**SharedPreferences mock pattern** (line 151-153):
```dart
setUp(() {
  SharedPreferences.setMockInitialValues({});
});
```

**Test naming pattern** — behavior-focused (from settings_store_test):
```dart
test('restoreOrCenter sets position when saved geometry exists', () async { ... });
test('restoreOrCenter centers window when no saved position', () async { ... });
test('restoreOrCenter falls back to center when position off-screen', () async { ... });
test('clearFullscreenIfSaved clears isFullscreen flag', () async { ... });
```

**Key test scenarios:**
1. Saved position on visible display → setPosition + setSize called
2. Saved position off-screen (no display match) → center() called
3. No saved position (windowX/windowY null) → center() called
4. isFullscreen true → clears flag via SettingsStore
5. screen_retriever throws → fail-open, center() called

---

### `test/helpers/fake_screen_retriever.dart` (NEW — test helper)

**Analog:** `test/helpers/fake_window_service.dart`

**Fake pattern with call tracking** (lines 7-73 of fake_window_service):
```dart
/// Test double for ScreenRetriever — no platform plugins.
///
/// Provides configurable display list and call tracking.
class FakeScreenRetriever {
  // ─── Configurable behavior ───
  List<Display> displays = [];
  bool shouldThrow = false;

  // ─── Call tracking ───
  int getAllDisplaysCallCount = 0;

  Future<List<Display>> getAllDisplays() async {
    getAllDisplaysCallCount++;
    if (shouldThrow) throw Exception('mock error');
    return displays;
  }
}
```

**Note:** screen_retriever's `ScreenRetriever` class is a singleton accessed via `screenRetriever`. The test will need to either:
- Make `WindowBootstrap` accept an abstract display provider (preferred for testability)
- Or use a static override/teardown pattern

**Recommended approach:** Add a `@visibleForTesting` static setter in WindowBootstrap:
```dart
static Future<List<Display>> Function()? _displayProviderOverride;

@visibleForTesting
static void setDisplayProvider(Future<List<Display>> Function() provider) {
  _displayProviderOverride = provider;
}

@visibleForTesting
static void resetDisplayProvider() {
  _displayProviderOverride = null;
}

static Future<List<Display>> _getDisplays() =>
    _displayProviderOverride?.call() ?? screenRetriever.getAllDisplays();
```

---

## Shared Patterns

### Error Handling
**Source:** `lib/kernel/bridge/window_service.dart` lines 120-138
**Apply to:** WindowBootstrap, WindowService onWindowClose
```dart
try {
  // ... async operation
} on Exception catch (e) {
  debugPrint('ComponentName: operation failed: $e');
  // graceful fallback — never crash
}
```

### ValueNotifier State
**Source:** `lib/kernel/bridge/window_service.dart` lines 32-36
**Apply to:** All new state in WindowService
```dart
final ValueNotifier<bool> isFullscreen = ValueNotifier(false);
// Expose for ValueListenableBuilder in UI
```

### FFI try/finally
**Source:** `lib/kernel/bridge/window_service.dart` lines 177-188, 193-203, 206-224
**Apply to:** Any new FFI allocations in WindowService
```dart
final ptr = calloc<StructType>();
try {
  // ... use ptr
} finally {
  calloc.free(ptr);
}
```

### Test Fakes with Call Tracking
**Source:** `test/helpers/fake_window_service.dart` lines 7-73
**Apply to:** `test/helpers/fake_screen_retriever.dart`
```dart
class FakeSomething {
  int someMethodCallCount = 0;
  bool shouldThrow = false;

  Future<T> someMethod() async {
    someMethodCallCount++;
    if (shouldThrow) throw Exception('mock');
    return configuredValue;
  }
}
```

### Dependency Injection (Constructor)
**Source:** `lib/features/player/player_services.dart` pattern (to be modified)
**Apply to:** PlayerServices, PlayerFeature, DeferredPlayerFeature
```dart
class PlayerServices {
  final WindowService windowService;
  PlayerServices({required this.windowService});
}
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|---|---|---|---|
| (none) | — | — | All files have strong analogs |

## Metadata

**Analog search scope:** `lib/kernel/bridge/`, `lib/features/player/`, `lib/main.dart`, `lib/app.dart`, `test/helpers/`, `test/kernel/persistence/`
**Files scanned:** 12
**Pattern extraction date:** 2026-05-30
