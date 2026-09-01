---
phase: "3"
slug: "playback-error-card-bridge"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-08-30"
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 03-RESEARCH.md `## Validation Architecture`（2026-08-30）

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK, Flutter 3.47.0); fake_async 1.3.3 available |
| **Config file** | none beyond `analysis_options.yaml` |
| **Quick run command** | `flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | quick ~5s / full ~60s |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widget/player/error_card_test.dart test/widget/player/error_card_host_test.dart`
- **After every plan wave:** Run `flutter test` + `flutter analyze`（0 error 红线）
- **Before `/gsd-verify-work`:** Full suite must be green（headless 预存失败除外,按既有基线鉴别）
- **Max feedback latency:** ~10 seconds（quick）

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | CARD-05 | — | N/A | widget | `flutter test test/widget/player/error_card_host_test.dart`（build 期到达无 markNeedsBuild 次生错误,post-frame 合并发布） | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | CARD-06 | — | N/A | widget | `flutter test test/widget/player/error_card_host_test.dart --plain-name 'mount'`（root 挂载 + ValueListenableBuilder 订阅） | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | CARD-01 | — | N/A | widget | `flutter test test/widget/player/error_card_test.dart`（常驻手动关、无自动消失、`FocusManager.instance.primaryFocus` 不变） | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | CARD-03 | — | 折叠/展开字段按 D-07 Phase 2 脱敏边界渲染 | widget | `flutter test test/widget/player/error_card_test.dart --plain-name 'expand'` | ❌ W0 | ⬜ pending |
| 03-02-03 | 02 | 2 | CARD-02 | T-信息泄露 | 卡内只渲染 reporter 已脱敏字段;fullMediaPath 不进可见卡 | widget + manual | `flutter test test/widget/player/error_card_test.dart --plain-name 'hit-test'` + Windows smoke | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 3 | CARD-04 | T-剪贴板 | 复制失败降级不影响卡片 | widget | `flutter test test/widget/player/error_card_test.dart --plain-name 'copy'`（mock `flutter/platform` channel,失败注入） | ❌ W0 | ⬜ pending |
| 03-03-02 | 03 | 3 | D-02/D-11 | — | N/A | widget | `flutter test test/widget/player/error_card_host_test.dart --plain-name 'warning'`（warning→OSD 不进卡;本地快照轮览） | ❌ W0 | ⬜ pending |
| 03-04-01 | 04 | 4 | MIG-01 | — | N/A | widget + grep | `flutter test test/widget/player/error_banner_equivalence_test.dart`（删前双路径等效断言）→ `grep -r ErrorBanner lib/ test/` 返回空 | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget/player/error_card_test.dart` — CARD-01/02/03/04 stubs
- [ ] `test/widget/player/error_card_host_test.dart` — CARD-05/06 + warning 路由 stubs
- [ ] `test/widget/player/error_banner_equivalence_test.dart` — MIG-01 等效测试（删除前对旧路径跑,删除后重定向新路径）
- [ ] `lib/l10n/app_en.arb` / `app_zh.arb` 新 l10n key + `flutter gen-l10n`（生成文件已入库）

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Windows 实机 hit-test:卡片显示期间控制栏/标题栏/播放列表正常命中 | CARD-02 | 宿主窗口 hit-test 无法在 headless 断言 | 实机播放视频,触发错误,点击卡片外各控件确认响应;**含全屏期间卡片显示(D-10)场景** |
| 全屏期间卡片显示且退出全屏后正常 | D-10/CARD-01 | 全屏 route 遮挡无法在 widget test 复现 | 实机进入全屏触发错误,确认卡片可见;退出全屏确认状态一致 |

---

## Headless 基线注意（load-bearing）

- **禁止在卡片测试中构造 MediaKitEngine/media_kit Player**——用 `test/helpers/fake_engine.dart` + reporter fixtures（模板:`test/diagnostics/player_error_report_bridge_test.dart`）;mdk.dll FFI headless 失败为预存基线
- `KernelLoggerImpl.resetForTesting()` + `init()` 于 `setUpAll`;`ErrorReporterImpl.resetForTesting()` 每测试间(单例)
- 剪贴板测试必须 mock `flutter/platform` channel(未 mock 抛 MissingPluginException;同时是 CARD-04 失败注入缝)

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
