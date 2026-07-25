# Phase 24: Sidebar Navigation - Research

**Researched:** 2026-07-23
**Domain:** Flutter settings panel tab navigation system (horizontal tab bar + IndexedStack + keyboard/gamepad input)
**Confidence:** HIGH

## Summary

Phase 24 builds a horizontal tab bar navigation system inside the existing `SettingsOverlayShell` (Phase 23). The shell skeleton (291 lines) is already in place with glass overlay, mask, title bar, drag, and ESC/B close handling. This phase inserts a 40px horizontal tab bar (7 tabs, equal-width) between the title bar and content area, wires tab switching via click/keyboard arrow keys/gamepad shoulder buttons, and adds FadeTransition content animation.

The user decided to override the roadmap's "200px left sidebar" layout with a Top/Middle/Bottom three-section horizontal layout. All SIDEBAR-01~04 requirements remain, but SIDEBAR-01's semantics changed from vertical sidebar to horizontal tab bar.

**Primary recommendation:** Extend `settings_overlay_shell.dart` with a `_buildTabBar()` method and replace the empty `Expanded` content area with `IndexedStack` + `TweenAnimationBuilder<double>` opacity animation. Refactor `_settings_nav_item.dart` from vertical 80px to horizontal equal-width. Add arrow key + gamepad shoulder button handling to the shell's existing `_handleKeyEvent`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tab bar rendering | UI (settings_overlay_shell.dart) | — | Shell owns the Column layout, tab bar is a Row child |
| Tab state (selectedTab) | State (settings_panel_state.dart) | — | ValueNotifier<int> already exists, shared by click/keyboard/gamepad |
| Tab switching logic | Controller (settings_panel_controller.dart) | — | nextTab()/prevTab() methods with wrapping |
| Keyboard arrow interception | UI (settings_overlay_shell.dart Focus) | — | Panel's Focus node consumes ← → before KeyboardHandler |
| Gamepad LB/RB interception | UI (settings_overlay_shell.dart Focus) | — | Same Focus node, gameButton12/13 constants |
| Content animation | UI (per-tab TweenAnimationBuilder) | — | Each tab wraps its IndexedStack child with opacity tween |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | 3.44.6 | Framework | Already installed, verified |
| flutter/material.dart | (SDK) | IndexedStack, FadeTransition, TweenAnimationBuilder | Built-in, no extra deps |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Tokens.* | project-local | Design tokens (bgPanel, accent, textSecondary, spMd, durationFast) | All visual values |
| GlassContainer | project-local | Glass tier wrapper for content area | Content area background |
| AppleCurves | project-local | Animation curves (fullscreenEnter/Exit) | Tab content fade animation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| IndexedStack | AnimatedSwitcher (old panel) | AnimatedSwitcher destroys/recreates tabs on switch; IndexedStack keeps all alive (D-01) |
| TweenAnimationBuilder | AnimationController + FadeTransition | TweenAnimationBuilder auto-manages controller lifecycle, simpler code (D-02) |
| gameButton12/13 | gameButtonLeft1/Right1 | Windows embedder maps shoulder buttons to gameButton12/13, not Left1/Right1 |

**Installation:** No new packages needed. All components are Flutter SDK built-in or project-local.

## Package Legitimacy Audit

> No external packages are installed in this phase. All components are Flutter SDK built-in or already present in the project.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | No new packages |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
PlayerScreen Stack
  └── SettingsOverlayShell (Phase 23, 291 lines)
        ├── Mask (AnimatedOpacity + GestureDetector → close)
        └── Center > Transform.translate > AnimatedScale > AnimatedOpacity
              └── GlassContainer (GlassTier.normal)
                    └── SizedBox (500×400)
                          └── Column
                                ├── [EXISTING] _buildTitleBar (44px, "设置" + close)
                                ├── [NEW] _buildTabBar (40px, 7 equal-width tabs, bgPanel)
                                └── [NEW] IndexedStack (index = selectedTab)
                                      ├── Tab 0: GeneralTab placeholder
                                      ├── Tab 1: EQ placeholder
                                      ├── Tab 2: Audio placeholder
                                      ├── Tab 3: Video placeholder
                                      ├── Tab 4: Shortcuts placeholder
                                      ├── Tab 5: About placeholder
                                      └── Tab 6: Performance placeholder
```

### Recommended Project Structure

```
lib/ui/dialogs/settings/
├── settings_overlay_shell.dart    # [MODIFY] Add _buildTabBar + IndexedStack + key handling
├── _settings_nav_item.dart        # [REFACTOR] Vertical 80px → Horizontal equal-width tab
├── settings_panel_state.dart      # [NO CHANGE] selectedTab notifier already exists
├── settings_panel_controller.dart # [MODIFY] Add nextTab()/prevTab() wrapping methods
├── general_tab.dart               # [EXISTING] Phase 25 fills content
├── equalizer_tab.dart             # [EXISTING]
├── audio_tab.dart                 # [EXISTING]
├── video_tab.dart                 # [EXISTING]
├── shortcuts_tab.dart             # [EXISTING]
├── about_tab.dart                 # [EXISTING]
└── settings_tab_performance.dart  # [EXISTING]
```

### Pattern 1: IndexedStack + TweenAnimationBuilder Opacity

**What:** Keep all 7 tabs alive in IndexedStack, wrap each with TweenAnimationBuilder<double> for opacity animation on tab switch.
**When to use:** When tab state (scroll position, pending values) must persist across switches.
**Example:**
```dart
// Source: D-01/D-02 decisions + existing TweenAnimationBuilder usage in center_controls.dart
IndexedStack(
  index: selectedTab,
  children: List.generate(7, (i) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: i == selectedTab ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: _buildTabContent(i), // placeholder or real tab
    );
  }),
)
```

### Pattern 2: SettingsNavItem Horizontal Refactor

**What:** Refactor vertical 80px nav item to horizontal equal-width tab item. Keep hover/selected interaction logic, change layout from Column to Row, remove fixed width (use Expanded in parent Row).
**When to use:** Tab bar items in horizontal layout.
**Example:**
```dart
// Refactored from _settings_nav_item.dart
class SettingsNavItem extends StatefulWidget {
  // Same props: icon, label, selected, onTap
  // Layout changes:
  // - Remove width: 80 (parent Row uses Expanded)
  // - Column → Row (icon + label horizontal)
  // - Left border indicator → Bottom border indicator
  // - Keep MouseRegion hover + GestureDetector tap + AnimatedContainer
}
```

### Pattern 3: Keyboard/Gamepad Tab Switching in Focus Node

**What:** Extend the shell's existing `_handleKeyEvent` to consume arrow keys and gamepad shoulder buttons for tab switching, preventing them from bubbling to KeyboardHandler.
**When to use:** Panel is open and Focus is on the shell.
**Example:**
```dart
// In settings_overlay_shell.dart _handleKeyEvent
KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  // [EXISTING] ESC/B close
  if (event.logicalKey == LogicalKeyboardKey.escape ||
      event.logicalKey == LogicalKeyboardKey.keyB) {
    _controller.close();
    return KeyEventResult.handled;
  }

  // [NEW] Arrow left/right → prev/next tab (D-04/D-06)
  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
    _controller.prevTab();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
    _controller.nextTab();
    return KeyEventResult.handled;
  }

  // [NEW] Gamepad LB/RB → prev/next tab (D-05/D-06)
  // Windows embedder: LEFT_SHOULDER → gameButton13, RIGHT_SHOULDER → gameButton12
  if (event.logicalKey == LogicalKeyboardKey.gameButton13) {
    _controller.prevTab();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.gameButton12) {
    _controller.nextTab();
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
}
```

### Anti-Patterns to Avoid

- **AnimatedSwitcher for tab content:** Destroys and recreates tabs on each switch, losing pending values and scroll positions. Use IndexedStack instead (D-01).
- **AnimationController for tab opacity:** Requires manual lifecycle management (initState/dispose). TweenAnimationBuilder auto-manages (D-02).
- **gameButtonLeft1/Right1 for shoulder buttons:** On Windows, shoulder buttons map to gameButton12/13 via the embedder, not Left1/Right1. Must check both for cross-platform compatibility.
- **Hardcoded bgSurface token:** Tokens.bgSurface does not exist in tokens.dart. Use Tokens.bgPanel (0xFF111520) for the tab bar background.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab content persistence | Custom visibility toggling | IndexedStack | Built-in, keeps all children alive, single index controls visibility |
| Opacity animation on tab switch | Manual AnimationController + listener | TweenAnimationBuilder<double> | Auto-disposes, no lifecycle management, existing pattern in codebase |
| Gamepad button detection | Raw HID polling or platform channels | LogicalKeyboardKey.gameButton12/13 | Flutter SDK built-in, Windows embedder maps GAMEPAD_LEFT/RIGHT_SHOULDER |
| Equal-width tab distribution | Manual width calculation | Expanded(flex: 1) in Row | Flutter layout handles equal distribution automatically |

## Common Pitfalls

### Pitfall 1: bgSurface Token Does Not Exist
**What goes wrong:** Code references `Tokens.bgSurface` but this constant doesn't exist in tokens.dart.
**Why it happens:** The CONTEXT.md D-08 mentions "bgSurface" but the actual token file has bgBase, bgPanel, bgElevated, bgHover, bgGlass.
**How to avoid:** Use `Tokens.bgPanel` (0xFF111520) for the tab bar flat dark background. It's the closest semantic match (panel-level surface).
**Warning signs:** Compilation error on `Tokens.bgSurface`.

### Pitfall 2: Gamepad Shoulder Button Key ID Mismatch
**What goes wrong:** Code checks `LogicalKeyboardKey.gameButtonLeft1` but Windows fires `gameButton13` for LEFT_SHOULDER.
**Why it happens:** Windows embedder maps GAMEPAD_LEFT_SHOULDER (0xc8) → gameButton13 (0x0020000030d), not gameButtonLeft1 (0x00200000314).
**How to avoid:** Check BOTH `gameButton12`/`gameButton13` (Windows) AND `gameButtonLeft1`/`gameButtonRight1` (generic HID) for cross-platform safety.
**Warning signs:** LB/RB not working on Windows despite correct logic.

### Pitfall 3: Arrow Keys Bubbling to KeyboardHandler
**What goes wrong:** Left/Right arrow keys trigger seek ±5s even when settings panel is open.
**Why it happens:** KeyboardHandler has `autofocus: true` and processes arrow keys. If the panel's Focus node doesn't consume the event first, it bubbles.
**How to avoid:** The panel's Focus node (already in shell) must return `KeyEventResult.handled` for arrow keys when panel is open. The Focus tree priority ensures the panel's focused node processes events before KeyboardHandler (D-06/D-10).
**Warning signs:** Seeking happens while navigating tabs.

### Pitfall 4: Tab Reset on Panel Open
**What goes wrong:** Panel remembers last tab across open/close cycles, causing inconsistent state.
**Why it happens:** selectedTab ValueNotifier persists across panel lifecycle.
**How to avoid:** Reset selectedTab to 0 in `SettingsPanelController.open()` (D-03: always reset to General on open).
**Warning signs:** Panel opens to a non-General tab unexpectedly.

## Code Examples

### Verified patterns from official sources:

### IndexedStack with Animated Opacity
```dart
// Source: Flutter SDK IndexedStack + project pattern (center_controls.dart TweenAnimationBuilder)
// D-01: All tabs stay alive, only visibility changes
ValueListenableBuilder<int>(
  valueListenable: _controller.state.selectedTab,
  builder: (context, selectedIndex, _) {
    return IndexedStack(
      index: selectedIndex,
      children: List.generate(7, (i) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: i == selectedIndex ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 200), // D-07: 200ms unified
          builder: (context, opacity, child) => Opacity(
            opacity: opacity,
            child: child,
          ),
          child: _buildTabContent(i),
        );
      }),
    );
  },
)
```

### Horizontal Tab Bar Row
```dart
// D-07/D-09: Top/Middle/Bottom layout, 7 equal-width tabs
Container(
  height: 40,
  color: Tokens.bgPanel, // NOT bgSurface (doesn't exist)
  child: Row(
    children: List.generate(7, (i) {
      return Expanded(
        child: SettingsNavItem(
          icon: _tabIcons[i],
          label: _tabLabels[i],
          selected: selectedIndex == i,
          onTap: () => _controller.state.selectedTab.value = i,
        ),
      );
    }),
  ),
)
```

### Gamepad Shoulder Button Detection (Cross-Platform)
```dart
// Source: Flutter SDK keyboard_key.g.dart + Windows embedder key map
// Windows: LEFT_SHOULDER(0xc8) → gameButton13, RIGHT_SHOULDER(0xc7) → gameButton12
// Generic HID: gameButtonLeft1(0x314), gameButtonRight1(0x317)
bool _isLeftShoulder(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.gameButton13 ||   // Windows embedder
    key == LogicalKeyboardKey.gameButtonLeft1;   // Generic HID

bool _isRightShoulder(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.gameButton12 ||   // Windows embedder
    key == LogicalKeyboardKey.gameButtonRight1;  // Generic HID
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AnimatedSwitcher (old settings_panel.dart) | IndexedStack (D-01) | Phase 24 | Tabs stay alive, pending values persist |
| Manual AnimationController | TweenAnimationBuilder (D-02) | Phase 24 | No lifecycle management needed |
| Vertical sidebar 88px | Horizontal tab bar 40px (D-07) | Phase 24 user decision | Layout override from roadmap |

**Deprecated/outdated:**
- `settings_panel.dart` (945 lines): Old implementation with AnimatedSwitcher + vertical sidebar. Being replaced by new shell + horizontal tab bar. Will be removed after Phase 27.

## Assumptions Log

> List all claims tagged [ASSUMED] in this research.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Tokens.bgPanel is the correct token for tab bar background (bgSurface doesn't exist) | Pattern 2, Pitfall 1 | Low — bgPanel is semantically closest; user may prefer bgElevated |
| A2 | Gamepad shoulder buttons fire as gameButton12/13 on Windows (verified via Flutter SDK embedder source) | Pattern 3, Pitfall 2 | Low — verified from SDK source code |
| A3 | Flutter's Focus tree priority ensures shell's Focus node processes key events before KeyboardHandler | Pitfall 3 | Medium — if Focus priority is wrong, arrow keys will seek instead of switch tabs |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **Tab bar background color: bgPanel vs bgElevated?**
   - What we know: D-08 says "bgSurface flat dark background" but bgSurface doesn't exist in tokens.dart
   - What's unclear: Whether user intended bgPanel (0xFF111520) or bgElevated (0xFF161A28)
   - Recommendation: Use bgPanel (darker, contrasts with glass content area). Ask user if they have a preference.

2. **Gamepad testing availability**
   - What we know: Flutter 3.44.6 on Windows supports gamepad key events via embedder
   - What's unclear: Whether user has a gamepad to test with
   - Recommendation: Implement gamepad support optimistically; test with keyboard arrow keys first, gamepad when hardware available

3. **Tab content placeholders for Phase 24**
   - What we know: Phase 24 only builds navigation, not tab content (Phase 25)
   - What's unclear: What placeholder widgets to render in each tab slot
   - Recommendation: Use simple `Center(child: Text('Tab N'))` placeholders, or reuse existing tab widgets from old settings_panel.dart as-is

## Environment Availability

> No external dependencies needed for this phase.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All | ✓ | 3.44.6 | — |
| Dart SDK | All | ✓ | (bundled) | — |
| Gamepad hardware | LB/RB testing | Unknown | — | Test with keyboard arrow keys first |

**Missing dependencies with no fallback:** none

**Missing dependencies with fallback:**
- Gamepad hardware: keyboard arrow keys provide equivalent tab switching behavior

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK bundled) |
| Config file | none — default flutter test runner |
| Quick run command | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SIDEBAR-01 | Horizontal tab bar with 7 equal-width tabs | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` | ✅ (extend) |
| SIDEBAR-02 | All 7 tabs render with icon + label | widget | `flutter test test/ui/dialogs/settings_nav_item_test.dart` | ❌ Wave 0 |
| SIDEBAR-03 | Click tab switches content with FadeTransition 200ms | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` | ✅ (extend) |
| SIDEBAR-04 | Arrow keys + LB/RB cycle tabs | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` | ✅ (extend) |

### Sampling Rate
- **Per task commit:** `flutter test test/ui/dialogs/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/ui/dialogs/settings_nav_item_test.dart` — covers SIDEBAR-02 (refactored horizontal nav item)
- [ ] Extend `test/ui/dialogs/settings_overlay_shell_test.dart` — covers SIDEBAR-01/03/04 (tab bar + keyboard + gamepad)

## Security Domain

> This phase is UI-only (tab navigation). No authentication, data handling, or cryptographic operations.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |

### Known Threat Patterns for Flutter Desktop UI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| (none applicable) | — | — |

## Sources

### Primary (HIGH confidence)
- Flutter SDK source: `/d/flutter/packages/flutter/lib/src/services/keyboard_key.g.dart` — gamepad key constants verified
- Flutter SDK source: Windows embedder key map — GAMEPAD_LEFT_SHOULDER → gameButton13, GAMEPAD_RIGHT_SHOULDER → gameButton12
- Project source: `lib/ui/dialogs/settings/settings_overlay_shell.dart` (291 lines) — shell skeleton
- Project source: `lib/ui/dialogs/settings/_settings_nav_item.dart` (98 lines) — refactor target
- Project source: `lib/ui/dialogs/settings/settings_panel_state.dart` (36 lines) — selectedTab notifier
- Project source: `lib/ui/dialogs/settings/settings_panel_controller.dart` (68 lines) — controller
- Project source: `lib/ui/theme/tokens.dart` (249 lines) — design tokens (bgSurface NOT present)
- Project source: `lib/ui/dialogs/settings_panel.dart` (945 lines) — old AnimatedSwitcher + sidebar reference

### Secondary (MEDIUM confidence)
- Context7: Flutter IndexedStack documentation
- Context7: Flutter LogicalKeyboardKey gamepad mapping

### Tertiary (LOW confidence)
- WebSearch: Flutter gamepad button mapping (training knowledge, verified against SDK source)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are Flutter SDK built-in or project-local, no new packages
- Architecture: HIGH — clear extension points identified, existing patterns to follow
- Pitfalls: HIGH — bgSurface token gap and gamepad key ID mismatch verified from source

**Research date:** 2026-07-23
**Valid until:** 2026-08-23 (30 days — stable Flutter SDK, project-local components)

---

*Phase: 24-Sidebar Navigation*
*Research completed: 2026-07-23*
