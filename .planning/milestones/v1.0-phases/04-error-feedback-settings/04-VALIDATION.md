---
phase: "4"
slug: "error-feedback-settings"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-08-31"
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 04-RESEARCH.md `## Validation Architecture`（2026-08-31）

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) + fake_async 1.3.3（防抖/timer 用例） |
| **Config file** | none（惯例:lib 路径镜像到 test/;kernel diagnostics → test/diagnostics/,widgets → test/widget/...） |
| **Quick run command** | `flutter test test/diagnostics/ test/widget/dialogs/ test/widget/player/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | quick ~10s / full ~60s |

---

## Sampling Rate

- **After every task commit:** quick run command
- **After every plan wave:** `flutter test` + `flutter analyze`（0 error 红线）+ `bash tool/audit/kernel_logger_gate.sh`（kernel 触碰:error_log_location.dart 扩展必须保持 GATE 1/2 干净）
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** ~15s

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-xx | 01 | 1 | SET-03 | T-04-01 | settings.json 读写失败静默回退,不阻断启动 | unit | planner 落位的 store 测试文件（load/save/fallback 矩阵:缺失/坏 JSON/错形状/BOM→默认;round-trip;保存失败吞） | ❌ W0 | ⬜ pending |
| 04-0x-xx | 0x | x | SET-02 | T-04-02 | 回退链:配置(有效)>exe-root>AS;配置无效跳级;file-as-dir 异常形态→该层失败;可写临时目录→过 | unit（注入 provider + 临时目录） | `flutter test test/diagnostics/error_log_location_test.dart`（扩展） | ✅ extend | ⬜ pending |
| 04-0x-xx | 0x | x | SET-02 | T-01-13/19 重审 | 重定向:dispose→activate 保序;间隙记录缓冲后冲刷;新文件收 post-swap;旧文件保 pre-swap | unit（注入 ErrorLogWriter） | `flutter test test/diagnostics/error_log_file_sink_test.dart` + 新 coordinator 测试 | ✅ extend + ❌ W0 | ⬜ pending |
| 04-0x-xx | 0x | x | SET-01 | — | 开关门控:off→host 渲染空;on→最新快照渲染;off 期间快照继续收报告;默认开（settings 缺失/损坏） | widget + unit | `flutter test test/widget/player/error_card_host_test.dart`（扩展）+ store 测试 | ✅ extend + ❌ W0 | ⬜ pending |
| 04-0x-xx | 0x | x | SET-02 | — | UI 校验:防抖探测、行内状态(✓/✗/回退中)、浏览取消(null)忽略 | widget + fakeAsync | `flutter test test/widget/dialogs/settings_dialog_test.dart`（扩展） | ✅ extend | ⬜ pending |
| 04-0x-xx | 0x | x | — | — | 通用 tab 导航:选中态切换内容;About 仍可达 | widget | settings_dialog_test（扩展） | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*具体 task id / wave 归属由 planner 按计划结构填定,本表为需求→测试的完整映射（Nyquist Dimension 8 源）。*

---

## Wave 0 Requirements

- [ ] `test/diagnostics/error_feedback_settings_store_test.dart`（或 planner 定位）— SET-03 load/save/fallback 矩阵
- [ ] 重定向 coordinator 测试（dispose→activate 顺序 + 缓冲冲刷）
- [ ] `error_log_location.dart` 注入式 exe 目录 provider + 可写探测 seam（先于测试可写）
- [ ] 全部新 UI 文案的 ARB key（en+zh）+ `flutter gen-l10n` 再生成

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 实机 debug run:开关切换卡片立即消失/恢复;日志路径变更后新错误写新位置、旧行不丢 | SET-01/02 | 宿主窗口/文件系统实机行为 | 实机切换开关与路径,触发错误,检查新旧日志文件内容分布 |
| 回退 OSD「日志已回退到默认位置」出现一次不刷屏 | D-04 | OSD 一次性语义实机观察 | 配置无效路径,观察 OSD 与行内状态 |
| MSIX 包内冒烟:exe-root 探测失败→行内显示 AS 有效路径 | D-02/SET-02 | MSIX ACL 环境无法 headless 复现 | MSIX 安装包运行,检查行内状态与日志落点 |
| 设置对话框输入非法路径(指向文件)的行内 ✗ 与不保存 | SET-02 | 交互路径 | 手动输入非法路径观察 |

---

## Headless Baseline Caveats

- **mdk.dll FFI 基线**（MEMORY: reference_mdk_dll_headless_test_failures）——非回归;按 stash/re-run 方法鉴别,只判 delta
- **2 个状态机 security 测试预存失败**（MEMORY: reference_state_machine_security_preexisting_failure）——同基线
- 本 phase 新测试（store/位置链/host 门控/对话框）为纯 Dart/Flutter,**headless 必须全绿**——不接受「CI flaky」

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
