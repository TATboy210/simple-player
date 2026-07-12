# Project Research Summary

**Project:** Simple Player Flutter — Settings Panel & Fullscreen Refactoring
**Researched:** 2026-07-12
**Confidence:** HIGH

## Executive Summary

Two structural problems: (1) 450-line SettingsStore god-object with 26 fields across 5 domains, (2) fullscreen state dual-source-of-truth (WindowService + SettingsStore). Solution: domain decomposition + fullscreen single-owner. Existing stack (ValueNotifier, shared_preferences, GlassContainer, FullscreenDriver) is correct — keep all.

## Key Findings

### Stack: Keep Everything
- ValueNotifier + ValueListenableBuilder — correct for 7 tabs
- shared_preferences — right for ~25 keys
- GlassContainer — already optimized (cached filters, tier system)
- FullscreenDriver hierarchy — clean strategy pattern
- Sidebar 72px → 80-100px for CJK labels

### Features
**Table stakes:** Reset to defaults, consolidate 7→5 tabs, instant feedback, keyboard nav
**Differentiators:** Settings search, shortcut conflict detection, import/export
**Defer:** Live preview, presets, per-file settings

### Architecture
- AppSettings god-object (26 fields, 5 domains) → split into PlaybackConfig, WindowConfig, SubtitleConfig, VideoConfig, EngineConfig
- SettingsStore (25+ static methods) → domain-specific stores + thin orchestrator
- Fullscreen: WindowService sole owner, remove from SettingsStore
- Constructor injection (already pattern), no DI package needed

### Critical Pitfalls
1. Fullscreen dual-source truth → WindowService single owner
2. Settings migration without version → add settingsVersion key first
3. Deferred apply violation → locale/theme always deferred
4. Win32 FFI resource leak → try/finally for Pointer.free()
5. Over-abstraction → split store, keep model simple

## Roadmap

Phase 1: Settings Store Decomposition (~3h) — domain stores, migration key
Phase 2: Fullscreen Decoupling (~2h) — WindowService sole owner
Phase 3: Settings Panel UI (~4h) — 7→5 tabs, constructor injection, reset defaults
Phase 4: UX Polish & Search (~3h) — search, sidebar width, scrollbar, conflict detection
Phase 5: Import/Export & Cleanup (~2h) — JSON export, singleton removal

---
*Research completed: 2026-07-12*
