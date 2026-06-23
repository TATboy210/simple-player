# Phase 16: Performance Foundation — Research

**Researched:** 2026-06-22
**Domain:** Flutter rendering performance — RepaintBoundary, BackdropFilter, Paint caching
**Confidence:** HIGH

## Summary

Phase 16 targets three specific rendering performance improvements: (1) audit and add RepaintBoundary to independent repaint regions, (2) skip BackdropFilter during window resize, and (3) cache Paint objects as static final in CustomPainter subclasses.

Key finding: **All four target widgets (ControlBar, VideoSurface, AuroraBackground, ProgressBar) already have RepaintBoundary wrapping.** The audit reveals the codebase is well-optimized in this regard. The remaining work is confirming no gaps exist and potentially adding RepaintBoundary to a few secondary widgets (OsdOverlay already has it, ErrorBanner already has it, ThumbnailTile already has it).

For BackdropFilter resize degradation, the infrastructure gap is significant: there is no resize signal propagating from WindowService to the widget tree. AutoHideController has a `_resizing` field but it's never set from outside — it's a dead code path. The BackdropFilter in GlassContainer, ControlBar, and PlaylistPanel has no resize awareness.

For Paint caching, `_BarPainter` is already fully static. `_AuroraPainter` creates 4 temporary Paint objects per frame (3× `drawImage` + 1× `drawRect` background) that should be static final.

**Primary recommendation:** Focus effort on PERF-06 (resize degradation) as it has the highest impact and requires new infrastructure. PERF-05 is mostly already done. PERF-07 is a quick win.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PERF-05 | RepaintBoundary audit — ControlBar, VideoSurface, AuroraBackground, ProgressBar | All 4 widgets already wrapped. Audit confirms completeness. Minor secondary widgets reviewed. |
| PERF-06 | BackdropFilter resize degradation — skip all BackdropFilter during isResizing | 3 BackdropFilter sites found (GlassContainer, ControlBar, PlaylistPanel). No resize signal exists yet. Requires new ValueNotifier in WindowBridge + propagation. |
| PERF-07 | Static Paint cache — CustomPainter Paint objects as static final | _BarPainter already static (4 paints). _AuroraPainter has 4 per-frame allocations to fix. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| RepaintBoundary placement | Widget (UI) | — | Each widget owns its own repaint boundary |
| Resize signal propagation | Bridge (WindowService) | Widget (GlassContainer, ControlBar) | WindowService detects resize, widgets consume signal |
| Paint object lifecycle | Widget (CustomPainter) | — | Paint is owned by the painter class |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/rendering | SDK | RepaintBoundary, BackdropFilter, CustomPainter | Built-in, no external dependency needed |

No new packages required for this phase.

## Package Legitimacy Audit

No new packages to install. This section is N/A.

## Architecture Patterns

### Pattern 1: RepaintBoundary Isolation

**What:** Wrap independent repaint regions in RepaintBoundary to prevent parent repaints from cascading into expensive child subtrees.

**When to use:** When a subtree contains a CustomPainter, Texture, or BackdropFilter that should not repaint when sibling content changes.

**Current state in codebase:**

```
PlayerScreen
├── VideoSurface          → RepaintBoundary ✓ (video_surface.dart:26)
├── ControlsOverlay       → RepaintBoundary ✓ (controls_overlay.dart:158)
│   ├── OsdOverlay        → RepaintBoundary ✓ (osd_overlay.dart:80)
│   ├── ControlBar        → RepaintBoundary ✓ (control_bar.dart:121)
│   └── ErrorBanner       → RepaintBoundary ✓ (controls_overlay.dart:204)
├── AuroraBackground      → RepaintBoundary ✓ (aurora_background.dart:229)
├── ProgressBar._buildBarLayers → RepaintBoundary ✓ (progress_bar.dart:180)
├── PlaylistPanel         → RepaintBoundary ✓ (playlist_panel.dart:178)
│   └── ThumbnailTile     → RepaintBoundary ✓ (folder_tab.dart:165, history_tab.dart:119)
├── EmptyState content    → RepaintBoundary ✓ (empty_state.dart:138)
└── GlassContainer        → RepaintBoundary ✓ (glass_container.dart:81, 85)
```

**Conclusion:** All critical repaint regions already have RepaintBoundary. No additions needed for PERF-05.

### Pattern 2: BackdropFilter Resize Degradation

**What:** Disable BackdropFilter blur during window resize to eliminate GPU readback stalls.

**Current state:**
- `GlassContainer` has `blurEnabled` parameter (D-14) — can disable blur
- `ControlBar` has `enableBlur` parameter — can disable blur
- `PlaylistPanel` has no blur disable mechanism — hardcoded BackdropFilter
- `AutoHideController` has `_resizing` field (line 38) and `set resizing` (line 94) — but this is **never called from outside**, dead code path

**Gap:** No resize signal propagates from WindowService to widgets.

**Recommended approach:**

1. Add `ValueNotifier<bool> isResizing` to `WindowBridge` interface
2. In `WindowService.onWindowResize()`, set `isResizing.value = true` immediately, debounce to `false` after resize ends
3. In `GlassContainer`, add optional `ValueListenable<bool>? resizing` parameter — when true, skip BackdropFilter
4. In `ControlBar`, pass resizing signal to skip BackdropFilter
5. In `PlaylistPanel`, add resizing check before BackdropFilter
6. Wire signals through `PlayerScreen` → `ControlsOverlay` → `ControlBar`

**Key implementation detail:** The resize signal must be set synchronously in `onWindowResize()` (not debounced) to catch the first resize frame. The debounce is only for clearing the flag after resize ends.

### Pattern 3: Static Paint Cache

**What:** Declare Paint objects as `static final` fields on CustomPainter subclasses to avoid per-frame allocation.

**Current state:**

| Painter | File | Static Paints | Per-frame Paints |
|---------|------|--------------|-----------------|
| `_BarPainter` | progress_bar.dart:245-248 | 4 (bgPaint, bufPaint, playedPaint, thumbPaint) | 0 — fully optimized |
| `_AuroraPainter` | aurora_background.dart:287,316 | 0 | 4 (1× bgBase drawRect, 3× drawImage default Paint) |

**_AuroraPainter fix:**
```dart
// Add as static fields on _AuroraPainter:
static final _bgPaint = Paint()..color = Tokens.bgBase;
static final _compositePaint = Paint(); // default compositing for drawImage
```

Then replace:
- Line 287: `Paint()..color = Tokens.bgBase` → `_bgPaint`
- Line 316: `Paint()` → `_compositePaint` (3 occurrences in the loop)

**Risk:** Very low. Paint objects with fixed properties are safe to share across frames. The `drawImage` Paint is just a default compositing paint — no state mutation.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Resize detection | Custom WM_SIZING listener | WindowService.onWindowResize() + debounced ValueNotifier | Already has the hook, just needs signal propagation |

## Common Pitfalls

### Pitfall 1: RepaintBoundary Overuse
**What goes wrong:** Adding RepaintBoundary to every widget creates overhead (each boundary allocates a separate compositing layer).
**Why it happens:** "More boundaries = better performance" misconception.
**How to avoid:** Only add to subtrees that genuinely benefit: CustomPainter, Texture, BackdropFilter, or large static subtrees.
**Warning signs:** Increased memory usage, no measurable FPS improvement.

### Pitfall 2: Resize Signal Race
**What goes wrong:** BackdropFilter disabled but not re-enabled after resize ends.
**Why it happens:** Debounce timer cancelled or not fired.
**How to avoid:** Ensure the `isResizing` notifier is set to `false` in a reliable cleanup path (not just debounce — also handle window close, fullscreen transition).
**Warning signs:** Blur permanently disabled after resize.

### Pitfall 3: GlassContainer blurEnabled vs resizing conflict
**What goes wrong:** `blurEnabled` (hardware degradation) and `resizing` (temporary degradation) interact unexpectedly.
**Why it happens:** Both disable BackdropFilter but for different reasons.
**How to avoid:** `GlassContainer` should skip BackdropFilter if EITHER `!blurEnabled` OR `resizing?.value == true`. These are independent OR conditions, not conflicting.

## Code Examples

### Resize Signal in WindowService

```dart
// In WindowBridge abstract class:
ValueNotifier<bool> get isResizing;

// In WindowService:
final ValueNotifier<bool> isResizing = ValueNotifier(false);
Timer? _resizeEndTimer;

@override
void onWindowResize() {
  if (_disposed || _isAnimating) return;
  isResizing.value = true;  // Immediate — catch first frame
  _resizeEndTimer?.cancel();
  _resizeEndTimer = Timer(const Duration(milliseconds: 200), () {
    if (!_disposed) isResizing.value = false;
  });
  // Existing debounce for windowSize...
  _resizeDebounce?.cancel();
  _resizeDebounce = Timer(const Duration(milliseconds: _durationWindowResize), () {
    if (_disposed) return;
    windowManager.getSize().then((size) {
      if (size != windowSize.value) _safeSet(windowSize, size);
    });
  });
}
```

### GlassContainer with Resize Awareness

```dart
class GlassContainer extends StatelessWidget {
  // ... existing fields ...
  final ValueListenable<bool>? resizing;

  @override
  Widget build(BuildContext context) {
    // ...
    if (!blurEnabled) {
      return ClipRRect(borderRadius: rRect, child: RepaintBoundary(child: content));
    }

    final shouldBlur = resizing == null || !resizing!.value;
    if (!shouldBlur) {
      return ClipRRect(borderRadius: rRect, child: RepaintBoundary(child: content));
    }

    // ... existing BackdropFilter logic ...
  }
}
```

### Static Paint Cache in _AuroraPainter

```dart
class _AuroraPainter extends CustomPainter {
  // Add static paints:
  static final _bgPaint = Paint()..color = Tokens.bgBase;
  static final _compositePaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _bgPaint);  // was: Paint()..color = Tokens.bgBase
    // ...
    canvas.drawImage(img, Offset(...), _compositePaint);  // was: Paint()
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-frame Paint allocation | Static final Paint | Already done for _BarPainter, needs fix for _AuroraPainter | Eliminates ~4 allocations/frame |
| No resize degradation | AutoHideController._resizing (dead code) | Dead path exists | Needs activation |
| BackdropFilter always on | GlassContainer.blurEnabled (D-14) | Phase 14 | Hardware degradation works, resize degradation missing |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `_AuroraPainter._compositePaint` (default Paint) is safe to share across frames | Pattern 3 | Very low — default Paint has no mutable state |
| A2 | 200ms debounce for resize end is sufficient | Code Examples | User may perceive blur flicker if resize is very fast (<200ms bursts) |
| A3 | `AutoHideController._resizing` setter is truly dead code (never called) | Pattern 2 | Confirmed by grep — no callers found in codebase |

## Open Questions

1. **(RESOLVED)** Should PlaylistPanel get a `resizing` parameter or should it use an inherited widget / provider?
   - Resolution: Constructor params — consistent with existing patterns. An InheritedWidget would be over-engineering for 3 consumers.
   - Rationale: GlassContainer, ControlBar, and PlaylistPanel all get `resizing` as constructor param, threaded from PlayerScreen.

2. **(RESOLVED)** Should resize degradation also affect the AuroraBackground Ticker?
   - Resolution: No — do not pause Ticker during resize.
   - Rationale: Already throttled to 15fps and isolated by RepaintBoundary. BackdropFilter is the real GPU bottleneck, not the Ticker.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | pubspec.yaml dev_dependencies |
| Quick run command | `flutter test` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-05 | RepaintBoundary present on target widgets | widget test | `flutter test test/` | Existing tests |
| PERF-06 | BackdropFilter skipped when isResizing=true | widget test | `flutter test test/` | New test needed |
| PERF-07 | CustomPainter uses static Paint | code review | `flutter analyze` | N/A (structural) |

### Wave 0 Gaps

- [ ] Test for GlassContainer resizing behavior (BackdropFilter skip when resizing=true)
- [ ] Test for ControlBar resizing behavior
- [ ] FakeWindowService needs `isResizing` notifier added

## Sources

### Primary (HIGH confidence)
- Codebase direct analysis — all widget files read and verified
- `grep -rn "RepaintBoundary|BackdropFilter|extends CustomPainter|Paint()" lib/` — comprehensive search

### Secondary (MEDIUM confidence)
- Flutter rendering pipeline documentation (training knowledge)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Flutter SDK only, no external packages
- Architecture: HIGH — direct codebase analysis, line numbers verified
- Pitfalls: MEDIUM — resize signal interaction patterns based on training knowledge

**Research date:** 2026-06-22
**Valid until:** 2026-07-22 (stable — Flutter rendering APIs change slowly)
