# Coding Conventions

**Analysis Date:** 2026-05-30

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart files (e.g., `playback_controller.dart`, `glass_container.dart`)
- Private files prefixed with `_` (e.g., `_settings_nav_item.dart`)
- Test files suffixed with `_test.dart` (e.g., `playlist_test.dart`)

**Classes:**
- `PascalCase` for classes, enums, typedefs (e.g., `PlaybackController`, `MediaState`, `GlassTier`)
- Private classes prefixed with `_` (e.g., `_QuickMenuItem`, `_RotatingFileOutput`, `_ShortcutsHelpDialog`)
- Abstract interfaces use `abstract class` (e.g., `abstract class MediaEngine`)
- Extensions use `PascalCase` descriptive names

**Functions/Methods:**
- `camelCase` for all functions and methods (e.g., `openAndPlay`, `togglePlayPause`)
- Private methods prefixed with `_` (e.g., `_init`, `_buildVideoContent`, `_seek`)
- Boolean getters use `is`/`has`/`can` prefixes (e.g., `isEmpty`, `hasNext`, `isUrl`, `isAllowedMedia`)
- Named constructors use `camelCase` (e.g., `GlassButton.iconOnly`)

**Variables:**
- `camelCase` for local variables and parameters (e.g., `rebuildCount`, `onNeedRebuild`)
- Private fields prefixed with `_` (e.g., `_openGeneration`, `_onError`, `_disposed`)
- Constants use `camelCase` (Dart convention, NOT `SCREAMING_SNAKE_CASE`)
  ```dart
  // Tokens class constants
  static const bgBase = Color(0xFF0A0A0F);
  static const fontTitle = 18.0;
  static const durationFast = 80;

  // Class-level constants
  static const _prepareTimeoutSeconds = 10;
  static const _defaultSkipSeconds = 10;
  ```

**Enums:**
- `PascalCase` for enum type name (e.g., `MediaState`, `PlayMode`, `GlassTier`)
- `camelCase` for enum values (e.g., `idle`, `loopAll`, `pathEmpty`)
- Enum values documented with `///` comments:
  ```dart
  enum MediaState {
    /// 初始状态，未加载任何媒体
    idle,
    /// 正在播放
    playing,
  }
  ```

## Code Style

**Formatting:**
- `dart format` for all `.dart` files
- Line length: 80 characters (dart format default)
- Trailing commas on multi-line argument/parameter lists to improve diffs

**Linting:**
- Config: `analysis_options.yaml` extends `package:flutter_lints/flutter.yaml`
- Additional rules:
  ```yaml
  linter:
    rules:
      prefer_const_constructors: true
      prefer_const_literals_to_create_immutables: true
  ```

**Const usage:**
- Use `const` constructors wherever possible
- Use `const` for compile-time constant values
- `final` for local variables that are assigned once

## Design Token System

**All visual values use `Tokens.*` constants from `lib/ui/theme/tokens.dart`:**

```dart
// Colors — Background
Tokens.bgBase        // 0xFF0A0A0F — Base background
Tokens.bgPanel       // 0xFF1A1A24 — Panel background
Tokens.bgElevated    // 0xFF242432 — Elevated surfaces
Tokens.bgHover       // 0xFF2A2A3A — Hover state
Tokens.bgGlass       // 0x801A1A24 — Glass background (50% alpha)

// Colors — Accent
Tokens.accent        // 0xFF2C58F4 — Primary accent
Tokens.accentLight   // 0xB42C57F4 — Light accent (70% alpha)
Tokens.danger        // 0xFFFA3737 — Error/danger

// Colors — Text
Tokens.textPrimary   // 0xFFE8E8F0 — Primary text
Tokens.textSecondary // 0xFF9999AA — Secondary text
Tokens.textTertiary  // 0xFF666677 — Tertiary text
Tokens.textDisabled  // 0xFF444455 — Disabled text

// Colors — Border
Tokens.borderHighlight // 0x33FFFFFF — Glass border (20% white)

// Typography
Tokens.fontFamily    // 'Noto Sans SC'
Tokens.fontTitle     // 18.0
Tokens.fontBody      // 14.0
Tokens.fontCaption   // 12.0
Tokens.fontOverline  // 10.0
Tokens.weightMedium  // FontWeight.w500
Tokens.weightSemiBold // FontWeight.w600

// Spacing
Tokens.spXs          // 4.0
Tokens.spSm          // 8.0
Tokens.spMd          // 12.0
Tokens.spLg          // 16.0
Tokens.spXl          // 24.0

// Border Radius
Tokens.radiusSm      // 6.0
Tokens.radiusMd      // 10.0
Tokens.radiusLarge   // 12.0
Tokens.radiusBtn     // 4.0
Tokens.radiusPopup   // 8.0

// Glass Blur
Tokens.glassBlurThin  // 8.0 — Title bar
Tokens.glassBlur      // 10.0 — Control bar
Tokens.glassBlurThick // 24.0 — Dialogs

// Animation Durations (milliseconds)
Tokens.durationFast    // 80
Tokens.durationNormal  // 150
Tokens.durationFade    // 300
Tokens.durationSlide   // 300
Tokens.durationDebounce // 500

// Component Sizes
Tokens.titleBarHeight      // 32.0
Tokens.controlBarHeight    // 84.0
Tokens.progressBarHeight   // 32.0
Tokens.compactBreakpoint   // 500.0
Tokens.playlistPanelWidth  // 420.0

// Icon Sizes
Tokens.iconSm    // 16.0
Tokens.iconMd    // 18.0
Tokens.iconLg    // 20.0
Tokens.iconXl    // 28.0
```

**Rule:** NEVER hardcode color, spacing, radius, or duration values. Always use `Tokens.*`.

## Import Organization

**Order:**
1. `dart:` imports (e.g., `dart:async`, `dart:io`, `dart:ui`)
2. External `package:` imports (e.g., `package:flutter/material.dart`, `package:fvp/mdk.dart`)
3. Internal `package:` imports (e.g., `package:simple_player_flutter/kernel/...`)
4. Relative imports within same feature/layer (e.g., `../theme/tokens.dart`, `./playback_navigator.dart`)

**Path Style:**
- Use relative imports within the same package/feature (e.g., `import '../theme/tokens.dart'`)
- Use `package:` imports in tests for cross-layer references (e.g., `import 'package:simple_player_flutter/kernel/...'`)
- Use relative imports in tests for test helpers (e.g., `import '../../helpers/fake_engine.dart'`)

**Example from source:**
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../kernel/engine/media_engine.dart';
import '../../kernel/models/media_state.dart';
import '../theme/tokens.dart';
```

**Example from tests:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/features/player/services/playback_controller.dart';
import 'package:simple_player_flutter/kernel/playlist/playlist.dart';
import '../../helpers/fake_engine.dart';
```

## Error Handling

**Pattern: try-catch with specific exception types:**
```dart
try {
  await someOperation();
} on Exception catch (e) {
  log.e('[ClassName] operation failed: $e');
  onError?.call(e);
}
```

**Pattern: Guard clauses with early return:**
```dart
Future<void> playIndex(int index) async {
  if (index < 0 || index >= playlist.length) return;
  // ... rest of logic
}
```

**Pattern: Disposed check (for classes with dispose):**
```dart
void play() {
  if (_disposed) return;
  state.value = MediaState.playing;
}
```

**Pattern: Null-safe error propagation:**
```dart
_rt.onError?.call(Exception(validationError));
```

**Pattern: Graceful fallback with error state:**
```dart
try {
  await Future.wait([LocaleService.I.init(), ThemeService.I.init()]);
} on Exception catch (e) {
  log.w('[App] settings load failed (continuing): $e');
}
```

**Pattern: Async guard with generation counter:**
```dart
int _openGeneration = 0;

Future<void> playIndex(int index) async {
  final gen = ++_openGeneration;
  await engine.open(path);
  if (gen != _openGeneration) return;  // Stale request discarded
  // ...
}
```

**NEVER use:**
- `catch (e)` without type specification — always `on Exception catch (e)`
- `print()` — use `debugPrint()` or `log.d()`/`log.w()`/`log.e()`
- Silent catch blocks (`catch (_) {}`)

## Logging

**Framework:** `logger` package (v2.5.0) with custom `Logger` instance in `lib/kernel/utils/log.dart`

**Global instance:**
```dart
import '../utils/log.dart';

Logger log = Logger(
  printer: PrettyPrinter(methodCount: 0, printEmojis: false, ...),
);
```

**Usage levels:**
```dart
log.d('Debug message');     // Debug level
log.w('Warning message');   // Warning level
log.e('Error message');     // Error level
```

**Prefix convention:** Use `[ClassName]` prefix for context:
```dart
log.w('[App] settings load failed (continuing): $e');
log.e('[PlayerFeature] init failed: $e');
log.d('[PlayerFeature] init completed in ${sw.elapsedMilliseconds}ms');
log.w('playIndex: rejected unsafe path: $validationError');
```

**Initialization:**
- Debug mode: Console output only (no-op)
- Release mode: File output to `%APPDATA%\SimplePlayer\logs\` with 2 MB rotation, 5 archive limit

## Comment Style

**Language:** Chinese comments are acceptable and common throughout the codebase

**Doc comments:** Use `///` for public API documentation:
```dart
/// 播放控制器 — 播放器全部运行时能力的统一入口
///
/// 组合 PlaybackNavigator / FileOperations / StateMonitor 三个子模块，
/// UI 层只与本类交互。
class PlaybackController {
```

**Section separators:** Use `// ─── Section Name ───` for logical grouping:
```dart
// ─── ValueNotifier fields ───
// ─── Call tracking ───
// ─── Playback control ───
// ─── Lifecycle ───
// ─── Test helper methods ───
```

**Inline comments:** Explain WHY, not WHAT:
```dart
// fire-and-forget: 预热 MDK 引擎（FFmpeg codec 注册 + D3D11 上下文）
unawaited(EnginePrewarm.prewarm(...));

// 延迟卸载，等待淡出动画完成
Future.delayed(const Duration(milliseconds: Tokens.durationSlide), () { ... });
```

**Design decision comments:** Reference decision IDs:
```dart
/// opacity < 0.01 时跳过 BackdropFilter GPU readback（D-13）
/// blurEnabled 为 false 时跳过 BackdropFilter，仅渲染 Container（D-14）
```

## Widget Composition Patterns

**Pattern: ValueListenableBuilder for reactive UI:**
```dart
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, child) => state == MediaState.idle
      ? child!
      : const SizedBox.shrink(),
  child: Positioned.fill(child: emptyState!),  // Cached child
)
```

**Pattern: Nested ValueListenableBuilders for multiple notifiers:**
```dart
ValueListenableBuilder<bool>(
  valueListenable: windowService.isFullscreen,
  builder: (context, isFullscreen, child) =>
      ValueListenableBuilder<bool>(
        valueListenable: windowService.isMaximized,
        builder: (context, isMaximized, child) {
          final noResize = isFullscreen || isMaximized;
          return DragToResizeArea(resizeEdgeSize: noResize ? 0 : 6, ...);
        },
        child: child,
      ),
  child: child,
)
```

**Pattern: StatefulWidget with private State:**
```dart
class PlayerScreen extends StatefulWidget {
  final MediaEngine engine;
  const PlayerScreen({super.key, required this.engine, ...});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  Widget build(BuildContext context) { ... }
}
```

**Pattern: Callback drilling with optional callbacks:**
```dart
class ControlsOverlay extends StatefulWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final void Function(BuildContext context, TapUpDetails details)? onSettingsSecondary;
}
```

**Pattern: GlassContainer for glassmorphism:**
```dart
GlassContainer(
  tier: GlassTier.normal,
  padding: const EdgeInsets.symmetric(horizontal: Tokens.spLg, vertical: Tokens.spMd),
  child: Text('Hello', style: TextStyle(color: Tokens.textPrimary)),
)
```

**Pattern: GlassButton dual mode:**
```dart
// Icon-only mode (lightweight, no BackdropFilter)
GlassButton.iconOnly(
  icon: Icons.play_arrow,
  tooltip: 'Play',
  onPressed: () => engine.play(),
)

// Label mode (with GlassContainer + blur)
GlassButton(
  icon: Icons.open_in_new,
  label: 'Open',
  onPressed: () => openFile(),
)
```

## Service Architecture

**Composition pattern (PlaybackController):**
```dart
class PlaybackController {
  PlaybackController({required this.engine, required this.playlist, ...}) {
    navigator = PlaybackNavigator(this);
    fileOps = FileOperations(this);
    monitor = StateMonitor(this);
  }

  final MediaEngine engine;
  final Playlist playlist;
  late final PlaybackNavigator navigator;
  late final FileOperations fileOps;
  late final StateMonitor monitor;

  // Forward methods to sub-modules
  Future<void> playIndex(int i) => navigator.playIndex(i);
  Future<void> playNext() => navigator.playNext();
  Future<bool> openAndPlay(String p) => fileOps.openAndPlay(p);
}
```

**Singleton pattern with `I` getter:**
```dart
class LocaleService {
  static final LocaleService I = LocaleService._();
  LocaleService._();
  // ...
}

// Usage
await LocaleService.I.init();
```

**Sub-module pattern (navigator, fileOps, monitor):**
```dart
class PlaybackNavigator {
  PlaybackNavigator(this._rt);
  final PlaybackController _rt;  // Back-reference to parent

  Future<void> playIndex(int index) async {
    // Access _rt.engine, _rt.playlist, _rt.onNeedRebuild()
  }
}
```

## Async Patterns

**Fire-and-forget with `unawaited()`:**
```dart
import 'dart:async';
unawaited(EnginePrewarm.prewarm(...));
```

**Backgrounded async with yield:**
```dart
await controller.openAndPlay('C:/test.mp4');
await Future(() {});  // yield for backgrounded async
```

**Future.wait for parallel init:**
```dart
await Future.wait([LocaleService.I.init(), ThemeService.I.init()]);
```

## Module Design

**Exports:** Each file exports one primary class/concept
- `media_engine.dart` exports `MediaEngine` abstract class
- `playback_controller.dart` exports `PlaybackController`
- `glass_container.dart` exports `GlassContainer`, `GlassTier`, `GlassButton`

**No barrel files:** Each import references the specific file

**Feature organization:**
```
lib/features/player/
├── player_feature.dart        # StatefulWidget (UI composition)
├── player_services.dart       # Service wiring (creates engine, controller, etc.)
├── deferred_player_feature.dart # Lazy-loaded feature wrapper
└── services/                  # Business logic services
    ├── playback_controller.dart
    ├── playback_navigator.dart
    ├── file_operations.dart
    ├── state_monitor.dart
    └── subtitle_service.dart
```

## ValueNotifier Pattern (State Management)

**No Provider/Riverpod/Bloc — use ValueNotifier + ValueListenableBuilder:**

```dart
// Engine exposes state as ValueNotifiers
abstract class MediaEngine {
  ValueNotifier<MediaState> get state;
  ValueNotifier<int> get position;
  ValueNotifier<double> get volume;
  ValueNotifier<bool> get isMuted;
  // ... 10+ ValueNotifiers
}

// Widgets listen via ValueListenableBuilder
ValueListenableBuilder<MediaState>(
  valueListenable: engine.state,
  builder: (context, state, _) => Text(state.name),
)
```

**Optimization: Use `child` parameter for static subtrees:**
```dart
ValueListenableBuilder<bool>(
  valueListenable: _playlistVisible,
  builder: (context, visible, videoContent) => Stack(
    children: [videoContent!, if (visible) PlaylistPanel(...)],
  ),
  child: videoContent,  // Cached — doesn't rebuild
)
```

**MergedListenable for multi-notifier rebuilds:**
```dart
// lib/ui/shared/merged_listenable.dart
// Combines multiple ValueNotifiers into one for single ValueListenableBuilder
```

## Commit Format

Conventional Commits: `<type>: <description>`

Types: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `perf:`, `chore:`, `wip:`

Examples:
```
feat: add subtitle delay controls
fix: prevent stale open() from overwriting current playback
refactor: extract PlaybackNavigator from PlaybackController
test: add playlist serialization round-trip tests
docs: update architecture diagram
perf: skip BackdropFilter when opacity < 0.01
```

---

*Convention analysis: 2026-05-30*
