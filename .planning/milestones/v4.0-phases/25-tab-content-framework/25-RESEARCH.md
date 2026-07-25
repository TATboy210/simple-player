# Phase 25: Tab Content Framework - Research

**Researched:** 2026-07-23
**Domain:** Flutter settings panel tab content, deferred apply pattern, reusable form controls
**Confidence:** HIGH

## Summary

Phase 25 builds the tab content framework for the new overlay settings panel. The current overlay shell (Phase 23/24) renders placeholder `Center(child: Text(...))` for each of the 7 tabs. This phase replaces those placeholders with real tab page widgets that render SettingRow skeleton lists, adds a generic OK/Cancel/Apply button bar at the panel bottom, and implements a deferred apply pattern where changes are stored in pending state until the user explicitly commits or cancels.

The codebase already has a mature set of reusable setting row components (`SettingRow`, `SettingSwitchRow`, `SettingSliderRow`, `SettingActionRow`) in `lib/ui/shared/settings_card.dart` and sibling files. The old `settings_panel.dart` (~500 lines) implements a working deferred apply pattern for locale/theme/shortcuts that serves as the reference implementation. The key architectural decision is how to generalize this deferred pattern into a reusable framework that any tab can plug into, rather than hard-coding locale/theme specifics.

**Primary recommendation:** Create a generic `PendingSettingsState` that holds `Map<String, dynamic>` pending values keyed by setting ID, with `commit()`, `cancel()`, and `hasPendingChanges` APIs. Each tab registers its pending keys. OK/Apply calls `commit()`, Cancel calls `cancel()`. This generalizes the old `_pendingLocale`/`_pendingThemeIndex` pattern into a framework-level primitive.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tab page rendering | UI (settings_overlay_shell.dart) | — | Each tab is a StatelessWidget rendered inside IndexedStack |
| SettingRow component | UI (shared/settings_card.dart) | — | Reusable label+control layout, already exists |
| OK/Cancel/Apply bar | UI (settings_overlay_shell.dart) | — | Fixed at panel bottom, part of shell layout |
| Deferred apply state | State (SettingsPanelState or new class) | — | Pending values need to persist across tab switches |
| Setting value persistence | Kernel (settings_store.dart) | — | SharedPreferences persistence, already exists |

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter/material.dart | SDK | Material widgets (Switch, Slider, DropdownButton) | Project standard, no alternatives |
| ValueNotifier + ValueListenableBuilder | SDK | Reactive state | Project convention (no Provider/Riverpod/Bloc) |

### Supporting (already in project)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GlassContainer | custom | Glass morphism wrapper | All settings cards |
| AnimatedSectionList | custom | Staggered fade-in animation | Tab content lists |
| SectionHeader | custom | Card section title | Grouping SettingRow items |
| SettingRow | custom | Label + control layout | All setting items |
| SettingSwitchRow | custom | Switch toggle row | Boolean settings |
| SettingSliderRow | custom | Slider with debounce | Numeric range settings |
| SettingActionRow | custom | Action with recording state | Shortcut binding |

### No new packages needed
This phase uses only existing project components and Flutter SDK widgets. No external package installation required.

## Package Legitimacy Audit

Not applicable — no external packages are installed in this phase.

## Architecture Patterns

### System Architecture Diagram

```
SettingsOverlayShell (Phase 23/24)
├── Title Bar (44px) ─── "设置" + close button
├── Tab Bar (64px) ─── 7x SettingsNavItem (horizontal)
├── Content Area ─── IndexedStack + TweenAnimationBuilder fade
│   ├── Tab 0: GeneralTab ─── SettingRow skeletons
│   ├── Tab 1: EqualizerTab ─── SettingRow skeletons
│   ├── Tab 2: AudioTab ─── SettingRow skeletons
│   ├── Tab 3: VideoTab ─── SettingRow skeletons
│   ├── Tab 4: ShortcutsTab ─── SettingRow skeletons
│   ├── Tab 5: AboutTab ─── SettingRow skeletons
│   └── Tab 6: PerformanceTab ─── SettingRow skeletons
└── Button Bar ─── OK / Cancel / Apply (fixed bottom)

State Flow:
  User changes setting → stored in PendingSettingsState._pending map
  OK clicked → commit() → persist all → close panel
  Apply clicked → commit() → persist all → keep panel open
  Cancel clicked → cancel() → restore originals → close panel
```

### Recommended Project Structure

```
lib/ui/dialogs/settings/
├── settings_overlay_shell.dart    # Modified: replace placeholders with real tabs + button bar
├── settings_panel_controller.dart # Modified: add commit/cancel methods
├── settings_panel_state.dart      # Modified: add PendingSettingsState or new file
├── pending_settings.dart          # NEW: generic deferred apply state manager
├── _settings_nav_item.dart        # Existing: no changes
├── tabs/                          # NEW directory
│   ├── general_tab.dart           # NEW: skeleton tab (replaces old general_tab.dart location)
│   ├── equalizer_tab.dart         # NEW: skeleton tab
│   ├── audio_tab.dart             # NEW: skeleton tab
│   ├── video_tab.dart             # NEW: skeleton tab
│   ├── shortcuts_tab.dart         # NEW: skeleton tab
│   ├── about_tab.dart             # NEW: skeleton tab
│   └── performance_tab.dart       # NEW: skeleton tab
├── general_tab.dart               # OLD: kept for reference, not modified
├── equalizer_tab.dart             # OLD: kept for reference
└── ...                            # OLD: other existing tabs
```

**Note:** The old tab files (`general_tab.dart`, `equalizer_tab.dart`, etc.) contain real functional implementations. Phase 25 creates skeleton placeholders in a `tabs/` subdirectory. Later phases will replace skeletons with real content and eventually delete the old files. The overlay shell imports from `tabs/`, not the old files.

### Pattern 1: Deferred Apply State

**What:** A generic state container that holds pending setting changes, original values, and provides commit/cancel APIs.

**When to use:** Any setting that has side effects on the app (locale change triggers MaterialApp rebuild, theme change triggers color scheme update) must be deferred until explicit user commit.

**Example (from old settings_panel.dart reference):**
```dart
// Source: lib/ui/dialogs/settings_panel.dart (lines 63-166)
// The OLD pattern — widget-local state:
late String _pendingLocale;
late int _pendingThemeIndex;
late String _originalLocale;
late int _originalThemeIndex;

void _commitChanges() {
  if (_pendingLocale != _originalLocale) {
    LocaleService.I.setLocale(_pendingLocale);
  }
  if (_pendingThemeIndex != _originalThemeIndex) {
    ThemeService.I.setTheme(_pendingThemeIndex);
  }
}

void _cancel() {
  if (_pendingLocale != _originalLocale) {
    LocaleService.I.setLocale(_originalLocale);
  }
  if (_pendingThemeIndex != _originalThemeIndex) {
    ThemeService.I.setTheme(_originalThemeIndex);
  }
  Navigator.of(context).pop();
}
```

**Recommended new pattern — generic PendingSettingsState:**
```dart
/// 通用延迟应用状态管理器 — 任何 tab 注册 pending key，OK/Apply 提交，Cancel 恢复。
class PendingSettingsState {
  /// 当前待提交的值（key = setting ID, value = pending value）
  final Map<String, dynamic> _pending = {};

  /// 打开面板时的原始快照（key = setting ID, value = original value）
  final Map<String, dynamic> _originals = {};

  /// 是否有未提交的更改
  bool get hasChanges => _pending.isNotEmpty;

  /// 注册一个 setting 的初始值（打开面板时调用）
  void register(String key, dynamic originalValue) {
    _originals[key] = originalValue;
  }

  /// 更新 pending 值（用户在 UI 中修改时调用）
  void update(String key, dynamic value) {
    _pending[key] = value;
  }

  /// 获取当前生效值（有 pending 返回 pending，否则返回 original）
  dynamic current(String key) => _pending[key] ?? _originals[key];

  /// 提交所有 pending 更改 — 返回需要持久化的 map
  Map<String, dynamic> commit() {
    final changes = Map<String, dynamic>.from(_pending);
    _pending.clear();
    // 更新 originals 为已提交值（Apply 后再次 Cancel 应以提交值为基准）
    _originals.addAll(changes);
    return changes;
  }

  /// 取消所有 pending 更改 — 返回需要恢复的 original 值
  Map<String, dynamic> cancel() {
    final originals = Map<String, dynamic>.from(_originals);
    _pending.clear();
    return originals;
  }

  void dispose() {
    _pending.clear();
    _originals.clear();
  }
}
```

### Pattern 2: SettingRow Skeleton Tab

**What:** Each tab page is a StatelessWidget that renders a scrollable list of SettingRow items with placeholder values. The skeleton uses real SettingRow components but with dummy data.

**When to use:** Framework-only milestone — build the structure now, fill real functionality later.

**Example:**
```dart
/// 通用设置 tab（骨架）— Phase 25 框架占位，Phase N 填充真实功能。
class GeneralTabSkeleton extends StatelessWidget {
  final PendingSettingsState pending;
  const GeneralTabSkeleton({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    return AnimatedSectionList(
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spLg,
            vertical: Tokens.spMd,
          ),
          margin: const EdgeInsets.only(bottom: Tokens.spMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '语言', icon: Icons.language),
              SettingRow(
                title: '界面语言',
                description: '选择界面显示语言',
                control: DropdownButton<String>(
                  value: pending.current('locale') as String? ?? 'zh',
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) {
                    if (v != null) pending.update('locale', v);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

### Pattern 3: OK/Cancel/Apply Button Bar

**What:** Fixed bottom bar with three action buttons. OK applies + closes, Apply applies without closing, Cancel reverts + closes.

**When to use:** Always present in the settings panel — part of the shell layout.

**Example (from old settings_panel.dart reference):**
```dart
// Source: lib/ui/dialogs/settings_panel.dart (lines 709-753)
Widget _buildBottomBar(AppLocalizations l10n) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Tokens.spMd,
      vertical: Tokens.spSm,
    ),
    color: Tokens.bgGlass,
    child: Row(
      children: [
        const Spacer(),
        _BottomButton(label: l10n.ok, primary: true, onTap: _ok),
        const SizedBox(width: Tokens.spSm),
        _BottomButton(label: l10n.cancel, onTap: _cancel),
        const SizedBox(width: Tokens.spSm),
        _BottomButton(label: l10n.apply, onTap: _apply),
      ],
    ),
  );
}
```

**Key design decisions for the new implementation:**
- The button bar is part of `_buildPanel()` in `settings_overlay_shell.dart`, placed below the content area as a new `Column` child.
- `_BottomButton` from the old panel can be extracted to a shared component or inlined.
- OK and Apply both call `pending.commit()` then persist via SettingsStore. OK additionally calls `_controller.close()`.
- Cancel calls `pending.cancel()` then calls `_controller.close()`.

### Anti-Patterns to Avoid

- **Direct service calls in tab widgets:** Tabs should only update `PendingSettingsState`, never call `LocaleService`/`ThemeService` directly. The commit/restore logic lives in the shell or controller.
- **Widget-local pending state:** Do NOT put `_pendingLocale` etc. in the shell's `State` class. Use `PendingSettingsState` so it's testable independently and accessible from any tab.
- **Hard-coded setting keys:** Use string constants or an enum for setting keys (`'locale'`, `'themeIndex'`, `'shortcuts'`) to avoid typos.
- **Skeleton tabs with real service dependencies:** Skeleton tabs should accept `PendingSettingsState` only, not `MediaEngine` or `VideoProcessingService`. Real dependencies come when skeletons are replaced.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Switch toggle row | Custom StatefulWidget | `SettingSwitchRow` (existing) | Already handles ValueNotifier binding + hover feedback |
| Slider with debounce | Custom slider + Timer | `SettingSliderRow` (existing) | 50ms debounce + drag state already implemented |
| Action recording row | Custom key capture | `SettingActionRow` (existing) | Active/deactivate states + conflict detection built in |
| Staggered fade animation | Custom AnimationController | `AnimatedSectionList` (existing) | Interval-based stagger already works |
| Section grouping | Custom card layout | `GlassContainer` + `SectionHeader` | Consistent glass morphism design language |

**Key insight:** The existing component library (`SettingRow`, `SettingSwitchRow`, `SettingSliderRow`, `SettingActionRow`, `GlassContainer`, `SectionHeader`, `AnimatedSectionList`) covers 90% of the UI needs. Phase 25's job is wiring these into tab page widgets and adding the deferred apply framework, not building new UI components.

## Runtime State Inventory

> Not applicable — this is a greenfield UI framework phase, not a rename/refactor/migration.

## Common Pitfalls

### Pitfall 1: IndexedStack Rebuild on Pending State Change
**What goes wrong:** If `PendingSettingsState` triggers a `setState` on the shell, all 7 tabs in the IndexedStack rebuild, causing jank.
**Why it happens:** `PendingSettingsState` is not a `ValueNotifier`, so the shell uses `setState` which rebuilds everything.
**How to avoid:** Make `PendingSettingsState` extend `ChangeNotifier` or use a `ValueNotifier<Map>` for the pending map. Each tab uses `ValueListenableBuilder` to listen only to its own keys. Alternatively, keep `PendingSettingsState` as a plain object and have each tab manage its own local state, calling `pending.update()` on changes without triggering shell rebuilds.
**Warning signs:** Frame drops when toggling switches or moving sliders.

### Pitfall 2: Cancel Not Restoring Tab-Local State
**What goes wrong:** User changes a setting in Tab 3, switches to Tab 0, clicks Cancel. Tab 3's UI still shows the changed value because the tab widget's local state wasn't reset.
**Why it happens:** Tab widgets may hold local state (e.g., `setState` for a slider position) that isn't tied to `PendingSettingsState`.
**How to avoid:** Tabs should derive their display values from `pending.current(key)`, not from local state. When `cancel()` clears pending values, the tab rebuilds with original values.
**Warning signs:** After Cancel, switching back to a previously visited tab shows stale values.

### Pitfall 3: Apply Without Updating Originals
**What goes wrong:** User clicks Apply (applies but doesn't close), then changes the same setting again, then clicks Cancel. The cancel restores to the pre-Apply value, not the Apply'd value.
**Why it happens:** `commit()` doesn't update `_originals` to the committed values.
**How to avoid:** After `commit()`, update `_originals` to match the committed values. This way, a subsequent Cancel restores to the last Apply'd state.
**Warning signs:** Apply-then-Cancel doesn't behave symmetrically.

### Pitfall 4: Skeleton Tab Import Path Confusion
**What goes wrong:** Planner puts skeleton tabs in `lib/ui/dialogs/settings/` alongside the old real tabs, causing import ambiguity.
**Why it happens:** Old tabs (`general_tab.dart`, `equalizer_tab.dart`) and new skeletons would coexist in the same directory.
**How to avoid:** Use a `tabs/` subdirectory for skeleton tabs. The overlay shell imports from `settings/tabs/general_tab.dart`, not `settings/general_tab.dart`.
**Warning signs:** Analyzer warnings about duplicate class names.

## Code Examples

### Verified patterns from the codebase:

### SettingRow with description (existing pattern)
```dart
// Source: lib/ui/shared/settings_card.dart (lines 14-111)
SettingRow(
  icon: Icons.volume_up,
  title: '音量',
  description: '调整播放音量',  // 灰色小字，标签下方
  control: Slider(value: 0.8, onChanged: (v) {}),
)
```

### SettingSwitchRow (existing pattern)
```dart
// Source: lib/ui/shared/settings_card.dart (lines 113-154)
SettingSwitchRow(
  title: '去隔行',
  description: '仅软件解码器',
  notifier: service.deinterlaceEnabled,
)
```

### GlassContainer card grouping (existing pattern)
```dart
// Source: lib/ui/dialogs/settings/video_tab.dart (lines 46-79)
GlassContainer(
  padding: const EdgeInsets.symmetric(
    horizontal: Tokens.spLg,
    vertical: Tokens.spMd,
  ),
  margin: const EdgeInsets.only(bottom: Tokens.spMd),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title: '色彩校正', icon: Icons.color_lens),
      // SettingRow items...
    ],
  ),
)
```

### Old deferred apply pattern (reference)
```dart
// Source: lib/ui/dialogs/settings_panel.dart (lines 63-166)
// _pendingLocale, _pendingThemeIndex — widget-local
// _originalLocale, _originalThemeIndex — snapshot on open
// _commitChanges() — apply pending to services
// _cancel() — restore originals to services
// _ok() — commit + pop
// _apply() — commit + update originals
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Widget-local `_pendingLocale`/`_pendingThemeIndex` | Generic `PendingSettingsState` | Phase 25 | Any tab can register pending changes without shell modification |
| Old `settings_panel.dart` bottom bar | Overlay shell integrated bar | Phase 25 | OK/Cancel/Apply part of the glass overlay, not a separate dialog |
| Placeholder `Center(child: Text(...))` | Skeleton tab pages with SettingRow | Phase 25 | Visual structure ready for real content |

**Deprecated/outdated:**
- `lib/ui/dialogs/settings_panel.dart` (~500 lines): Will be replaced entirely by the overlay shell framework. Kept for reference during Phase 25, deleted when all tabs are migrated.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SpinControl is a new component (not in codebase yet) — Phase 25 creates skeleton placeholder, Phase 26 implements real SpinControl | Pattern 2 | If SpinControl exists elsewhere, skeleton tab pattern changes slightly |
| A2 | Skeleton tabs go in `tabs/` subdirectory, not alongside old tabs | Architecture | Import path confusion if placed in same directory |
| A3 | `PendingSettingsState` is a new file, not an extension of `SettingsPanelState` | Pattern 1 | If merged into SettingsPanelState, test isolation changes |
| A4 | Old `settings_panel.dart` is kept for reference during Phase 25, not deleted | Anti-Patterns | If deleted too early, reference patterns are lost |

## Open Questions

1. **Should PendingSettingsState be a ChangeNotifier or plain object?**
   - What we know: `SettingsPanelState` uses `ValueNotifier` for each field. Old panel used widget-local `setState`.
   - What's unclear: Whether PendingSettingsState needs to trigger rebuilds across tabs, or if each tab manages its own local state independently.
   - Recommendation: Plain object with no ChangeNotifier. Each tab manages its own local state and calls `pending.update()` imperatively. The shell only rebuilds on OK/Cancel/Apply button press (via `setState` or controller method). This avoids IndexedStack rebuild cascades.

2. **Should the 7 skeleton tabs be in a `tabs/` subdirectory or flat in `settings/`?**
   - What we know: Old tabs are flat in `settings/`. The overlay shell currently imports from `settings/`.
   - What's unclear: Whether co-locating skeletons with old tabs creates confusion.
   - Recommendation: Use `tabs/` subdirectory. Clear separation, no import ambiguity, easy to delete old files later.

3. **Should the old `_BottomButton` be extracted to shared or inlined?**
   - What we know: `_BottomButton` is a private widget in `settings_panel.dart` with hover/press scale animation.
   - What's unclear: Whether to reuse it in the new shell or create a simpler version.
   - Recommendation: Extract to `lib/ui/shared/settings_button.dart` as a public `SettingsButton` widget. The old panel's implementation is solid (hover scale, press scale, primary accent glow) and matches the design language.

## Environment Availability

> Not applicable — this phase has no external dependencies beyond Flutter SDK.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — default Flutter test config |
| Quick run command | `flutter test test/ui/dialogs/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TABS-01 | 7 tab pages render SettingRow skeletons | widget | `flutter test test/ui/dialogs/settings_tab_content_test.dart` | No — Wave 0 |
| TABS-02 | SettingRow supports Switch/Slider/Dropdown types | widget | `flutter test test/ui/dialogs/settings_tab_content_test.dart` | No — Wave 0 |
| TABS-03 | OK/Cancel/Apply bar renders at panel bottom | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart` (extend) | Yes |
| TABS-04 | Deferred apply: pending → commit/cancel | unit | `flutter test test/ui/dialogs/pending_settings_test.dart` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/ui/dialogs/`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/ui/dialogs/pending_settings_test.dart` — covers TABS-04 deferred apply logic
- [ ] `test/ui/dialogs/settings_tab_content_test.dart` — covers TABS-01/02 skeleton rendering
- [ ] Extend `test/ui/dialogs/settings_overlay_shell_test.dart` — covers TABS-03 button bar
- [ ] No framework install needed — flutter_test is SDK-bundled

## Security Domain

Not applicable — this phase is pure UI framework with no authentication, input validation, cryptography, or external API calls. Setting values are user preferences (locale, theme, volume) with no security sensitivity.

## Sources

### Primary (HIGH confidence)
- `lib/ui/dialogs/settings_panel.dart` — Old deferred apply pattern, OK/Cancel/Apply bar, 7 tab wiring
- `lib/ui/shared/settings_card.dart` — SettingRow + SettingSwitchRow components
- `lib/ui/shared/setting_slider_row.dart` — SettingSliderRow component
- `lib/ui/shared/setting_action_row.dart` — SettingActionRow component
- `lib/ui/dialogs/settings/settings_overlay_shell.dart` — Current overlay shell with placeholder tabs
- `lib/ui/dialogs/settings/settings_panel_state.dart` — Current state model (3 ValueNotifiers)
- `lib/ui/dialogs/settings/settings_panel_controller.dart` — Controller with open/close/toggle

### Secondary (MEDIUM confidence)
- `lib/ui/shared/animated_section_list.dart` — Staggered fade animation for tab content
- `lib/ui/shared/section_header.dart` — Card section header component
- `lib/ui/shared/glass_container.dart` — Glass morphism container
- `lib/ui/theme/tokens.dart` — Design tokens (all visual values via Tokens.*)

### Tertiary (LOW confidence)
- None — all findings are from direct codebase inspection

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components exist in codebase, no new packages
- Architecture: HIGH — clear patterns from old settings_panel.dart + Phase 23/24 overlay shell
- Pitfalls: HIGH — IndexedStack rebuild, cancel restore, apply-originals sync are well-understood Flutter patterns

**Research date:** 2026-07-23
**Valid until:** 2026-08-23 (stable — framework patterns, not API-dependent)
