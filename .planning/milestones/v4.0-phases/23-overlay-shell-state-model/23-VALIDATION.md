---
phase: 23
slug: overlay-shell-state-model
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-22
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `23-RESEARCH.md` § Validation Architecture (HIGH confidence).
> Per-task rows are keyed by requirement ID; task IDs / waves are reconciled
> after `gsd-planner` produces `*-PLAN.md` files.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test`（项目既有，`test/` 目录已存在多文件） |
| **Config file** | `pubspec.yaml`（flutter_test dev_dependency）+ `analysis_options.yaml`（strict-casts/strict-inference/strict-raw-types） |
| **Quick run command** | `flutter test test/ui/dialogs/settings_panel_state_test.dart test/ui/dialogs/settings_panel_controller_test.dart -x` |
| **Full suite command** | `flutter test`（全量回归） |
| **Static gate** | `flutter analyze`（strict 干净，零 warning/error） |
| **Estimated runtime** | 本阶段 3 新文件 < ~10s；全量套件 ~60-90s（含 ~57 既有 mdk.dll 失败） |

---

## Sampling Rate

- **After every task commit:** `flutter test test/ui/dialogs/settings_panel_state_test.dart test/ui/dialogs/settings_panel_controller_test.dart test/ui/dialogs/settings_overlay_shell_test.dart -x`
- **After every plan wave:** `flutter test`（全量回归 — 注意 mdk.dll headless FFI 预存在失败 ~57 项，非本阶段回归，须 stash/re-run 鉴别）
- **Before `/gsd-verify-work`:** `flutter analyze` 严格干净 + 3 测试文件全绿 + 全量套件无**新增**失败（既有 mdk.dll 失败不计）
- **Max feedback latency:** ~10s（quick 命令）

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| — (pending planner) | — | 0 | PANEL-01 | — | N/A（纯数据模型） | unit | `flutter test test/ui/dialogs/settings_panel_state_test.dart -x` | ❌ W0 新建 | ⬜ pending |
| — (pending planner) | — | 0 | PANEL-02 | — | `open()` 已开时 no-op；`close()` 已关时 no-op | unit | `flutter test test/ui/dialogs/settings_panel_controller_test.dart -x` | ❌ W0 新建 | ⬜ pending |
| — (pending planner) | — | — | PANEL-02 | — | `open()` 暂停 + wasPlaying 快照；`close()` 仅 wasPlaying=true 恢复 | unit | 同上 | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-02 | — | `toggle()` 等价 open/close 切换 | unit | 同上 | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-03 | — | `BackdropFilter` + `bgGlass` + `borderHighlight` 存在 | widget | `flutter test test/ui/dialogs/settings_overlay_shell_test.dart -x` | ❌ W0 新建 | ⬜ pending |
| — (pending planner) | — | — | PANEL-04 | T-23-03 | `dragOffset` clamp 到 `MediaQuery` 边界（防越界/负值） | widget | 同上 | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-05 | T-23-01 | 点击遮罩调用 `close()`；面板关闭后 `IgnorePointer` 不命中下层 | widget | 同上 | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-05 | — | `AnimatedScale`+`AnimatedOpacity` 200ms，结束后 scale==1.0/opacity==1.0 | widget | 同上（`pumpAndSettle(200ms)`） | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-06 | T-23-02 | ESC 关面板且不冒泡 `onExitFullscreen`（`KeyEventResult.handled`） | widget | 同上（KeyEvent 模拟） | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-06 | — | B 键关面板 | widget | 同上 | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-07 | — | 基础尺寸 500×400 | widget | 同上 | ❌ W0 | ⬜ pending |
| — (pending planner) | — | — | PANEL-07 | — | 面板不超过窗口 80% | widget | 同上（`MediaQuery` override） | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Threat refs: T-23-01 click-through (Tampering) · T-23-02 ESC-race→fullscreen (Tampering) · T-23-03 drag-out-of-bounds (Tampering) — see `23-RESEARCH.md` § Security Domain.*

---

## Wave 0 Requirements

- [ ] `test/ui/dialogs/settings_panel_state_test.dart` — 覆盖 PANEL-01（3 notifier 初始值 isOpen=false/selectedTab=0/dragOffset=Offset.zero + dispose）
- [ ] `test/ui/dialogs/settings_panel_controller_test.dart` — 覆盖 PANEL-02（open/close/toggle + wasPlaying 快照 + 已开/已关 no-op）
- [ ] `test/ui/dialogs/settings_overlay_shell_test.dart` — 覆盖 PANEL-03/04/05/06/07（widget 测试：挂载/动画/拖拽 clamp/ESC+B/尺寸）
- [ ] `FakePlaybackController`（共享 fixture）— 手写 fake 实现 `pause()`/`play()`/`isPlaying`，替代 `PlaybackController` 避免 mdk.dll headless FFI 风险（CLAUDE.md "Fakes over mocks"）

*Wave 0 新测试**不依赖**真实 MediaEngine，规避 ~57 既有 mdk.dll FFI 加载失败（非本阶段回归）。*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 毛玻璃视觉模糊效果（像素级） | PANEL-03 | headless widget 测试无 GPU 模糊 | 启动应用 `-d windows`，打开设置面板，目视确认 BackdropFilter 模糊生效 |

*其余所有行为（状态/控制器/动画结束态/拖拽 clamp/键盘/尺寸）均有自动化验证。动画时序用 `pumpAndSettle(200ms)` 断言结束态而非中间帧；BackdropFilter 断言 widget 存在性而非像素。*

---

## Flakiness Risks (mitigations baked into Wave 0)

- **动画时序断言** — `AnimatedScale`/`AnimatedOpacity` 200ms：用 `tester.pumpAndSettle(const Duration(milliseconds: 200))` 或 `fakeAsync`，断言结束后 scale==1.0/opacity==1.0 而非中间帧。
- **BackdropFilter GPU** — headless 无实际模糊：断言 `BackdropFilter` widget 存在性 + `GlassContainer` 层级，不断言像素级模糊。
- **Focus subtree 时序** — ESC/B 测试须 `tester.pump()` 让 Focus 获得焦点后再 `tester.sendKeyEvent`；参考 `playlist_panel` 既有测试模式。
- **mdk.dll headless FFI** — 全量 `flutter test` 有 ~57 既有失败（MEMORY.md 记录），非本阶段回归；Wave 0 用 `FakePlaybackController` 规避。

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (PANEL-01..07 全部)
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
