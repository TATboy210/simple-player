# Simple Player Flutter - Accessibility Plan

> WCAG 2.1 AA Compliance Roadmap for Desktop Media Player

**Created:** 2026-07-20
**Status:** Planning
**Target:** WCAG 2.1 Level AA

---

## 1. Executive Summary

### Current Accessibility State

Simple Player Flutter is a desktop media player with **minimal accessibility support**. The codebase has only **3 Semantics widgets** across the entire UI layer, no structured keyboard tab navigation, and no screen reader announcement strategy beyond a single `liveRegion` on the buffering overlay.

### Key Gaps

| Area | Status | Severity |
|------|--------|----------|
| Semantics Labels | 3 of ~50+ interactive widgets labeled | CRITICAL |
| Keyboard Tab Navigation | No Tab/Shift+Tab support | CRITICAL |
| Screen Reader Announcements | 1 liveRegion (buffering only) | HIGH |
| Focus Indicators | No visible focus rings | HIGH |
| Font Scaling | No textScaleFactor handling | HIGH |
| High Contrast Theme | Not supported | MEDIUM |
| Color Contrast | Glass-on-dark may fail AA ratios | MEDIUM |
| Reduced Motion | Partial (progress_bar only) | LOW |

### WCAG 2.1 AA Target

Achieve Level AA compliance across all applicable success criteria for a desktop application, with priority focus on:

1. **Perceivable** - All UI elements have text alternatives; content is presentable in different ways
2. **Operable** - Full keyboard accessibility; users have enough time; content is navigable
3. **Understandable** - Readable; predictable; input assistance
4. **Robust** - Compatible with assistive technologies (NVDA, JAWS, Narrator)

---

## 2. Accessibility Standards

### 2.1 WCAG 2.1 AA Requirements (Applicable to Desktop)

#### Principle 1: Perceivable

| Criterion | Level | Relevance |
|-----------|-------|-----------|
| 1.1.1 Non-text Content | A | All icon buttons need text alternatives |
| 1.3.1 Info and Relationships | A | UI structure must be programmatically determinable |
| 1.3.2 Meaningful Sequence | A | Reading order must be logical |
| 1.4.1 Use of Color | A | Color must not be sole means of conveying info |
| 1.4.3 Contrast (Minimum) | AA | 4.5:1 for text, 3:1 for large text |
| 1.4.4 Resize Text | AA | Text must be resizable up to 200% |
| 1.4.11 Non-text Contrast | AA | 3:1 for UI components and graphical objects |
| 1.4.13 Content on Hover or Focus | AA | Hover/focus content must be dismissible, hoverable, persistent |

#### Principle 2: Operable

| Criterion | Level | Relevance |
|-----------|-------|-----------|
| 2.1.1 Keyboard | A | All functionality available via keyboard |
| 2.1.2 No Keyboard Trap | A | Focus must not get stuck |
| 2.4.1 Bypass Blocks | A | Skip navigation mechanism |
| 2.4.3 Focus Order | A | Logical tab order |
| 2.4.7 Focus Visible | AA | Keyboard focus indicator must be visible |
| 2.5.1 Pointer Gestures | A | Multi-point gestures have single-pointer alternatives |
| 2.5.2 Pointer Cancellation | A | Down-event does not execute action |

#### Principle 3: Understandable

| Criterion | Level | Relevance |
|-----------|-------|-----------|
| 3.2.1 On Focus | A | No context change on focus |
| 3.2.2 On Input | A | No context change on input |
| 3.3.1 Error Identification | A | Errors identified and described |
| 3.3.2 Labels or Instructions | A | Labels for user input |

#### Principle 4: Robust

| Criterion | Level | Relevance |
|-----------|-------|-----------|
| 4.1.2 Name, Role, Value | A | All UI components have accessible name/role/value |

### 2.2 Desktop Application Special Requirements

Desktop Flutter applications have specific accessibility considerations:

- **Screen Reader Integration**: Windows Narrator, NVDA, JAWS via UI Automation (UIA) bridge
- **Platform Semantics**: Flutter's Semantics widget maps to platform accessibility APIs
- **Keyboard Navigation**: Desktop users expect Tab/Shift+Tab, arrow keys, Enter/Space activation
- **System DPI Scaling**: Must respect Windows display scaling (100%, 125%, 150%, 200%)
- **High Contrast Mode**: Windows High Contrast mode detection and support
- **Reduced Motion**: Respect `MediaQuery.disableAnimationsOf`

---

## 3. Current State Analysis

### 3.1 Semantics Labels

**Current Coverage: 3/50+ widgets (6%)**

| Component | Has Semantics | Label Quality |
|-----------|---------------|---------------|
| ProgressBar | Yes | `slider:true`, label + value percentage |
| GlassChip | Yes | `button:true`, `selected`, label |
| PlaybackStatusOverlay | Yes | `liveRegion:true`, opening/buffering label |
| ControlBar | **No** | No container semantics |
| PlayPauseButton | **No** | Tooltip only, no Semantics |
| VolumeButton | **No** | Tooltip only, no Semantics |
| VolumeSlider | **No** | Standard Slider (has implicit) |
| SpeedButton | **No** | No Semantics |
| GlassButton | **No** | Tooltip only (not screen reader accessible) |
| PlaylistPanel | **No** | No container semantics |
| _TabChip | **No** | GestureDetector, not accessible |
| SettingsPanel | **No** | No dialog semantics |
| CustomTitleBar | **No** | No Semantics |

**Key Finding**: GlassButton uses `Tooltip` for visual hints but does NOT wrap in `Semantics`. Screen readers cannot read tooltips -- they need explicit `Semantics(label:)`.

### 3.2 Keyboard Navigation

**Current State: Hotkey-only, no Tab navigation**

- `KeyboardHandler` provides 20+ keyboard shortcuts via `Focus(autofocus: true)`
- Shortcuts are **action-only** (play, pause, seek, volume) -- not navigation
- No Tab/Shift+Tab support between interactive elements
- No arrow key navigation within groups (button bar, playlist)
- `PlaylistPanel` has Escape key handling and focus management
- `SettingsPanel` has Escape key handling
- No visible focus indicators on any widget

**Focus Tree Issues**:
- `Focus(autofocus: true)` on KeyboardHandler captures all focus
- GlassButton uses `InkWell` (implicitly focusable) but no `FocusTraversalGroup`
- PlaylistPanel manages its own `FocusNode` but no traversal policy

### 3.3 Screen Reader Support

**Current State: Minimal**

- `PlaybackStatusOverlay` is the ONLY widget with `liveRegion: true`
- No announcements for: play/pause state changes, volume changes, track changes, errors
- No `Semantics.liveRegion` on state-changing overlays (OSD)
- `OsdService` shows visual OSD pills but has zero screen reader integration

### 3.4 Visual Support

**Current State: Limited**

- **Reduced Motion**: `ProgressBar` checks `MediaQuery.disableAnimationsOf` -- ONLY component
- **Font Scaling**: No component uses `MediaQuery.textScalerOf` or `textScaleFactor`
- **High Contrast**: No detection or support for Windows High Contrast mode
- **Color Contrast**: Glass morphism (semi-transparent backgrounds over video) creates unpredictable contrast ratios
- **Focus Indicators**: No visible focus rings anywhere in the codebase

---

## 4. Semantics Label Plan

### 4.1 Label Specification

All interactive widgets MUST have a Semantics label following this schema:

```
Semantics(
  label: '<action> <context>',     // e.g., "Play video", "Volume slider"
  hint: '<additional guidance>',    // e.g., "Press Enter to play"
  button: true,                     // for buttons
  slider: true,                     // for sliders
  selected: bool,                   // for toggle states
  toggled: bool,                    // for on/off states
  liveRegion: true,                 // for dynamic status
  child: ...
)
```

### 4.2 Component Label Map

#### Control Bar Buttons

| Widget | Semantics Label | Semantics Hint | Role |
|--------|----------------|----------------|------|
| PlayPauseButton (playing) | l10n.pause | "Press Space to pause" | button |
| PlayPauseButton (paused) | l10n.play | "Press Space to play" | button |
| SkipPrevious | l10n.previousTrack | "Press P for previous" | button |
| SkipNext | l10n.nextTrack | "Press N for next" | button |
| Rewind10 | l10n.rewind10 | "Press Left to seek backward" | button |
| Forward30 | l10n.forward30 | "Press Right to seek forward" | button |
| Stop | l10n.stop | — | button |
| VolumeButton (muted) | l10n.unmute | "Press M to unmute" | button |
| VolumeButton (unmuted) | l10n.mute | "Press M to mute" | button |
| VolumeSlider | l10n.volume | Current value as percentage | slider |
| SpeedButton | "Playback speed: {speed}x" | — | button |
| PlayModeButton | l10n.playModeLabel | — | button |
| OpenFile | l10n.openFileTooltip | — | button |
| OpenSubtitle | l10n.openSubtitle | — | button |
| Playlist | l10n.playlist | — | toggle button |
| Settings | l10n.settings | — | button |
| Fullscreen | l10n.fullscreen / l10n.exitFullscreen | — | toggle button |

#### Playlist Panel

| Widget | Semantics Label | Role |
|--------|----------------|------|
| PlaylistPanel | "Playlist panel" | dialog / region |
| _TabChip (folder) | l10n.folderTab, selected state | tab |
| _TabChip (history) | l10n.historyTab, selected state | tab |
| ThumbnailTile | "File name, {index} of {total}" | list item |
| RemoveButton | "Remove {filename}" | button |

#### Settings Panel

| Widget | Semantics Label | Role |
|--------|----------------|------|
| SettingsPanel | l10n.settings | dialog |
| _Sidebar items | Tab name, selected state | tab |
| Apply/OK/Cancel | Respective labels | button |

#### Progress Bar

| Widget | Semantics Label | Role |
|--------|----------------|------|
| ProgressBar | l10n.progressBar | slider |
| Tooltip | Time at hover position | tooltip (excluded from tree) |

#### Title Bar

| Widget | Semantics Label | Role |
|--------|----------------|------|
| PinButton | l10n.pin / l10n.unpin | toggle button |
| MinimizeButton | l10n.minimize | button |
| MaximizeButton | l10n.maximize / l10n.restore | toggle button |
| CloseButton | "Close" | button |

### 4.3 Implementation Approach

#### Pattern 1: Wrap GlassButton with Semantics

The core issue is `GlassButton` relies on `Tooltip` which is NOT exposed to screen readers. Fix by adding Semantics to `GlassButton._buildIconOnly()`:

```dart
Widget _buildIconOnly() {
  // ... existing code ...
  final button = Semantics(
    label: widget.tooltip ?? '',
    button: true,
    enabled: widget.enabled,
    child: Tooltip(
      message: widget.tooltip ?? '',
      // ... existing Tooltip code ...
    ),
  );
  // ... rest of code ...
}
```

#### Pattern 2: Wrap containers with Semantics

For structural regions (ControlBar, PlaylistPanel):

```dart
Semantics(
  label: 'Player controls',
  container: true,
  child: Column(
    children: [...],
  ),
)
```

#### Pattern 3: Dynamic labels for stateful widgets

For buttons that change state (Play/Pause, Mute/Unmute):

```dart
Semantics(
  label: playing ? l10n.pause : l10n.play,
  button: true,
  child: IconButton(...),
)
```

### 4.4 Testing Semantics Labels

Use Flutter's semantic testing utilities:

```dart
// Widget test
testWidgets('play button has correct semantics', (tester) async {
  await tester.pumpWidget(createPlayer());
  final playButton = find.bySemanticsLabel('Play');
  expect(playButton, findsOneWidget);
});

// Semantics tree inspection
final semantics = tester.getSemantics(find.byType(PlayPauseButton));
expect(semantics.label, 'Play');
expect(semantics.hasFlag(SemanticsFlag.isButton), true);
```

Automated tool: `flutter test --accessibility` flag generates semantic tree reports.

---

## 5. Keyboard Navigation Plan

### 5.1 Shortcut Design

**Current shortcuts are preserved.** New navigation shortcuts are added:

| Key | Context | Action |
|-----|---------|--------|
| Tab | Global | Move focus to next interactive element |
| Shift+Tab | Global | Move focus to previous interactive element |
| Enter/Space | Focused button | Activate button |
| Left/Right | Focused slider | Adjust value |
| Escape | Playlist/Settings open | Close panel/dialog |
| Arrow keys | Playlist items | Navigate between items |
| Home/End | Progress bar | Jump to start/end |

### 5.2 Tab Order

The Tab order follows the visual layout, top-to-bottom, left-to-right:

```
1. Title Bar: Pin → Minimize → Maximize → Close
2. (Video area - not focusable by default)
3. Control Bar Row 1: Title text (read-only)
4. Control Bar Row 2: ProgressBar
5. Control Bar Row 3 Left: PlayMode → VolumeButton → VolumeSlider → SpeedButton
6. Control Bar Row 3 Center: Previous → Rewind → Play/Pause → Forward → Next → Stop
7. Control Bar Row 3 Right: OpenFile → OpenSubtitle → Playlist → Settings → Fullscreen
8. Playlist Panel (when open): Tab bar → content list
9. Settings Dialog (when open): Sidebar tabs → content area → OK/Cancel/Apply
```

### 5.3 Focus Management Strategy

#### FocusTraversalGroup Strategy

Wrap logical groups in `FocusTraversalGroup` with `OrderedTraversalPolicy`:

```dart
// Control bar gets its own traversal group
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: ControlBar(...),
)

// Playlist panel gets its own traversal group
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: PlaylistPanel(...),
)
```

#### Focus Indicator Design

All focusable elements MUST show a visible focus ring:

```dart
Focus(
  child: Builder(
    builder: (context) {
      final focused = Focus.of(context).hasFocus;
      return Container(
        decoration: focused
            ? BoxDecoration(
                border: Border.all(
                  color: Tokens.accent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(Tokens.radiusBtn),
              )
            : null,
        child: existingChild,
      );
    },
  ),
)
```

Focus ring style:
- Color: `Tokens.accent` (blue) -- meets 3:1 contrast against both light and dark backgrounds
- Width: 2px
- Offset: 2px from element boundary
- Style: solid outline with 2px gap (outline-style focus ring)

#### Focus Trap Prevention

- `KeyboardHandler` must NOT capture Tab key
- `PlaylistPanel` Escape returns focus to playlist toggle button
- `SettingsPanel` Escape returns focus to settings button
- Modal dialogs trap focus within the dialog (standard behavior)

### 5.4 Arrow Key Navigation in Groups

Button groups (CenterGroup, LeftButtonGroup, RightButtonGroup) support arrow key navigation:

```dart
FocusTraversalGroup(
  policy: WidgetOrderTraversalPolicy(),
  child: Row(
    children: [
      _FocusableButton(...),  // Left arrow → previous, Right arrow → next
      _FocusableButton(...),
      _FocusableButton(...),
    ],
  ),
)
```

Playlist items support vertical arrow navigation:

```dart
ListView.builder(
  // ...
  itemBuilder: (context, index) => Focus(
    onKeyEvent: (node, event) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Move focus to next item
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Move focus to previous item
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: ThumbnailTile(...),
  ),
)
```

---

## 6. Screen Reader Plan

### 6.1 Announcement Strategy

#### Live Regions for State Changes

Add `Semantics(liveRegion: true)` to widgets that display dynamic state:

| State Change | Announcement | Widget |
|-------------|--------------|--------|
| Play/Pause | "Playing" / "Paused" | PlayPauseButton or OSD |
| Track Change | "Now playing: {filename}" | OSD or ControlBar title |
| Volume Change | "Volume {percentage}%" | VolumeButton/Slider |
| Mute/Unmute | "Muted" / "Unmuted" | VolumeButton |
| Speed Change | "Speed {rate}x" | SpeedButton |
| Buffering | "Buffering" | PlaybackStatusOverlay (existing) |
| Error | "Error: {message}" | Error overlay |
| Subtitle Toggle | "Subtitles on" / "Subtitles off" | OSD |

#### Implementation: Announcement Service

Create a dedicated service for screen reader announcements:

```dart
/// Centralized screen reader announcement service.
///
/// Uses SemanticsService.announce to send messages to the platform
/// screen reader. Buries announcements to avoid flooding (debounce).
class AnnouncementService {
  static final instance = AnnouncementService._();
  AnnouncementService._();

  Timer? _debounce;
  String? _pendingAnnouncement;

  /// Announce a message to the screen reader.
  /// Debounces rapid changes (e.g., volume slider drag) to 500ms.
  void announce(BuildContext context, String message) {
    _pendingAnnouncement = message;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () {
        final msg = _pendingAnnouncement;
        if (msg != null) {
          SemanticsService.announce(
            msg,
            TextDirection.ltr,  // or from Localizations
          );
          _pendingAnnouncement = null;
        }
      },
    );
  }

  /// Immediate announcement (no debounce) for critical messages.
  void announceImmediate(BuildContext context, String message) {
    _debounce?.cancel();
    _pendingAnnouncement = null;
    SemanticsService.announce(message, TextDirection.ltr);
  }
}
```

#### Integration Points

```dart
// In PlayPauseButton
onPressed: () {
  engine.togglePlayPause();
  final state = engine.state.value;
  AnnouncementService.instance.announce(
    context,
    state == MediaState.playing ? l10n.pause : l10n.play,
  );
}

// In VolumeSlider._onChangedEnd
void _onChangedEnd(double v) {
  // ... existing code ...
  AnnouncementService.instance.announce(
    context,
    '${l10n.volume} ${(v * 100).round()}%',
  );
}
```

### 6.2 Interaction Feedback

Every user action MUST provide feedback through at least one channel:

| Action | Visual Feedback | Screen Reader Feedback | Haptic |
|--------|----------------|----------------------|--------|
| Button press | Scale animation | Label announced | N/A (desktop) |
| Slider drag | Value update | Debounced value | N/A |
| Toggle state | Icon/color change | State announced | N/A |
| Error | Error overlay | Error message | N/A |
| Loading | Spinner | "Loading" live region | N/A |

### 6.3 Error Handling Accessibility

Error states must be accessible:

```dart
Semantics(
  label: l10n.errorLoadingFile,
  liveRegion: true,
  child: ErrorWidget(
    message: errorMessage,
    onRetry: () => engine.retry(),
  ),
)
```

---

## 7. Visual Support Plan

### 7.1 High Contrast Theme

#### Detection

```dart
/// Detect Windows High Contrast mode via MediaQuery.
bool isHighContrast(BuildContext context) {
  return MediaQuery.highContrastOf(context);
}
```

#### High Contrast Token Overrides

When high contrast is detected, override glass tokens with solid colors:

```dart
class HighContrastTokens {
  // Replace glass backgrounds with solid opaque colors
  static const bgGlass = Color(0xFF000000);
  static const bgHover = Color(0xFF333333);
  static const borderHighlight = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFCCCCCC);
  static const accent = Color(0xFF6CB4FF);  // Bright blue, passes AA on black
  static const progressPlayed = Color(0xFF6CB4FF);
  static const progressBuffer = Color(0xFF666666);
}
```

#### Token Selection Helper

```dart
/// Returns appropriate token value based on contrast mode.
T contrastAware<T>(BuildContext context, T normal, T highContrast) {
  return MediaQuery.highContrastOf(context) ? highContrast : normal;
}

// Usage in widgets
final bgColor = contrastAware(context, Tokens.bgGlass, HighContrastTokens.bgGlass);
```

### 7.2 Font Scaling Support

#### Current Issue

All font sizes are hardcoded via `Tokens.fontBody`, `Tokens.fontCaption`, etc. When the user scales text in Windows settings, the app does not respond.

#### Solution: Use MediaQuery.textScalerOf

```dart
// Replace hardcoded font sizes with scaled values
final textScaler = MediaQuery.textScalerOf(context);
final scaledFontSize = textScaler.scale(Tokens.fontBody);

// In Text widgets
Text(
  'Hello',
  style: TextStyle(
    fontSize: MediaQuery.textScalerOf(context).scale(Tokens.fontBody),
  ),
)
```

#### Layout Accommodation

Scaled text may overflow containers. Handle this with:

1. **Flexible/Expanded** wrappers for text in rows
2. **maxLines + overflow: TextOverflow.ellipsis** for constrained spaces
3. **Minimum touch target**: 48x48dp even when text is small (WCAG 2.5.5)

```dart
// Ensure minimum tap target
ConstrainedBox(
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  child: Center(child: Text(label)),
)
```

### 7.3 Color Contrast Compliance

#### Problem: Glass Morphism

Glass backgrounds (`bgGlass` = `Color(0x1AFFFFFF)`) over video create unpredictable contrast ratios. The actual contrast depends on the video content behind the glass.

#### Solution: Ensure Minimum Contrast

1. **Text on glass**: Add a solid text shadow or ensure the glass tint is sufficient
2. **Icon buttons**: Use `Tokens.textPrimary` (#FFFFFF) on dark glass -- passes AA on most backgrounds
3. **Disabled states**: Ensure disabled text still meets 3:1 ratio (WCAG 1.4.11)

#### Contrast Audit Checklist

| Element | Foreground | Background | Required Ratio | Action |
|---------|-----------|------------|----------------|--------|
| Body text | textPrimary (#FFF) | bgGlass (over dark video) | 4.5:1 | Verify with glass overlay |
| Caption text | textSecondary (#AAA) | bgGlass | 4.5:1 | May need brightening |
| Accent text | accent (#4A9EFF) | bgGlass | 4.5:1 | Verify |
| Disabled text | textDisabled | bgGlass | 3:1 | Verify |
| Progress played | accent (#4A9EFF) | bgHover | 3:1 | Verify |
| Focus ring | accent | bgGlass | 3:1 | Verify |

### 7.4 Reduced Motion Support

Extend the current partial support (ProgressBar only) to all animated widgets:

```dart
/// Helper to check reduced motion preference.
bool prefersReducedMotion(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context);
}

// In animated widgets
final duration = prefersReducedMotion(context)
    ? Duration.zero
    : const Duration(milliseconds: Tokens.durationSlide);
```

Components to update:
- `PlaylistPanel` slide/fade animation
- `ControlsOverlay` fade animation
- `GlassButton` scale animation
- `SpeedButton` popup animation
- `OsdOverlay` fade animation
- `PlaylistPanel._TabChip` color transition

---

## 8. Component-Level Accessibility Implementation

### 8.1 Control Bar

#### Current Issues
- No Semantics container wrapper
- No tab navigation between button groups
- No focus indicators on buttons

#### Implementation

```dart
// Wrap entire ControlBar in Semantics
Semantics(
  label: l10n.playerControls,
  container: true,
  child: FocusTraversalGroup(
    child: Column(
      children: [
        // Row 1: Title + Time (read-only, exclude from traversal)
        ExcludeFromTraversal(
          child: Row(children: [title, TimeRangeDisplay]),
        ),
        // Row 2: ProgressBar (focusable slider)
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: ProgressBar(engine: engine),
        ),
        // Row 3: Button groups
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: Row(children: [
            LeftButtonGroup(...),
            CenterGroup(...),
            RightButtonGroup(...),
          ]),
        ),
      ],
    ),
  ),
)
```

### 8.2 GlassButton (Core Fix)

The most impactful single change: add Semantics to `GlassButton._buildIconOnly()`:

```dart
Widget _buildIconOnly() {
  final effectiveColor = widget.color ?? ...;
  final content = widget.child ?? Icon(widget.icon, size: widget.iconSize, color: effectiveColor);

  final button = Semantics(
    label: widget.tooltip ?? widget.label ?? '',
    button: true,
    enabled: widget.enabled,
    child: Tooltip(
      message: widget.tooltip ?? '',
      waitDuration: const Duration(milliseconds: Tokens.tooltipDelayShort),
      child: SizedBox(
        width: 48,  // Minimum touch target (WCAG 2.5.5)
        height: 48, // Minimum touch target
        child: Material(
          color: Colors.transparent,
          borderRadius: GlassButton._radiusBtn,
          child: InkWell(
            onTap: widget.enabled ? widget.onPressed : null,
            // ... rest of existing code ...
          ),
        ),
      ),
    ),
  );

  return MouseRegion(
    cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
    onEnter: (_) => _onHoverChanged(true),
    onExit: (_) => _onHoverChanged(false),
    child: ScaleTransition(scale: _scaleAnim, child: button),
  );
}
```

Key changes:
1. Wrap with `Semantics(label:, button:, enabled:)`
2. Increase minimum size to 48x48dp (WCAG 2.5.5 target size)

### 8.3 Playlist Panel

#### Current Issues
- `_TabChip` uses `GestureDetector` -- not keyboard focusable
- No Semantics on panel, tabs, or list items
- No arrow key navigation in list

#### Implementation

```dart
// _TabChip: Replace GestureDetector with InkWell + Semantics
class _TabChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusBtn),
        focusColor: Tokens.bgHover,
        child: Container(
          // ... existing decoration ...
          child: Row(
            children: [
              Icon(icon, size: 14, color: selected ? Tokens.accent : Tokens.textDisabled),
              const SizedBox(width: 4),
              Text(label, style: ...),
            ],
          ),
        ),
      ),
    );
  }
}

// PlaylistPanel: Add Semantics container
Semantics(
  label: l10n.playlist,
  container: true,
  explicitChildNodes: true,
  child: Focus(
    focusNode: _focusNode,
    onKeyEvent: _handleKey,
    child: _buildPanel(width, height),
  ),
)
```

### 8.4 Progress Bar

#### Current State: Partially Accessible

Already has `Semantics(slider: true, label:, value:)`. Improvements needed:

```dart
// Add increasedValue/decreasedValue for keyboard arrow support
Semantics(
  label: l10n.progressBar,
  value: '${(_effectiveFraction * 100).round()}%',
  slider: true,
  increasedValue: '+5 seconds',  // Right arrow hint
  decreasedValue: '-5 seconds',  // Left arrow hint
  onIncrease: () => engine.skipForward(5000),
  onDecrease: () => engine.skipBack(5000),
  child: GestureDetector(...),
)
```

### 8.5 Settings Dialog

#### Implementation

```dart
Semantics(
  label: l10n.settings,
  scopesRoute: true,  // Announce as dialog
  explicitChildNodes: true,
  child: Focus(
    onKeyEvent: _handleEscape,
    child: Dialog(
      child: Column(
        children: [
          // Sidebar with tab semantics
          Semantics(
            label: 'Settings navigation',
            child: _Sidebar(
              selectedIndex: _selectedIndex,
              onChanged: _onTabChanged,
            ),
          ),
          // Tab content
          Expanded(child: _buildTab(_selectedIndex)),
          // Action buttons
          Row(children: [
            Semantics(button: true, child: TextButton(onPressed: _onCancel, child: Text(l10n.cancel))),
            Semantics(button: true, child: TextButton(onPressed: _onApply, child: Text(l10n.apply))),
          ]),
        ],
      ),
    ),
  ),
)
```

### 8.6 Custom Title Bar

#### Implementation

```dart
Semantics(
  label: l10n.windowControls,
  container: true,
  child: Row(
    children: [
      Semantics(
        label: isPinned ? l10n.unpin : l10n.pin,
        button: true,
        toggled: isPinned,
        child: IconButton(...),
      ),
      Semantics(label: l10n.minimize, button: true, child: IconButton(...)),
      Semantics(
        label: isMaximized ? l10n.restore : l10n.maximize,
        button: true,
        toggled: isMaximized,
        child: IconButton(...),
      ),
      Semantics(label: 'Close', button: true, child: IconButton(...)),
    ],
  ),
)
```

---

## 9. Testing Strategy

### 9.1 Automated Testing

#### Semantics Unit Tests

```dart
group('Accessibility Semantics', () {
  testWidgets('all control bar buttons have semantics labels', (tester) async {
    await tester.pumpWidget(createPlayer());

    // Verify each button has a label
    expect(find.bySemanticsLabel(l10n.play), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.previousTrack), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.nextTrack), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.rewind10), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.forward30), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.stop), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.mute), findsOneWidget);
  });

  testWidgets('progress bar has slider semantics', (tester) async {
    await tester.pumpWidget(createPlayer());
    final semantics = tester.getSemantics(find.byType(ProgressBar));
    expect(semantics.label, l10n.progressBar);
    expect(semantics.hasFlag(SemanticsFlag.isSlider), true);
  });

  testWidgets('playlist panel tabs have correct semantics', (tester) async {
    await tester.pumpWidget(createPlayerWithPlaylist());
    final folderTab = find.bySemanticsLabel(l10n.folderTab);
    expect(folderTab, findsOneWidget);
  });
});
```

#### Keyboard Navigation Tests

```dart
group('Keyboard Navigation', () {
  testWidgets('Tab moves focus between control groups', (tester) async {
    await tester.pumpWidget(createPlayer());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // Verify focus moved to first interactive element
    expect(tester.binding.focusManager.primaryFocus, isNotNull);
  });

  testWidgets('Escape closes playlist panel', (tester) async {
    await tester.pumpWidget(createPlayerWithPlaylist());
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    // Verify playlist is closed
  });

  testWidgets('Enter activates focused button', (tester) async {
    await tester.pumpWidget(createPlayer());
    // Focus play button
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Verify play state changed
  });
});
```

#### Contrast Ratio Tests

```dart
group('Color Contrast', () {
  testWidgets('text on glass meets AA contrast', (tester) async {
    await tester.pumpWidget(createPlayer());
    // Use Flutter_test contrast checker or manual calculation
    // textPrimary (#FFFFFF) on bgGlass overlay must >= 4.5:1
  });
});
```

### 9.2 Manual Testing

#### Screen Reader Test Matrix

| Test Case | NVDA | Narrator | JAWS |
|-----------|------|----------|------|
| Navigate to play button, hear label | | | |
| Press play, hear "Playing" announcement | | | |
| Tab through all control bar buttons | | | |
| Navigate playlist items with arrow keys | | | |
| Open settings dialog, hear dialog announcement | | | |
| Adjust volume slider, hear percentage | | | |
| Receive error, hear error message | | | |
| Receive buffering notification | | | |

#### Keyboard-Only Test Matrix

| Test Case | Pass/Fail |
|-----------|-----------|
| Tab to every interactive element | |
| Shift+Tab reverses order | |
| Enter/Space activates buttons | |
| Arrow keys adjust sliders | |
| Escape closes dialogs/panels | |
| Focus indicator visible on every element | |
| No keyboard traps | |
| Focus returns to trigger after dialog close | |

#### Visual Test Matrix

| Test Case | 100% | 150% | 200% |
|-----------|------|------|------|
| All text readable | | | |
| No text overflow/clipping | | | |
| Minimum 48dp touch targets | | | |
| Focus rings visible | | | |
| High contrast mode works | | | |

---

## 10. Implementation Roadmap

### Phase 1: Foundation (Week 1-2) -- CRITICAL

**Goal**: Basic screen reader and keyboard support

| Task | Priority | Effort |
|------|----------|--------|
| Add Semantics to GlassButton (core fix) | P0 | 2h |
| Add Semantics to all control bar buttons | P0 | 3h |
| Add Semantics to playlist tabs and items | P0 | 3h |
| Add Semantics to settings dialog | P0 | 2h |
| Add Semantics to title bar buttons | P0 | 1h |
| Add FocusTraversalGroup to control bar | P0 | 2h |
| Add FocusTraversalGroup to playlist panel | P0 | 2h |
| Add visible focus indicators | P0 | 4h |
| Add AnnouncementService for state changes | P0 | 3h |
| Wire AnnouncementService to play/pause/mute/track | P0 | 2h |
| Add l10n entries for new Semantics labels | P0 | 2h |
| Write Semantics widget tests | P0 | 4h |

**Total Phase 1**: ~30 hours

**Deliverables**:
- All interactive widgets have Semantics labels
- Tab/Shift+Tab navigation works across all UI
- Screen reader announces state changes
- Focus indicators visible on all focusable elements

### Phase 2: Enhanced Navigation (Week 3-4) -- HIGH

**Goal**: Full keyboard navigation and arrow key support

| Task | Priority | Effort |
|------|----------|--------|
| Arrow key navigation in button groups | P1 | 3h |
| Arrow key navigation in playlist list | P1 | 4h |
| Home/End support in progress bar | P1 | 2h |
| Focus trap in dialogs (Settings, MediaInfo) | P1 | 2h |
| Focus return after dialog/panel close | P1 | 2h |
| Progress bar keyboard seek (Left/Right) | P1 | 2h |
| Volume slider keyboard adjustment | P1 | 1h |
| Tab chip keyboard activation | P1 | 1h |
| Write keyboard navigation tests | P1 | 4h |

**Total Phase 2**: ~21 hours

**Deliverables**:
- Full keyboard-only operation possible
- Arrow keys navigate within groups
- Dialog focus trapping works correctly
- Focus management follows WAI-ARIA dialog pattern

### Phase 3: Visual Accessibility (Week 5-6) -- MEDIUM

**Goal**: High contrast, font scaling, reduced motion

| Task | Priority | Effort |
|------|----------|--------|
| High contrast theme detection | P2 | 2h |
| High contrast token overrides | P2 | 3h |
| Font scaling support (textScalerOf) | P2 | 4h |
| Layout accommodation for scaled text | P2 | 3h |
| Extended reduced motion support | P2 | 3h |
| Color contrast audit and fixes | P2 | 3h |
| Minimum touch target enforcement (48dp) | P2 | 2h |
| Manual screen reader testing (NVDA) | P2 | 4h |
| Manual screen reader testing (Narrator) | P2 | 4h |
| Documentation and final audit | P2 | 2h |

**Total Phase 3**: ~30 hours

**Deliverables**:
- High contrast mode supported
- Text scales to 200% without layout breakage
- All animations respect reduced motion
- Color contrast ratios verified and documented
- Full manual testing completed

---

## 11. WCAG 2.1 AA Compliance Checklist

### Principle 1: Perceivable

- [ ] **1.1.1 Non-text Content** -- All icon buttons have Semantics labels
- [ ] **1.3.1 Info and Relationships** -- UI structure exposed via Semantics tree
- [ ] **1.3.2 Meaningful Sequence** -- Tab order matches visual layout
- [ ] **1.4.1 Use of Color** -- Play/pause state uses icon change, not just color
- [ ] **1.4.3 Contrast (Minimum)** -- Text meets 4.5:1, large text meets 3:1
- [ ] **1.4.4 Resize Text** -- Text scales to 200% via system settings
- [ ] **1.4.11 Non-text Contrast** -- UI components meet 3:1
- [ ] **1.4.13 Content on Hover/Focus** -- Tooltips are dismissible (Esc), hoverable, persistent

### Principle 2: Operable

- [ ] **2.1.1 Keyboard** -- All functionality available via keyboard
- [ ] **2.1.2 No Keyboard Trap** -- No focus traps; Escape always works
- [ ] **2.4.1 Bypass Blocks** -- Skip to video area shortcut (future)
- [ ] **2.4.3 Focus Order** -- Logical Tab order verified
- [ ] **2.4.7 Focus Visible** -- Focus ring visible on all focusable elements
- [ ] **2.5.1 Pointer Gestures** -- All gestures have keyboard alternatives
- [ ] **2.5.2 Pointer Cancellation** -- Actions on up-event (InkWell default)

### Principle 3: Understandable

- [ ] **3.2.1 On Focus** -- No unexpected context changes on focus
- [ ] **3.2.2 On Input** -- No unexpected context changes on input
- [ ] **3.3.1 Error Identification** -- Errors announced to screen readers
- [ ] **3.3.2 Labels or Instructions** -- All inputs labeled

### Principle 4: Robust

- [ ] **4.1.2 Name, Role, Value** -- All components have accessible name/role/value
- [ ] **Screen Reader Testing** -- Verified with NVDA, Narrator, JAWS
- [ ] **Automated Testing** -- Semantics tests pass

---

## 12. New L10n Entries Required

The following entries must be added to `app_en.arb` and `app_zh.arb`:

```json
{
  "playerControls": "Player controls",
  "@playerControls": { "description": "Semantics label for the control bar container" },

  "windowControls": "Window controls",
  "@windowControls": { "description": "Semantics label for the title bar buttons" },

  "playbackSpeed": "Playback speed: {speed}x",
  "@playbackSpeed": { "description": "Semantics label for speed button with current rate" },

  "nowPlaying": "Now playing: {title}",
  "@nowPlaying": { "description": "Announcement when track changes" },

  "playing": "Playing",
  "@playing": { "description": "Announcement when playback starts" },

  "paused": "Paused",
  "@paused": { "description": "Announcement when playback pauses" },

  "volumeAnnouncement": "Volume {percent}%",
  "@volumeAnnouncement": { "description": "Announcement when volume changes" },

  "subtitleOn": "Subtitles on",
  "@subtitleOn": { "description": "Announcement when subtitles enabled" },

  "subtitleOff": "Subtitles off",
  "@subtitleOff": { "description": "Announcement when subtitles disabled" },

  "errorAnnouncement": "Error: {message}",
  "@errorAnnouncement": { "description": "Announcement for error states" },

  "seekToPosition": "Seek to {time}",
  "@seekToPosition": { "description": "Announcement when seeking to a position" }
}
```

---

## 13. Dependencies and Risks

### Dependencies

| Dependency | Impact | Mitigation |
|------------|--------|------------|
| Flutter Semantics → UIA bridge | Screen reader support relies on Flutter's platform bridge | Test with real screen readers, not just semantic tree |
| Windows High Contrast API | Theme detection | Use `MediaQuery.highContrastOf` (Flutter built-in) |
| fvp Texture rendering | Video area has no Semantics | Add "Video" label to Texture widget |

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Glass morphism breaks contrast ratios | High | High | Provide high contrast fallback theme |
| Flutter Semantics bridge limitations on Windows | Medium | High | Test with NVDA early, file Flutter issues if needed |
| Tab order conflicts with KeyboardHandler | Medium | Medium | Exclude Tab from shortcut handler |
| Performance impact of additional Semantics nodes | Low | Low | Semantics are pruned in release mode |

---

## 14. References

- [WCAG 2.1 Guidelines](https://www.w3.org/TR/WCAG21/)
- [Flutter Accessibility Documentation](https://docs.flutter.dev/accessibility-and-localization/accessibility)
- [WAI-ARIA Practices](https://www.w3.org/WAI/ARIA/apg/)
- [Windows Accessibility](https://learn.microsoft.com/en-us/windows/win32/winauto/microsoft-active-accessibility)
- [NVDA Screen Reader](https://www.nvaccess.org/)
- [Flutter Semantics API](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
