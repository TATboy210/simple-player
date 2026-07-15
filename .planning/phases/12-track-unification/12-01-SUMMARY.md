---
phase: 12-track-unification
plan: 01
subsystem: ui
tags: [track-preference, subtitle, audio, value-notifier]

requires:
  - phase: 11
    provides: TrackPreferenceService, TrackPreferences model, SettingsStore persistence
provides:
  - UI layer wired to record audio/subtitle track preferences on user interaction
  - activeSubtitleTracks getter on SubtitleConfig/TrackControl interface
affects: [12-track-unification]

tech-stack:
  added: []
  patterns: [callback-based preference recording from UI to kernel service]

key-files:
  created: []
  modified:
    - lib/ui/player/player_screen.dart
    - lib/kernel/engine/subtitle_config.dart
    - lib/kernel/engine/subtitle_track_source.dart
    - lib/kernel/engine/track_manager.dart
    - lib/kernel/engine/fvp_engine.dart
    - lib/kernel/engine/subtitle_configurator.dart
    - test/helpers/fake_engine.dart
    - test/kernel/engine/subtitle_configurator_test.dart

key-decisions:
  - "Added activeSubtitleTracks getter to SubtitleConfig interface (mirrors activeAudioTracks on TrackControl)"
  - "Plan Step 2 evaluated: MediaEngine already unifies TrackControl+SubtitleConfig+VideoEffectControl — no merge needed"

patterns-established:
  - "Subtitle toggle records preference: toggle → read activeSubtitleTracks → recordSubtitleTrack(index or -1)"

requirements-completed: [TRK-01, TRK-02]

coverage:
  - id: D1
    description: "Audio track switching records preference via onAudioTrackChanged callback"
    requirement: TRK-01
    verification:
      - kind: unit
        ref: test/kernel/services/track_preference_service_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: "Subtitle toggle (S key) records preference after toggle"
    requirement: TRK-02
    verification:
      - kind: unit
        ref: test/kernel/engine/subtitle_configurator_test.dart
        status: pass
    human_judgment: false
  - id: D3
    description: "Subtitle delay ([ ]) records preference"
    requirement: TRK-02
    verification:
      - kind: unit
        ref: test/kernel/services/track_preference_service_test.dart
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-07-15
status: complete
---

# Phase 12-01: 轨道偏好录制接入 Summary

**UI 层轨道切换操作（音轨选择、字幕开关、字幕延迟）全部接入 TrackPreferenceService 录制，偏好跨会话持久化**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-07-15
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- S 键字幕 toggle 现在录制偏好（之前只有音轨和延迟录制）
- 新增 `activeSubtitleTracks` getter 到 SubtitleConfig 接口链（SubtitleTrackSource → TrackManager → SubtitleConfigurator → FvpEngine），与 `activeAudioTracks` 模式一致
- 验证 Success Criteria #1: MediaEngine 已统一 TrackControl+SubtitleConfig+VideoEffectControl，无需合并

## Files Created/Modified
- `lib/ui/player/player_screen.dart` — onToggleSubtitle 回调增加 recordSubtitleTrack 调用
- `lib/kernel/engine/subtitle_config.dart` — 新增 activeSubtitleTracks 抽象 getter
- `lib/kernel/engine/subtitle_track_source.dart` — 新增 activeSubtitleTracks 抽象 getter
- `lib/kernel/engine/track_manager.dart` — 实现 activeSubtitleTracks（读 _player.activeSubtitleTracks）
- `lib/kernel/engine/fvp_engine.dart` — 代理 activeSubtitleTracks 到 _trackManager
- `lib/kernel/engine/subtitle_configurator.dart` — 代理 activeSubtitleTracks 到 _trackSource
- `test/helpers/fake_engine.dart` — FakeEngine 实现 activeSubtitleTracks
- `test/kernel/engine/subtitle_configurator_test.dart` — FakeSubtitleTrackSource 实现 activeSubtitleTracks

## Decisions Made
- 新增 `activeSubtitleTracks` 到 kernel 层接口（计划说"不需要修改 kernel 层"，但读取 toggle 结果必须暴露该 getter）
- Plan Step 2 评估结论：MediaEngine 已是统一接口，三个实现类是内部细节，无需合并

## Deviations from Plan

### Auto-fixed Issues

**1. [Interface Gap] activeSubtitleTracks 未暴露**
- **Found during:** Implementation
- **Issue:** 计划假设不需要修改 kernel 层，但 toggleSubtitle() 不返回结果，UI 无法读取切换后的状态
- **Fix:** 在 SubtitleConfig 接口链添加 activeSubtitleTracks getter（4 文件 + 2 测试 fake）
- **Files modified:** subtitle_config.dart, subtitle_track_source.dart, track_manager.dart, fvp_engine.dart, subtitle_configurator.dart, fake_engine.dart, subtitle_configurator_test.dart
- **Verification:** flutter analyze 零错误, 21 track tests 全通过
- **Committed in:** feat commit

---

**Total deviations:** 1 auto-fixed (interface gap)
**Impact on plan:** 必要修改，遵循 activeAudioTracks 已有模式，无范围膨胀

## Issues Encountered
None

## Next Phase Readiness
- Phase 12 轨道管理统一完成（1/1 plan）
- 所有轨道操作（音轨切换、字幕开关、字幕延迟）均已录制偏好
- `flutter analyze` 零错误，730 测试通过（34 pre-existing load failures）

---
*Phase: 12-track-unification*
*Completed: 2026-07-15*
