# Phase 1: Window Chrome - Research

**Researched:** 2026-05-07
**Domain:** Flutter desktop window management, glass-morphism UI, ValueNotifier reactive state
**Confidence:** HIGH

## Summary

Phase 1 implements a custom title bar with glass-morphism (BackdropFilter blur), four window controls (pin, minimize, maximize, close), drag-to-move, and double-tap maximize. The implementation follows the reference project at `D:\player_flutter` which provides a proven 189-line `CustomTitleBar` widget.

**Key finding:** The current codebase already has 90% of the infrastructure. `PlatformService` abstract interface and `WindowsPlatformService` implementation are complete with all required methods (`minimize()`, `toggleMaximize()`, `close()`, `startDragging()`, `toggleAlwaysOnTop()`) and ValueNotifiers (`isAlwaysOnTop`, `isMaximized`, `isResizing`). `WindowManagerService` already handles all FFI calls with try-catch, debounce, and disposal safety. The only missing piece is the title bar widget itself and 9 design tokens.

**Primary recommendation:** Port `custom_title_bar.dart` from the reference project with minimal modifications. Add 9 tokens to `tokens.dart`. Wire into `app.dart` above existing content.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Title bar rendering | UI Layer (`lib/kernel/ui/window/`) | -- | Flutter widget, purely visual |
| Window controls (minimize/maximize/close/pin) | Platform Layer (`PlatformService`) | Window Layer (`WindowManagerService`) | Abstract interface delegates to Windows FFI |
| Drag-to-move | Platform Layer (`PlatformService`) | -- | `startDragging()` is platform FFI |
| Glass-morphism (BackdropFilter) | UI Layer | -- | Flutter rendering primitive |
| Resize degradation (isResizing) | Window Layer (`WindowManagerService`) | UI Layer (consumer) | `isResizing` ValueNotifier owned by WindowManagerService |
| Design tokens | UI Theme Layer (`Tokens`) | -- | Compile-time constants |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material | SDK (3.44+) | Material widgets, Tooltip, MouseRegion | Built-in, no extra dependency |
| window_manager | 0.5.1 | Frameless window, drag, fullscreen, always-on-top | Already in pubspec, production-hardened |
| dart:ui | SDK | BackdropFilter, ImageFilter.blur | Built-in, GPU-accelerated |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_localizations | SDK | l10n for tooltips (pin, unpin, minimize, etc.) | Already wired in app.dart |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| BackdropFilter | Custom shader | Overkill for title bar blur, BackdropFilter is standard |
| window_manager drag | Native Win32 drag | window_manager handles cross-platform, already used |

## Architecture Patterns

### System Architecture Diagram

```
User Interaction (title bar)
       |
       v
+-------------------+
| CustomTitleBar    |  (StatelessWidget)
| GestureDetector   |  -- onPanStart -> startDragging()
|                   |  -- onDoubleTap -> toggleMaximize()
| ValueListenableBuilder(isResizing) |
|   [resizing=true] --> plain bgGlass container
|   [resizing=false] --> ClipRect -> BackdropFilter(blur) -> container
+-------------------+
       |
       +-- Row: [icon] [fileName] [Spacer] [TitleBarControls]
       |                                    |
       |                                    +-- Row: [pin] [min] [max] [close]
       |                                        Each: _TitleBarButton (StatefulWidget with hover)
       |
       v
+-------------------+
| PlatformService.I |  (abstract interface)
| isAlwaysOnTop     |  ValueNotifier<bool>
| isMaximized       |  ValueNotifier<bool>
| isResizing        |  ValueNotifier<bool>
| minimize()        |  -> WindowManagerService
| toggleMaximize()  |  -> WindowManagerService
| close()           |  -> WindowManagerService
| startDragging()   |  -> WindowManagerService
| toggleAlwaysOnTop()| -> WindowManagerService
+-------------------+
       |
       v
+-------------------+
| WindowManagerSvc  |  (singleton, FFI)
| window_manager pkg |  All calls wrapped in try-catch
+-------------------+
```

### Recommended File Structure

```
lib/kernel/ui/window/
  custom_title_bar.dart    # CustomTitleBar + TitleBarControls + _TitleBarButton
```

### Pattern 1: Glass-Morphism Widget Tree

**What:** Layered widget tree that conditionally applies BackdropFilter based on resize state
**When to use:** Any glass surface that must degrade during resize drag
**Example:**
```dart
// Source: D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart:66-86
GestureDetector(
  behavior: HitTestBehavior.translucent,
  onPanStart: (_) => wm.startDragging(),
  onDoubleTap: () => wm.toggleMaximize(),
  child: ValueListenableBuilder<bool>(
    valueListenable: wm.isResizing,
    builder: (_, resizing, child) => resizing
        ? child!  // plain bgGlass, no blur
        : ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: Tokens.glassBlurThin,
                sigmaY: Tokens.glassBlurThin,
              ),
              child: child,
            ),
          ),
    child: content,  // Container with Row inside
  ),
)
```

### Pattern 2: TitleBarControls with State Reflection

**What:** Row of buttons that reflect window state via ValueListenableBuilder
**When to use:** Window control buttons that show active/inactive state
**Example:**
```dart
// Source: D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart:100-134
ValueListenableBuilder<bool>(
  valueListenable: wm.isAlwaysOnTop,
  builder: (_, pinned, _) => _TitleBarButton(
    icon: Icons.push_pin,
    isActive: pinned,  // accent color when true
    tooltip: pinned ? l10n.unpin : l10n.pin,
    onPressed: wm.toggleAlwaysOnTop,
  ),
),
ValueListenableBuilder<bool>(
  valueListenable: wm.isMaximized,
  builder: (_, maximized, _) => _TitleBarButton(
    icon: maximized ? Icons.filter_none : Icons.crop_square,
    tooltip: maximized ? l10n.restore : l10n.maximize,
    onPressed: wm.toggleMaximize,
  ),
),
```

### Pattern 3: _TitleBarButton with Hover Detection

**What:** StatefulWidget button that tracks hover state locally, rebuilds only itself
**When to use:** Any button with hover highlight without external state
**Example:**
```dart
// Source: D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart:138-188
class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hovered
        ? (widget.isClose ? Tokens.danger : Tokens.bgHover)
        : Colors.transparent;
    final iconColor = _hovered
        ? Tokens.textPrimary
        : (widget.isActive ? Tokens.accent : Tokens.textSecondary);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: Tokens.titleBarButtonWidth,
            height: Tokens.titleBarHeight,
            color: bgColor,
            child: Icon(widget.icon, size: Tokens.iconSm, color: iconColor),
          ),
        ),
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **Creating ValueNotifiers in the title bar widget:** Notifiers are owned by PlatformService/WindowManagerService. Title bar only listens.
- **Using setState for window state:** Window state (pinned, maximized) flows through ValueNotifier, not local setState.
- **Hardcoding colors/sizes:** All values must come from `Tokens.*` constants.
- **Catching bare `catch (e)`:** Always `on Exception catch (e)` per codebase convention.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Window drag | Custom Win32 drag code | `windowManager.startDragging()` | Platform-handled, cross-platform |
| Window minimize/maximize/close | Direct Win32 API | `windowManager.minimize()` etc. | Abstracted, already wrapped in try-catch |
| Always-on-top | Manual HWND_TOPMOST | `windowManager.setAlwaysOnTop()` | Handled by window_manager package |
| BackdropFilter blur | Custom shader | `BackdropFilter` + `ImageFilter.blur()` | GPU-accelerated, standard Flutter |

## Runtime State Inventory

Not applicable. Phase 1 is greenfield widget creation, not rename/refactor.

## Common Pitfalls

### Pitfall 1: BackdropFilter Performance During Resize
**What goes wrong:** BackdropFilter causes GPU jank during window resize drag
**Why it happens:** Blur filter recomputes every frame during resize
**How to avoid:** Listen to `PlatformService.I.isResizing` ValueNotifier, skip BackdropFilter when true
**Warning signs:** Visible frame drops during window resize

### Pitfall 2: GestureDetector Conflicts with Button Taps
**What goes wrong:** Title bar drag gesture consumes taps on control buttons
**Why it happens:** Outer GestureDetector intercepts all pointer events
**How to avoid:** Use `HitTestBehavior.translucent` on outer GestureDetector; inner buttons have their own GestureDetector that takes priority in z-order
**Warning signs:** Buttons don't respond to clicks

### Pitfall 3: Missing L10n Keys
**What goes wrong:** Tooltip text shows raw key instead of localized string
**Why it happens:** L10n keys not added to ARB files
**How to avoid:** All required keys already exist: `pin`, `unpin`, `minimize`, `maximize`, `restore`, `close` (verified in both `app_en.arb` and `app_zh.arb`)
**Warning signs:** Raw key names in tooltips

### Pitfall 4: Icon Size Mismatch
**What goes wrong:** App icon uses wrong size token
**Why it happens:** Reference uses `iconMd` (18px in reference, 20px in current)
**How to avoid:** Use `Tokens.iconMd` (20px) for app icon, `Tokens.iconSm` (16px) for button icons per UI-SPEC
**Warning signs:** Visually oversized/undersized icons

## Code Examples

### CustomTitleBar Constructor Pattern
```dart
// Source: D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart:13-17
class CustomTitleBar extends StatelessWidget {
  final VoidCallback? onOpenFile;
  final ValueNotifier<String>? fileName;

  const CustomTitleBar({super.key, this.onOpenFile, this.fileName});
```

### File Name Display Logic
```dart
// Source: D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart:35-49
if (fileName != null)
  ValueListenableBuilder<String>(
    valueListenable: fileName!,
    builder: (_, name, _) => Expanded(
      child: Text(
        name.isEmpty ? 'Simple Player' : '$name — Simple Player',
        style: const TextStyle(
          color: Tokens.textSecondary,
          fontSize: Tokens.fontCaption,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  )
else
  const Text(
    'Simple Player',
    style: TextStyle(
      color: Tokens.textSecondary,
      fontSize: Tokens.fontCaption,
      fontWeight: FontWeight.w500,
    ),
  ),
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| System title bar | Custom frameless + CustomTitleBar | Current codebase | Full control over appearance |
| Provider/Bloc | ValueNotifier + ValueListenableBuilder | Codebase standard | No external state deps |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build | -- | 3.44+ (beta) | -- |
| window_manager | FFI calls | -- | 0.5.1 | -- |
| flutter_test | Widget tests | -- | SDK | -- |

No external dependencies beyond what's already in pubspec.yaml.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml (dev_dependencies) |
| Quick run command | `flutter test test/widget/window/custom_title_bar_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WC-01 | Pin toggles always-on-top | widget | `flutter test test/widget/window/custom_title_bar_test.dart` | No - Wave 0 |
| WC-05 | Controls reflect state changes | widget | same file | No - Wave 0 |
| PQ-03 | Unit tests for controls state | widget | same file | No - Wave 0 |
| PQ-05 | Dispose safety | code review | N/A (no new notifiers) | N/A |
| PQ-06 | FFI error handling | code review | existing WindowManagerService | Yes |
| PQ-07 | No hardcoded values | `flutter analyze` | `flutter analyze` | Yes |

### Wave 0 Gaps
- [ ] `test/widget/window/custom_title_bar_test.dart` -- covers WC-01, WC-05, PQ-03
- [ ] `test/helpers/fake_platform_service.dart` -- extract FakePlatformService from existing test for reuse

### Sampling Rate
- **Per task commit:** `flutter test test/widget/window/custom_title_bar_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** `flutter analyze` + `flutter test` both green

## Security Domain

Not applicable. Phase 1 is purely UI with no user input handling, no network calls, no data persistence beyond existing window state. All FFI calls are wrapped in try-catch (PQ-06, already implemented in WindowManagerService).

## Project Constraints (from CLAUDE.md)

- Use `debugPrint()` not `print()` for logging
- Use `DesignTokens.*` for all visual values (in this codebase: `Tokens.*`)
- Errors: catch with `debugPrint` + graceful fallback (never silent `catch (_) {}`)
- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Chinese comments are OK (existing codebase convention)
- ValueNotifier + ValueListenableBuilder only (no Provider/Riverpod/Bloc)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WB-01 | Custom title bar with glass-morphism, 36px height | Pattern 1: Glass-morphism widget tree; Token: `titleBarHeight: 36.0` |
| WB-02 | Title bar shows app icon, file name, window controls | Pattern 2: TitleBarControls; File name display logic documented |
| WB-03 | Drag-to-move via title bar | `GestureDetector.onPanStart -> PlatformService.I.startDragging()` |
| WB-04 | Double-tap toggles maximize | `GestureDetector.onDoubleTap -> PlatformService.I.toggleMaximize()` |
| WC-01 | Pin button toggles always-on-top | `_TitleBarButton(icon: push_pin, onPressed: wm.toggleAlwaysOnTop)` |
| WC-02 | Minimize button | `_TitleBarButton(icon: minimize, onPressed: wm.minimize)` |
| WC-03 | Maximize button toggles | `_TitleBarButton(icon: crop_square/filter_none, onPressed: wm.toggleMaximize)` |
| WC-04 | Close button | `_TitleBarButton(icon: close, isClose: true, onPressed: wm.close)` |
| WC-05 | Controls reflect state via ValueNotifier | Pattern 2: ValueListenableBuilder on isAlwaysOnTop/isMaximized |
| PQ-01 | flutter analyze zero warnings | Run `flutter analyze` after implementation |
| PQ-03 | Unit tests for controls state | Widget tests with FakePlatformService |
| PQ-05 | Dispose safety | No new ValueNotifiers in title bar; PlatformService owns disposal |
| PQ-06 | FFI error handling | Already implemented in WindowManagerService (all methods wrapped) |
| PQ-07 | No hardcoded values | All from `Tokens.*` constants; 9 new tokens needed |
</phase_requirements>

## Token Additions Required

Current `tokens.dart` has 40 tokens. Add these 9:

| Token | Value | Category | Purpose |
|-------|-------|----------|---------|
| `titleBarHeight` | `36.0` | Layout | Title bar height |
| `titleBarButtonWidth` | `46.0` | Layout | Window control button width |
| `glassBlurThin` | `12.0` | Glass | BackdropFilter sigma for title bar |
| `glassBlur` | `16.0` | Glass | BackdropFilter sigma for control bar (Phase 2+) |
| `glassBlurThick` | `24.0` | Glass | BackdropFilter sigma for dialogs (Phase 2+) |
| `durationFast` | `80` | Animation | Press feedback duration (ms) |
| `durationNormal` | `150` | Animation | Hover state duration (ms) |
| `durationDebounce` | `500` | Animation | Resize debounce duration (ms, Phase 2) |
| `iconLg` | `20.0` | Icon | Large icon size |

**Note:** `iconMd` in current codebase is already 20.0 (matches reference's `iconLg`). The app icon in title bar should use `Tokens.iconMd` (20px) per existing codebase convention, not the reference's `iconLg`.

## Files to Create/Modify

### Create
| File | Purpose |
|------|---------|
| `lib/kernel/ui/window/custom_title_bar.dart` | CustomTitleBar + TitleBarControls + _TitleBarButton (3 widgets, ~190 lines) |
| `test/widget/window/custom_title_bar_test.dart` | Widget tests for state reflection and button behavior |
| `test/helpers/fake_platform_service.dart` | Extract FakePlatformService from existing test for reuse |

### Modify
| File | Change |
|------|--------|
| `lib/kernel/ui/theme/tokens.dart` | Add 9 new tokens |
| `lib/app.dart` | Add `CustomTitleBar` above existing `DragToResizeArea`, pass `controller.currentFileName` |

### No Changes Needed
| File | Why |
|------|-----|
| `lib/kernel/services/platform_service.dart` | Already has all required methods and ValueNotifiers |
| `lib/kernel/platform/windows_platform_service.dart` | Already delegates to WindowManagerService |
| `lib/kernel/window/window_manager_service.dart` | Already has isResizing, all FFI calls wrapped in try-catch |
| `lib/l10n/app_en.arb` | All tooltip keys already exist (pin, unpin, minimize, maximize, restore, close) |
| `lib/l10n/app_zh.arb` | All tooltip keys already exist |

## Testing Approach

### FakePlatformService Pattern
Already exists in `test/unit/platform_service_test.dart:6-42`. Extract to `test/helpers/fake_platform_service.dart` for reuse. Provides:
- Call counters: `minimizeCalls`, `toggleMaximizeCalls`, `closeCalls`, `startDraggingCalls`, `toggleAlwaysOnTopCalls`
- Controllable ValueNotifiers: `isAlwaysOnTop`, `isMaximized`, `isResizing`

### Widget Test Pattern
```dart
testWidgets('pin button reflects isAlwaysOnTop state', (tester) async {
  final fake = FakePlatformService();
  PlatformService.init(fake);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: CustomTitleBar(fileName: ValueNotifier(''))),
  ));

  // Verify pin button exists
  expect(find.byIcon(Icons.push_pin), findsOneWidget);

  // Toggle pinned state
  fake.isAlwaysOnTop.value = true;
  await tester.pump();

  // Pin icon should now have accent color (verified via widget inspection)
});

testWidgets('maximize button icon toggles', (tester) async {
  final fake = FakePlatformService();
  PlatformService.init(fake);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: CustomTitleBar(fileName: ValueNotifier(''))),
  ));

  // Default: crop_square icon
  expect(find.byIcon(Icons.crop_square), findsOneWidget);

  // Toggle maximized
  fake.isMaximized.value = true;
  await tester.pump();

  // Now: filter_none icon
  expect(find.byIcon(Icons.filter_none), findsOneWidget);
});
```

## Sources

### Primary (HIGH confidence)
- `D:\player_flutter\lib\kernel\ui\window\custom_title_bar.dart` -- Reference implementation, 189 lines
- `D:\player_flutter\lib\kernel\window\window_manager_service.dart` -- Reference WindowManagerService with isResizing, debounce
- `D:\simple_player_flutter\lib\kernel\services\platform_service.dart` -- Current abstract interface (verified all methods exist)
- `D:\simple_player_flutter\lib\kernel\window\window_manager_service.dart` -- Current implementation (verified FFI wrapping)
- `D:\simple_player_flutter\lib\kernel\ui\theme\tokens.dart` -- Current tokens (40 tokens, verified)
- `D:\simple_player_flutter\lib\l10n\app_en.arb` -- Verified all tooltip keys exist

### Secondary (MEDIUM confidence)
- `D:\simple_player_flutter\.planning\phases\01-window-chrome\01-UI-SPEC.md` -- Locked design contract

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all dependencies already in pubspec, patterns proven in reference
- Architecture: HIGH -- PlatformService interface already complete, WindowManagerService production-hardened
- Pitfalls: HIGH -- BackdropFilter performance pattern well-documented in reference

**Research date:** 2026-05-07
**Valid until:** 2026-06-07 (stable -- Flutter/window_manager APIs unlikely to change)
