# Phase 32: Navigation & Interaction Polish - Research

**Researched:** 2026-07-28
**Domain:** Flutter desktop keyboard/focus routing, input-mode heuristics, and settings-panel interaction polish
**Confidence:** MEDIUM

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NAV-01 | Persistent clickable end-cap tab arrows plus Left/Right tab switching | Mount arrows in the existing `SettingsTabStrip` row and delegate to controller `prevTab`/`nextTab`. |
| NAV-02 | Singleton input-mode notifier with heuristic and toggle fallback, no Steamworks FFI | Use a root pointer observer plus focus-router key observation; do not infer source identity from an arrow event. |
| NAV-03 | Animated keyboard/gamepad hint substitution | Use `AnimatedSwitcher` with a distinct `ValueKey<InputMode>` child. |
| NAV-04 | Remove raw `gameButtonLeft1` / `gameButtonRight1` bindings | Remove the two logical-key branches and their two widget tests; the actual bindings are in `panel_key_bindings.dart`, not `keyboard_handler.dart`. |
| NAV-05 | Top/bottom thin-glass option-list arrows without another blur | Use translucent `Container(color: Tokens.bgGlass)`, located inside the existing panel blur. |
| NAV-06 | Up/down keyboard arrow glow feedback | Root router must update an arrow-feedback notifier and return `handled` for both vertical arrows. |
| NAV-07 | One root `Focus(onKeyEvent:)` captures all arrows | Keep the existing root `Focus` in `SettingsOverlayShell`; expand its handler so every recognized directional arrow is handled before `KeyboardHandler` can seek/adjust volume. |

## Project Constraints (from CLAUDE.md)

- Use `ValueNotifier` and `ValueListenableBuilder`; do not introduce Provider, Riverpod, or Bloc. [CITED: D:/simple_player_flutter/CLAUDE.md#L80-L85]
- Route every visual value through `Tokens.*`; the control-bar glass language is `BackdropFilter` + `bgGlass` + `borderHighlight`. [CITED: D:/simple_player_flutter/CLAUDE.md#L105-L110]
- Use `debugPrint`, explicit typed recoverable-error handling, and graceful fallback; do not silently catch errors. [CITED: D:/simple_player_flutter/CLAUDE.md#L112-L118]
- Avoid `!`, `late`, and `as`; use final locals, Dart patterns, and explicit `required` parameters. [CITED: D:/simple_player_flutter/CLAUDE.md#L197-L203]
- Keep non-trivial/public functions documented and explain non-obvious state/I/O logic while writing it. [CITED: D:/simple_player_flutter/CLAUDE.md#L180-L191]
- Write tests first, prefer fakes over mocks, and preserve rather than skip/remove failing assertions. [CITED: D:/simple_player_flutter/CLAUDE.md#L249-L254]

## Summary

The core blocker is resolved only at the API-contract level: Flutter can distinguish an event that the embedder reports as a gamepad key from an event reported as a keyboard arrow, but it cannot recover the *origin* of a Steam Input mapping after Steam/Windows has emitted a normal keyboard-arrow event. `KeyEvent` carries the platform-supplied `physicalKey`, `logicalKey`, and `deviceType`; Flutter documents that `physicalKey` is platform-mapped and that device type is not accurate on all platforms. On current Flutter source, non-Android raw events are classified as `keyboard`; therefore, a Steam mapping that injects keyboard Left/Right must be treated as indistinguishable from a real Left/Right in this application. The exact Steam runtime signature is not available in the repository and requires Windows hardware validation. [CITED: https://api.flutter.dev/flutter/services/KeyEvent/physicalKey.html] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L123-L218] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242]

This means Phase 32 must not branch navigation by `physicalKey`, `HardwareKeyboard`, or `deviceType` to label a mapped arrow as gamepad. Use the locked secondary heuristic: mouse activity selects keyboard; a recognized arrow after five seconds without mouse activity selects gamepad; a user toggle remains the correction path. The `Listener` must observe `onPointerHover` for ordinary desktop mouse motion, not only `onPointerMove`, because Flutter defines `onPointerMove` as movement after pointer-down and `onPointerHover` as movement while not down. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7263-L7280] [CITED: D:/flutter/packages/flutter/lib/src/gestures/events.dart#L1604-L1640]

The implementation can be contained in the existing settings overlay: its `FocusTraversalGroup > Focus(autofocus, onKeyEvent)` is already the right interception boundary, and its key handler currently returns `handled` for Left/Right. Phase 32 should expand that handler atomically with deletion of the obsolete cross-platform shoulder bindings. The outer `KeyboardHandler` owns global Left/Right seek and Up/Down volume shortcuts, so any recognized panel arrow that returns `ignored` can leak into player behavior. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L250-L297] [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart#L30-L70] [CITED: D:/simple_player_flutter/lib/ui/player/keyboard_handler.dart#L114-L132]

**Primary recommendation:** Implement a small `InputModeDetector` service plus a single settings-root event router; treat Steam-mapped arrows as source-indistinguishable, preserve mouse/idle heuristic and manual override, and land NAV-04 with NAV-07 in the same plan and commit.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Input-mode observation and user override | API / Backend (kernel service) | Browser / Client (Flutter shell listener) | The singleton owns state/heuristic policy; the overlay only forwards input signals. [CITED: D:/simple_player_flutter/CLAUDE.md#L80-L85] |
| Tab selection and end-cap navigation | Browser / Client | API / Backend | The widget renders/receives clicks; `SettingsPanelController` remains the sole selected-tab state owner. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/tab_strip.dart#L14-L35] [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_panel_controller.dart#L66-L74] |
| Arrow-key containment | Browser / Client | — | Focus dispatch bubbles from primary focus to ancestors until one returns `handled`; the settings root is the appropriate boundary. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239] |
| Hint fade and directional glow | Browser / Client | — | These are panel-local visual projections of notifier state. [CITED: https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html] |
| Glass/blur performance boundary | Browser / Client | — | The panel already owns its `GlassContainer` blur; overlay arrows are painted translucent rather than creating another readback pass. [CITED: D:/simple_player_flutter/lib/ui/shared/glass_container.dart#L144-L168] |

## Standard Stack

### Core

| Library / primitive | Version | Purpose | Why Standard |
|---------------------|---------|---------|--------------|
| Flutter `Focus`, `KeyEvent`, `KeyEventResult` | Flutter 3.44.8 installed [VERIFIED: local Flutter CLI] | Capture and consume settings-panel keys before outer shortcuts | Existing project root focus uses this API; Flutter dispatches from focused node to ancestors until handled. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L263-L268] [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239] |
| Flutter `Listener` / `PointerHoverEvent` | Flutter 3.44.8 installed [VERIFIED: local Flutter CLI] | Detect mouse activity at the settings-overlay boundary | Official listener semantics distinguish hover from drag movement. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280] |
| `ValueNotifier` / `ValueListenableBuilder` | Flutter SDK [CITED: D:/simple_player_flutter/pubspec.yaml#L9-L39] | Input-mode and glow state | Required project state-management convention. [CITED: D:/simple_player_flutter/CLAUDE.md#L80-L85] |
| Flutter `AnimatedSwitcher` | Flutter 3.44.8 installed [VERIFIED: local Flutter CLI] | Cross-fade keyboard and gamepad hint content | It supplies the desired FadeTransition when child key/type changes. [CITED: D:/flutter/packages/flutter/lib/src/widgets/animated_switcher.dart#L78-L84] [CITED: D:/flutter/packages/flutter/lib/src/widgets/animated_switcher.dart#L213-L235] |

### Supporting

| Primitive | Purpose | When to Use |
|-----------|---------|-------------|
| `ControlBarDecoration.playing` | Reuse control-bar color, border, and four-shadow language | Tab-arrow shell/glow decoration only; it deliberately does not include blur. [CITED: D:/simple_player_flutter/lib/ui/shared/control_bar_decoration.dart#L3-L9] [CITED: D:/simple_player_flutter/lib/ui/shared/control_bar_decoration.dart#L29-L60] |
| `RepaintBoundary` | Isolate independently animated arrow-button repaint work | Wrap each `TabArrowButton`, not the whole tab strip. [ASSUMED] |
| `Timer` / cancellable deadline | Implement five-second mouse-idle decision | Keep the timer in the detector; cancel in `dispose` and make tests use fake time. [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Heuristic plus manual toggle | Steamworks/Steam Input FFI | Out of scope and prohibited by NAV-02; project Steam plan describes Steam Input SDK as a future option, not a present dependency. [CITED: C:/Users/35490/.claude/projects/D--simple-player-flutter/memory/project_steam_steamos_plan.md#L54-L63] |
| `Listener.onPointerHover` plus `onPointerMove` | `onPointerMove` alone | Incorrect for idle desktop mice because move is only after a pointer-down; hover covers not-down mouse movement. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280] |
| Existing root `Focus` | A nested focus handler inside every option/list widget | Nested handlers can consume or leak events before root routing; the current root already scopes the panel. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L30-L33] [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L263-L297] |

**Installation:** No external package installation is required. [VERIFIED: D:/simple_player_flutter/pubspec.yaml]

## Architecture Patterns

### System Architecture Diagram

```text
Desktop mouse movement ──> settings-root Listener.onPointerHover/onPointerMove
                                  │
                                  ▼
                           InputModeDetector
                     (last mouse time + override state)
                                  │ effective mode
                                  ├───────────────> InputModeHint AnimatedSwitcher
                                  │
KeyDown ───────────────> settings-root Focus.onKeyEvent
                                  │
                  ┌───────────────┼────────────────┐
                  ▼               ▼                ▼
             Left/Right      Up/Down            ESC/B
           prev/next tab   trigger glow          close
           record heuristic    + handled         + handled
                  │               │
                  ▼               ▼
       SettingsPanelController  option-list overlay
                  │
                  ▼
       selectedTab ValueNotifier ──> SettingsTabStrip + IndexedStack

Any recognized directional key returns handled
     └─ prevents bubbling to outer KeyboardHandler seek/volume callbacks
```

### Recommended Project Structure

```text
lib/
├── kernel/services/
│   └── input_mode_detector.dart       # singleton policy, timer, override, disposal
└── ui/dialogs/settings/
    ├── input_mode_hint.dart           # AnimatedSwitcher visual projection
    ├── tab_arrow_button.dart          # end-cap button + RepaintBoundary
    ├── option_list_navigation_overlay.dart # thin arrows + directional glow state
    ├── panel_key_bindings.dart        # single root keyboard router
    ├── settings_overlay_shell.dart    # root Focus + window-level Listener mount
    └── tab_strip.dart                 # Row end-cap mount point
```

### Pattern 1: Treat Steam-mapped arrows as ordinary arrows

**What:** The root key router must route `LogicalKeyboardKey.arrowLeft` and `arrowRight` once, regardless of whether a keyboard or Steam Input mapping produced them. Do not use `physicalKey`, pressed-key state, or Windows `deviceType` as a Steam-origin discriminator. [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L134-L183] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242]

**When to use:** Every panel navigation event where Steam Input may emit keyboard mappings. [ASSUMED]

**Exact separability finding:** Flutter has constants for distinct direct gamepad keys (`LogicalKeyboardKey.gameButtonLeft1` / `gameButtonRight1`, and physical counterparts) and arrow keys with other numeric IDs; therefore a direct gamepad event can be distinct. However, an external mapping that emits an ordinary keyboard Left/Right reaches Flutter with the arrow values supplied by the platform, and current Windows/non-Android conversion labels device type as `keyboard`. No Flutter API carries an original Steam controller identity after that mapping. The precise signature of a particular Steam controller configuration is therefore **not determinable from source alone** and needs manual hardware evidence. [CITED: D:/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart#L790-L795] [CITED: D:/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart#L2519-L2534] [CITED: D:/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart#L4241-L4246] [CITED: D:/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart#L3771-L3789] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242]

**Example:**

```dart
// Sources: Flutter Focus dispatch and KeyEvent APIs:
// https://api.flutter.dev/flutter/widgets/Focus/onKeyEvent.html
// https://api.flutter.dev/flutter/services/KeyEvent-class.html
KeyEventResult handle(FocusNode node, KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  return switch (event.logicalKey) {
    LogicalKeyboardKey.arrowLeft => _previousTabFromArrow(),
    LogicalKeyboardKey.arrowRight => _nextTabFromArrow(),
    LogicalKeyboardKey.arrowUp => _showPreviousOptionGlow(),
    LogicalKeyboardKey.arrowDown => _showNextOptionGlow(),
    LogicalKeyboardKey.escape || LogicalKeyboardKey.keyB => _closePanel(),
    _ => KeyEventResult.ignored,
  };
}
```

The four directional branches must all call `InputModeDetector.recordArrowKey()` before their panel action and return `KeyEventResult.handled`; do not route direct `gameButtonLeft1`/`gameButtonRight1`. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239] [CITED: D:/simple_player_flutter/lib/ui/player/keyboard_handler.dart#L114-L132]

### Pattern 2: Mouse-idle heuristic with explicit override

**What:** Mount one `Listener(behavior: HitTestBehavior.translucent)` around the visible settings panel content (inside the overlay, outside the panel root `Focus`). On `PointerHoverEvent` of `PointerDeviceKind.mouse`, record keyboard mode; also observe `onPointerMove` for mouse drag movement. On each recognized arrow key, schedule/refresh a five-second delayed check; only when no newer mouse timestamp exists at expiry should automatic detection select gamepad. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7244-L7280] [CITED: D:/flutter/packages/flutter/lib/src/gestures/events.dart#L299-L316]

**When to use:** Only while the settings overlay is open; dispose/cancel its timer when the detector is disposed or the panel closes. [ASSUMED]

**Recommended state contract:** Keep `InputMode { keyboard, gamepad, auto }` as the user preference notifier and store the automatic effective result privately. Expose a read-only effective mode listenable (or a derived `ValueNotifier`) for hints. Manual keyboard/gamepad selection wins; selecting `auto` re-enables the mouse/idle heuristic. This removes the otherwise ambiguous meaning of `auto` as both a selection and a rendered hint state. [ASSUMED]

**Why the original wording needs correction:** `PointerMoveEvent → keyboard` is insufficient on desktop: Flutter documents it only while the pointer is down. Use mouse `PointerHoverEvent` as the normal pointer-motion signal and retain move as a drag supplement. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280] [CITED: D:/flutter/packages/flutter/lib/src/gestures/events.dart#L1604-L1640]

### Pattern 3: End-cap row composition

**What:** Replace the current `Row(children: List.generate(... Expanded(SettingsNavItem)))` with `Row(children: [TabArrowButton(left), Expanded(child: Row(tab items)), TabArrowButton(right)])`. The two buttons are persistent and call the same controller callbacks as keys; no second tab-selection state is introduced. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/tab_strip.dart#L61-L88] [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_panel_controller.dart#L66-L74]

**When to use:** Both compact and normal layouts; obtain all button dimensions/radius/duration from new `Tokens.tabArrowRadius` and `Tokens.hintFadeDuration` constants. [ASSUMED]

### Pattern 4: Single blur owner and translucent list overlays

**What:** `SettingsOverlayShell` already puts the whole panel below `GlassContainer(tier: GlassTier.normal)`. `ControlBarDecoration` supplies only decoration, explicitly excluding `BackdropFilter`. Therefore option-list arrows must use `Container(color: Tokens.bgGlass)` and optional shared border/glow decoration inside that existing blur owner. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L263-L294] [CITED: D:/simple_player_flutter/lib/ui/shared/control_bar_decoration.dart#L3-L9] [CITED: D:/simple_player_flutter/lib/ui/shared/glass_container.dart#L144-L168]

**When to use:** For top/bottom arrow overlays only. Do not construct `GlassContainer` or a new `BackdropFilter` there. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L45-L46]

### Anti-Patterns to Avoid

- **Key-source guessing from an arrow event:** Do not decide that `physicalKey.arrowLeft`, `HardwareKeyboard`, or Windows device type proves keyboard versus Steam Input; mapped keyboard events lose provenance at the platform boundary. [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L134-L183] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242]
- **`onPointerMove` as the only mouse detector:** It misses normal hover movement. Use `onPointerHover` for mouse idle reset. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280]
- **A nested arrow-key Focus:** It can return ignored/handled before the panel router and makes global shortcut leakage difficult to reason about. Preserve exactly one settings-root key router. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239]
- **A second `BackdropFilter` for list arrows:** This creates another blur/readback layer under an existing panel blur; use the translucent color-only overlay mandated by NAV-05. [CITED: D:/simple_player_flutter/lib/ui/shared/glass_container.dart#L144-L168] [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L45-L46]

## Existing Binding Impact Surface (NAV-04)

The requested grep target in `lib/ui/player/keyboard_handler.dart` has **zero** `gameButtonLeft1` / `gameButtonRight1` hits; it only owns global arrows for seek and volume at lines 118-132. The raw shoulder bindings actually live in `lib/ui/dialogs/settings/panel_key_bindings.dart`. This correction is important for the plan. [VERIFIED: D:/simple_player_flutter/lib/ui/player/keyboard_handler.dart#L101-L210] [VERIFIED: D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart#L73-L81]

| Reference | Current behavior | Required Phase 32 action |
|-----------|------------------|--------------------------|
| `panel_key_bindings.dart:19` | Class contract claims gameButton13/12 plus cross-platform Left1/Right1 routing. [VERIFIED: D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart#L16-L23] | Update documentation to describe arrow-only tab routing and direct non-obsolete keys only if retained by a deliberate decision. |
| `panel_key_bindings.dart:73-76` | `_isLeftShoulder` treats `gameButton13` and `gameButtonLeft1` as previous tab. [VERIFIED: D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart#L73-L76] | Delete the `gameButtonLeft1` comparison. |
| `panel_key_bindings.dart:78-81` | `_isRightShoulder` treats `gameButton12` and `gameButtonRight1` as next tab. [VERIFIED: D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart#L78-L81] | Delete the `gameButtonRight1` comparison. |
| `settings_overlay_shell_test.dart:614-651` | Two widget tests assert cross-platform raw `gameButtonRight1` and `gameButtonLeft1` navigation. [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings_overlay_shell_test.dart#L614-L651] | Delete/replace with tests that assert the prohibited logical-key strings are absent and arrow routing occurs once. |
| `settings_overlay_shell_test.dart:574-611`, `settings_responsive_integration_test.dart:292-323`, `settings_focus_navigation_test.dart:150-171` | Tests retain `gameButton12`/`gameButton13` direct-gamepad behavior. [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_overlay_shell_test.dart#L574-L611] [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_responsive_integration_test.dart#L292-L323] [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_focus_navigation_test.dart#L150-L171] | Keep only if the plan explicitly says direct gamepad events remain supported; they are not the NAV-04 deletion target. [ASSUMED] |

**Atomicity requirement:** NAV-04 and NAV-07 must be one plan/task group. Deleting bindings without ensuring the root router handles Left/Right lets an ignored event continue to the outer `KeyboardHandler`, whose arrow callbacks seek ±5 seconds; conversely, root handling without deleting old raw branches leaves duplicate navigation routes. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239] [CITED: D:/simple_player_flutter/lib/ui/player/player_screen.dart#L171-L180] [CITED: D:/simple_player_flutter/lib/ui/player/keyboard_handler.dart#L118-L124]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Steam Input protocol/FFI | A custom Steamworks adapter, controller-device parser, or source classifier | Steam mapping plus the required heuristic/manual fallback | NAV-02 explicitly excludes Steamworks SDK FFI; a keyboard injection has no retained provenance in Flutter’s public event contract. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L41-L44] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242] |
| Hint fade | Custom animation controller for a two-label swap | `AnimatedSwitcher` + `ValueKey<InputMode>` | Flutter already cross-fades new and old keyed children. [CITED: D:/flutter/packages/flutter/lib/src/widgets/animated_switcher.dart#L78-L84] [CITED: D:/flutter/packages/flutter/lib/src/widgets/animated_switcher.dart#L213-L235] |
| Glass arrow overlay | Another blur/GlassContainer implementation | Color-only `Container(color: Tokens.bgGlass)` within existing panel blur | Avoids nested blur and follows NAV-05’s explicit requirement. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L45-L46] |

**Key insight:** Phase 32 is a routing/state-projection change, not a Steam integration. Preserve a single authoritative tab controller and a single root key boundary. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_panel_controller.dart#L37-L74] [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L260-L297]

## Common Pitfalls

### Pitfall 1: Arrow event leaks to player shortcuts

**What goes wrong:** Left/Right seeks and Up/Down changes volume while the settings overlay is visible. [CITED: D:/simple_player_flutter/lib/ui/player/keyboard_handler.dart#L118-L132]

**Why it happens:** Flutter sends an ignored key from primary focus to each ancestor; `KeyboardHandler` is outside the panel. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239] [CITED: D:/simple_player_flutter/lib/ui/player/player_screen.dart#L171-L230]

**How to avoid:** In the sole root settings `Focus`, return `handled` for every recognized directional `KeyDownEvent`, including Up/Down when only glow feedback occurs. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L263-L297]

**Warning signs:** A widget test that changes selected tab but does not embed an outer `KeyboardHandler` can miss leakage. [ASSUMED]

### Pitfall 2: Incorrect mouse signal makes auto mode sticky

**What goes wrong:** Mouse movement does not reset the idle timer, so ordinary keyboard use is shown as gamepad. [ASSUMED]

**Why it happens:** `onPointerMove` only follows pointer down; hovering mouse motion uses `onPointerHover`. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280]

**How to avoid:** Filter `PointerHoverEvent.kind == PointerDeviceKind.mouse`; additionally record mouse `PointerMoveEvent` during drags. Store a monotonic timestamp and verify it again when the five-second timer fires. [CITED: D:/flutter/packages/flutter/lib/src/gestures/events.dart#L299-L316] [ASSUMED]

**Warning signs:** Detector unit tests pass only drag events and never send a hover event. [ASSUMED]

### Pitfall 3: Ambiguous `auto` state cannot drive hints

**What goes wrong:** A notifier value of `auto` leaves `InputModeHint` unable to choose keyboard or gamepad content. [ASSUMED]

**Why it happens:** User preference and effective detected input are distinct state concepts. [ASSUMED]

**How to avoid:** Specify two concepts: public preference (`keyboard`, `gamepad`, `auto`) and derived effective presentation (`keyboard` or `gamepad`). The planner must make the derived listenable/notifier ownership and disposal explicit. [ASSUMED]

**Warning signs:** Widget code switches directly on `InputMode.auto` to render a label. [ASSUMED]

### Pitfall 4: Tab arrows overflow the 7-item row

**What goes wrong:** Adding fixed end caps without reserving remaining width compresses/overflows tab labels, particularly compact mode. [ASSUMED]

**Why it happens:** The current strip gives every one of seven items an equal `Expanded` slot across the whole row. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/tab_strip.dart#L74-L87]

**How to avoid:** Make the two end caps fixed tokenized widths and put the seven `Expanded` items in a nested `Expanded(Row(...))`; widget-test both compact and normal widths. [ASSUMED]

### Pitfall 5: Nested blur/readback and broad repaints

**What goes wrong:** Animating list arrows creates expensive additional blur work or causes the whole panel to repaint. [ASSUMED]

**Why it happens:** The panel already owns `GlassContainer`’s `BackdropFilter`, which wraps a repaint boundary; another GlassContainer inserts another filter. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L263-L294] [CITED: D:/simple_player_flutter/lib/ui/shared/glass_container.dart#L144-L168]

**How to avoid:** Use color-only overlays, isolate independently animated tab arrows with `RepaintBoundary`, and use a small notifier localized to arrow glow. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L45-L46] [ASSUMED]

## Code Examples

### Keyed hint fade

```dart
// Source: https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html
class InputModeHint extends StatelessWidget {
  const InputModeHint({super.key, required this.mode});

  final ValueListenable<InputMode> mode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InputMode>(
      valueListenable: mode,
      builder: (context, effectiveMode, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: Tokens.hintFadeDuration),
        child: Text(
          effectiveMode == InputMode.gamepad ? 'LB / RB' : '← / →',
          key: ValueKey(effectiveMode),
        ),
      ),
    );
  }
}
```

`AnimatedSwitcher` only starts a transition when a child’s type or key changes, and its default builder is a fade; `ValueKey(effectiveMode)` is therefore required. [CITED: D:/flutter/packages/flutter/lib/src/widgets/animated_switcher.dart#L78-L84] [CITED: D:/flutter/packages/flutter/lib/src/widgets/animated_switcher.dart#L213-L235]

### Root mouse observer

```dart
// Sources: Listener / PointerHoverEvent APIs
// https://api.flutter.dev/flutter/widgets/Listener-class.html
// https://api.flutter.dev/flutter/gestures/PointerMoveEvent-class.html
Listener(
  behavior: HitTestBehavior.translucent,
  onPointerHover: detector.recordPointerActivity,
  onPointerMove: detector.recordPointerActivity,
  child: Focus(
    autofocus: true,
    onKeyEvent: keyBindings.handle,
    child: panel,
  ),
)
```

The detector must ignore non-mouse pointer kinds; `onPointerHover` is the primary desktop movement signal, and `onPointerMove` supplements drag movement. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280] [CITED: D:/flutter/packages/flutter/lib/src/gestures/events.dart#L299-L316]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `RawKeyboardListener` / raw key callbacks | `Focus.onKeyEvent` / `KeyEvent` | Flutter documents the old `onKey` as deprecated after v3.18.0-2.0.pre. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L123-L150] | Keep the existing `Focus.onKeyEvent` path; do not introduce RawKeyboard APIs. |
| Independent panel chrome values | `ControlBarDecoration` shared decoration | Phase 31 baseline. [CITED: D:/simple_player_flutter/.planning/phases/31-visual-design-alignment/VERIFICATION.md#L9-L15] | Match arrows to control-bar decoration tokens without copying values. |

**Deprecated/outdated:** `Focus.onKey` is deprecated; continue using `Focus.onKeyEvent` as the existing shell does. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L123-L150] [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart#L263-L268]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A `RepaintBoundary` around each independently animated tab arrow is sufficient repaint isolation. | Standard Stack / Pitfall 5 | May need DevTools/profile evidence or a different boundary placement. |
| A2 | The input-mode API should model preference and effective mode separately. | Pattern 2 / Pitfall 3 | A poorly specified API could make auto-mode hints inconsistent. |
| A3 | Direct `gameButton12`/`gameButton13` support may remain after NAV-04 removes only Left1/Right1. | Binding Impact Surface | Could preserve an unintended second gamepad route; planner must verify with a Windows controller. |
| A4 | Five-second detection should use a cancellable timer and be active only while the settings panel is open. | Standard Stack / Pattern 2 | Lifecycle/timer leaks or detector behavior outside panel scope. |
| A5 | Fixed end caps plus nested expanded tab row preserve compact layout. | Pitfall 4 | Compact labels could overflow without measurement. |

## Open Questions

1. **What exact KeyEvent signature does the target Steam Input profile emit on Windows?**
   - What we know: Direct Flutter gamepad logical/physical keys have distinct constants, but Flutter exposes no origin metadata once an external layer emits a keyboard arrow; Windows/non-Android raw conversion defaults device type to keyboard. [CITED: D:/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart#L790-L795] [CITED: D:/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart#L2519-L2534] [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242]
   - What is unclear: Whether the installed Steam profile injects plain keyboard events or presents direct gamepad events for LB/RB.
   - Recommendation: Add a debug-only/manual Windows test matrix logging `logicalKey`, `physicalKey`, `deviceType`, and `synthesized` for native arrows, Steam LB/RB, and a direct controller; do not alter production routing based on an unverified signature. [ASSUMED]

2. **Which UI owns the manual input-mode toggle?**
   - What we know: NAV-02 locks a toggle fallback but does not name its placement. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L41-L44]
   - What is unclear: Whether it belongs in the shortcuts tab, panel title bar, or another settings control.
   - Recommendation: Planner should add a compact control in the Shortcuts tab, because that tab already owns key-capture UI through `KeyboardListener`. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/shortcuts_tab.dart#L104-L107] [ASSUMED]

3. **Which option-list widget receives NAV-05/06 overlays first?**
   - What we know: `SettingsTabContent` is a colored `IndexedStack` container and has no generic scroll/list overlay seam. [CITED: D:/simple_player_flutter/lib/ui/dialogs/settings/tab_content.dart#L47-L120]
   - What is unclear: Which shipped tab/list has the intended top/bottom option-list navigation model.
   - Recommendation: Scope the new overlay to the specific scrollable settings list selected by the planner; do not overlay all seven IndexedStack children speculatively. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | Widget/unit tests and Flutter APIs | ✓ | 3.44.8 [VERIFIED: local Flutter CLI] | — |
| Dart SDK | Analyzer/tests | ✓ | 3.12.2 [VERIFIED: local Dart CLI] | — |
| Windows + Steam Input controller | Exact Steam event-signature and dual-mode validation | ✗ in this research environment [ASSUMED] | — | Manual Windows acceptance checkpoint; heuristic remains source-agnostic. |

**Missing dependencies with no fallback:**
- Physical Windows Steam Input validation is required to verify the target controller profile’s actual emitted signature and absence of double-fire. [ASSUMED]

**Missing dependencies with fallback:**
- No code dependency is blocked: source-agnostic arrow routing and widget/unit coverage can proceed without Steam SDK or FFI. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L41-L44]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` from Flutter SDK [CITED: D:/simple_player_flutter/pubspec.yaml#L34-L39] |
| Config file | `pubspec.yaml`; no separate test config found. [VERIFIED: D:/simple_player_flutter/pubspec.yaml] |
| Quick run command | `flutter test test/kernel/services/input_mode_detector_test.dart test/ui/dialogs/settings/settings_tab_strip_test.dart test/ui/dialogs/settings/settings_overlay_shell_test.dart` [ASSUMED] |
| Full suite command | `flutter analyze && flutter test --coverage` [CITED: D:/simple_player_flutter/CLAUDE.md#L5-L12] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NAV-01 | End-cap buttons persist, click invokes controller navigation, Left/Right switches tabs | widget | `flutter test test/ui/dialogs/settings/settings_tab_strip_test.dart test/ui/dialogs/settings/settings_overlay_shell_test.dart` | ❌ Wave 0 for strip test; shell test exists. [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_overlay_shell_test.dart#L499-L572] |
| NAV-02 | Mouse hover selects keyboard; arrow after five seconds idle selects gamepad; override wins | unit with fake clock/timer | `flutter test test/kernel/services/input_mode_detector_test.dart` | ❌ Wave 0 |
| NAV-03 | Mode changes replace a keyed child and drive fade configuration | widget | `flutter test test/ui/dialogs/settings/input_mode_hint_test.dart` | ❌ Wave 0 |
| NAV-04 | No `gameButtonLeft1`/`gameButtonRight1` production references; raw shoulder tests removed | source-grep gate plus widget | `git grep -nE 'gameButtonLeft1|gameButtonRight1' -- ':(exclude)test/**' 'lib/**'` and shell test | Existing tests require replacement. [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_overlay_shell_test.dart#L614-L651] |
| NAV-05 | Option arrows are color-only overlay, no added `BackdropFilter` below panel | widget structural test | `flutter test test/ui/dialogs/settings/option_list_navigation_overlay_test.dart` | ❌ Wave 0 |
| NAV-06 | Up/Down produces the correct temporary glow notifier/view state and is handled | unit + widget | `flutter test test/ui/dialogs/settings/panel_key_bindings_test.dart test/ui/dialogs/settings/option_list_navigation_overlay_test.dart` | ❌ Wave 0 |
| NAV-07 | Root handler handles all arrows and prevents outer player seek/volume callbacks | integration-style widget with outer `KeyboardHandler` fake callbacks | `flutter test test/ui/dialogs/settings/settings_overlay_shell_test.dart` | Existing shell test needs an outer-handler leakage case. [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_overlay_shell_test.dart#L501-L572] |

### Manual-Only Validation

| Scenario | Why manual | Acceptance evidence |
|----------|------------|---------------------|
| Native keyboard Left/Right versus Steam Input LB/RB on Windows | Headless Flutter tests can synthesize keys but cannot prove the Steam/Windows mapping’s original platform event signature or duplicate delivery. [ASSUMED] | Record key log fields, tab-index delta exactly one per press, and correct hint mode/fallback toggle. |
| GPU/perceptual thin-glass quality | Structural tests can assert no additional `BackdropFilter`; they cannot prove visual match/readback cost on target hardware. [ASSUMED] | Inspect top/bottom overlays on the open panel and profile for no new blur layer/jank. |

### Sampling Rate

- **Per task commit:** Run the targeted detector and settings-widget test files. [ASSUMED]
- **Per wave merge:** Run `flutter analyze` plus Phase 32 test files. [CITED: D:/simple_player_flutter/CLAUDE.md#L5-L12]
- **Phase gate:** Full `flutter test --coverage` plus manual Windows keyboard/controller matrix; account for the documented pre-existing headless `mdk.dll` baseline separately. [CITED: D:/simple_player_flutter/.planning/phases/31-visual-design-alignment/VERIFICATION.md#L28-L34]

### Wave 0 Gaps

- [ ] `test/kernel/services/input_mode_detector_test.dart` — deterministic idle, hover, override, and disposal coverage for NAV-02.
- [ ] `test/ui/dialogs/settings/settings_tab_strip_test.dart` — end-cap geometry/click and compact-width coverage for NAV-01.
- [ ] `test/ui/dialogs/settings/input_mode_hint_test.dart` — keyed `AnimatedSwitcher` replacement coverage for NAV-03.
- [ ] `test/ui/dialogs/settings/option_list_navigation_overlay_test.dart` — no-second-blur structure and Up/Down glow coverage for NAV-05/06.
- [ ] Extend `settings_overlay_shell_test.dart` with outer `KeyboardHandler` spy callbacks to prove arrow containment for NAV-07.
- [ ] Repair/confirm `settings_focus_navigation_test.dart` baseline before relying on it: its fake construction uses `initiallyPlaying`, while the current fake constructor accepts `initialState`. [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_focus_navigation_test.dart#L16-L21] [VERIFIED: D:/simple_player_flutter/test/ui/dialogs/settings/settings_panel_controller_test.dart#L17-L20]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [ASSUMED] | No auth surface in this local settings-navigation phase. |
| V3 Session Management | no [ASSUMED] | No session state is introduced. |
| V4 Access Control | no [ASSUMED] | No authorization boundary is introduced. |
| V5 Input Validation | yes [ASSUMED] | Accept only known `KeyEvent`/pointer kinds at the panel boundary; ignore unrelated keys and non-mouse pointer activity for detector input. |
| V6 Cryptography | no [ASSUMED] | No cryptographic operation or secret is introduced. |

### Known Threat Patterns for Flutter input routing

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted/synthetic key sequence drives global playback shortcuts while modal settings is open | Tampering | Root settings `Focus` returns `handled` for recognized arrows; unrelated keys remain ignored. [CITED: D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart#L227-L239] |
| Timer callback after detector disposal | Denial of Service / stability | Cancel timer and guard lifecycle in `dispose`; test disposal. [ASSUMED] |
| Excess GPU readback from nested blur filters | Denial of Service / responsiveness | Use NAV-05 color-only container under the existing `GlassContainer` blur. [CITED: D:/simple_player_flutter/.planning/REQUIREMENTS.md#L45-L46] [CITED: D:/simple_player_flutter/lib/ui/shared/glass_container.dart#L144-L168] |

## Sources

### Primary (HIGH confidence)
- [D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart](D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart) - live root focus, panel composition, and existing blur boundary.
- [D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart](D:/simple_player_flutter/lib/ui/dialogs/settings/panel_key_bindings.dart) - live game-button and arrow routing surface.
- [D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart](D:/flutter/packages/flutter/lib/src/widgets/focus_scope.dart) - focus bubbling semantics.
- [D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart](D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart) - event keys and Windows/non-Android device-type conversion.

### Secondary (MEDIUM confidence)
- [Flutter Focus API](https://api.flutter.dev/flutter/widgets/Focus/onKeyEvent.html) - current documented key-event callback semantics.
- [Flutter KeyEvent API](https://api.flutter.dev/flutter/services/KeyEvent-class.html) - physical/logical/device fields.
- [Flutter Listener API](https://api.flutter.dev/flutter/widgets/Listener-class.html) - pointer hover/move callbacks.
- [Flutter AnimatedSwitcher API](https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html) - keyed default fade behavior.

### Tertiary (LOW confidence)
- No external web-only sources used. Steam Input’s exact emitted Windows signature remains a manual-validation item rather than a claimed fact.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing Flutter SDK, live project conventions, and source APIs were inspected. [VERIFIED: local Flutter CLI]
- Architecture: HIGH - live settings shell, tab strip, controller, focus dispatcher, and player shortcut boundary were read. [VERIFIED: D:/simple_player_flutter/lib/ui/dialogs/settings/settings_overlay_shell.dart]
- Steam Input separability: MEDIUM - Flutter’s loss of origin/provenance after an external keyboard mapping is well-supported by API/source constraints, but the target Steam profile has not been captured on Windows hardware. [CITED: D:/flutter/packages/flutter/lib/src/services/hardware_keyboard.dart#L1217-L1242]
- Pitfalls: MEDIUM - focus/hover/blur pitfalls are source-backed; timing/repaint placement needs implementation profiling. [CITED: D:/flutter/packages/flutter/lib/src/widgets/basic.dart#L7268-L7280]

**Research date:** 2026-07-28
**Valid until:** 2026-08-27
