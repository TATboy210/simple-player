# Roadmap: Simple Player — 窗口外观与全屏体验

## Overview

本里程碑对外壳层四个体验问题做外科手术式修复：系统主题色边框消除、跨平台圆角一致性、全屏进出过渡无闪烁、自绘标题栏拖拽稳定跟手。所有修复建立在已交付的 C1（NCCALCSIZE 多分支）与 C2（WindowMode 单一数据源）不变量之上。阶段顺序遵循依赖链：先钉死不变量与能力探测，再做 chrome 属性（边框→圆角共享 ApplyChromeAttributes），拖拽在全屏闪烁之前落地（两者共享 WM_NCHITTEST），全屏闪烁作为压轴阶段因其触及三层且解禁 media_kit 红线，Linux 结构性实现与文档打磨收尾。

## Milestones

- ✅ **v1.0 错误捕获定位反馈系统** - Phases 1-5 (shipped 2026-09-01, archived)
- 🚧 **v1.1 窗口外观与全屏体验** - Phases 6-11 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (6, 7, 8): Planned milestone work (continuing from v1.0 Phase 5)
- Decimal phases (6.1, 6.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 6: 能力探测与 C1/C2 钉死** - 启动期 DWM 能力探测门控所有属性调用，C1 缝隙不变量钉死防回归。
- [ ] **Phase 7: 去主题色边框** - Win11 消除系统强调色描边，Win10 接受 1px 为已知平台差异，属性在主题/DPI/模式变化后重应用。
- [ ] **Phase 8: 圆角统一** - Win11 原生 DWM 圆角，Win10 接受直角（行业同款取舍），无视频性能代价。
- [ ] **Phase 9: 标题栏拖拽可靠性** - 原生 HTCAPTION 命中测试消除偶发不跟手，双击最大化与按钮簇共存。
- [ ] **Phase 10: 全屏过渡无闪烁** - 进出全屏零可见闪烁，恢复进入前窗口模式，达产品级基线。
- [ ] **Phase 11: Linux 结构性实现与打磨** - Linux 合成器分支结构性正确（待实机验证），文档修正。

## Phase Details

### Phase 6: 能力探测与 C1/C2 钉死

**Goal**: 后续所有阶段可安全调用 DWM 属性——启动期一次性能力快照门控全部调用，Win10 绝不收到 Win11 专属属性；C1 缝隙不变量以回归测试与守卫注释钉死，后续 chrome 工作不得使其回归。
**Depends on**: Nothing (first phase of milestone)
**Requirements**: ENAB-01, ENAB-02
**Success Criteria** (what must be TRUE):
  1. 应用在 Win10 上启动时不产生 DWM 属性错误——能力探测正确识别 Win10 并门控 Win11 22000+ 专属属性调用（实机可观测：日志无 E_INVALIDARG，不崩溃）。
  2. 应用在 Win11 上启动时能力探测正确识别 build 22000+，使后续阶段的边框/圆角属性可生效（实机可观测：后续阶段属性生效）。
  3. C1 NCCALCSIZE 处理器的现有规范化结构（守卫注释 + `WS_OVERLAPPEDWINDOW` 样式检查 → 条件 `return 0`；单分支为规范形态——2026-09-02 用户裁决）有自动化回归 gate，折叠为裸 `return 0`（移除样式检查）时 gate 失败；全屏切换在 Win11 实机上无 8px 缝隙（实机 UAT）。
**Plans**: 2 plans

Plans:
- [ ] 06-01-PLAN.md — DwmCapabilities FFI probe (ENAB-01): RtlGetVersion build number + DwmGetWindowAttribute availability for 4 Win11 22000+ attributes, facade + ValueNotifier + D-04 failure reporting
- [ ] 06-02-PLAN.md — C1/C2 pinning gate (ENAB-02): gate script (GATE 1 C1 structure fingerprint + GATE 2 C2 VideoState.isFullscreen negative-grep) + real-hardware UAT checklist

### Phase 7: 去主题色边框

**Goal**: Win11 上窗口边缘无系统强调色描边，Win10 上接受 1px 主题色边框为已知平台差异（用户裁决），DWM 属性在主题/DPI/模式变化后重新应用不丢失。
**Depends on**: Phase 6 (capability probe gates all attribute calls)
**Requirements**: BORD-01, BORD-02, BORD-03
**Success Criteria** (what must be TRUE):
  1. Win11 上窗口边缘无系统强调色描边——将系统强调色设为红色后窗口边缘不为红色（实机 UAT：DWMWA_BORDER_COLOR=NONE 生效）。
  2. Win10 上 1px 主题色边框存在且被接受为已知平台差异，不尝试 WS_THICKFRAME 剥离或 DWMNCRP（文档化于 PROJECT.md Key Decisions）。
  3. 运行中切换 Windows 主题或 DPI 后，Win11 上边框属性重新应用——切换深色/浅色主题后边框仍被抑制（实机 UAT）。
  4. 进入和退出全屏后，Win11 上边框属性在 settle point 重新应用——无陈旧边框闪入（实机 UAT）。
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

### Phase 8: 圆角统一

**Goal**: 窗口四角符合 OS 约定——Win11 系统原生圆角，Win10 直角（与 Windows Terminal/VLC/VS Code 同款行业取舍），无透明分层窗口的视频性能代价。
**Depends on**: Phase 7 (ApplyChromeAttributes helper established)
**Requirements**: CORN-01, CORN-02
**Success Criteria** (what must be TRUE):
  1. Win11 上窗口四角为系统原生圆角，抗锯齿，视觉与 Windows Terminal 一致（实机 UAT：DWMWCP_ROUND 生效）。
  2. Win10 上窗口四角为直角，无透明分层窗口伪圆角（文档化平台差异，与 VLC/VS Code 同款取舍）。
  3. 视频播放性能不受影响——无 WS_EX_LAYERED，无逐像素合成代价（可观测：resize/帧时序基线与 phase 前无退化）。
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

### Phase 9: 标题栏拖拽可靠性

**Goal**: Windows 上拖拽自绘标题栏始终跟手——原生 HTCAPTION 命中测试消除偶发不跟手；双击最大化与按钮簇区域不触发拖拽；最大化状态下拖拽有守卫。
**Depends on**: Phase 6 (C1 pin — both touch WM_NCHITTEST/NCCALCSIZE region)
**Requirements**: DRAG-01, DRAG-02, DRAG-03
**Success Criteria** (what must be TRUE):
  1. Windows 上拖拽标题栏始终跟手——连续 20 次拖拽全部跟随指针，无漏拽事件（实机 UAT：HTCAPTION 原生模态拖拽循环）。
  2. 双击标题栏最大化/还原窗口正常工作；点击标题栏按钮（最小化/最大化/关闭）不启动拖拽。
  3. 窗口最大化时拖拽标题栏不脱离窗口（IsZoomed 守卫）。
  4. 非 Windows 平台保留现有 startDragging fallback 路径，无回归。
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

### Phase 10: 全屏过渡无闪烁

**Goal**: 进出全屏零可见闪烁——无标题栏闪现、无尺寸跳变、无纹理撕裂；退出全屏恢复进入前窗口模式（最大化↔窗口化）而非一律窗口化；全屏体验达产品级基线。
**Depends on**: Phase 6 (probe + C1 pin), Phase 7 (settle-point re-apply), Phase 9 (HTCAPTION stable)
**Requirements**: FSCR-01, FSCR-02, FSCR-03, FSCR-04, FSCR-05
**Success Criteria** (what must be TRUE):
  1. 进入全屏时标题栏即时隐藏（无渐隐闪现），退出全屏时标题栏渐隐恢复（实机 UAT）。
  2. 全屏过渡零可见闪烁——无标题栏闪现、无边框闪现、无尺寸跳变、无纹理撕裂，Win10 与 Win11 均通过（实机 UAT + textureIdChanges=0 探测）。
  3. 退出全屏恢复进入前窗口模式——进入前若为最大化则退出后回到最大化，非一律窗口化。
  4. 全屏体验对照 mpv/VLC/Windows Terminal 行为基线达产品级——即时切换、无动画竞争、几何正确（FSCR-05 产品级验收，含执行期交叉审查授权）。
  5. DWMWA_TRANSITIONS_FORCEDISABLED 在实机 spike 中通过 raster<33ms + 视觉无闪烁门则采纳，否则不作为默认提交（spike-gated，非承诺默认）。

**Constraints** (reverted-approaches denylist — 硬约束):
- 方案 A（FFI 桥）/ 方案 B（DWM 禁用 / DWMWA_NCRENDERING_POLICY）/ 全局 DWMNCRP / `window_manager.setFullScreen` 均为已撤回方案，禁止重提。
- 任何全屏 PR 须在设计文档首段声明其不是上述方案之一；重新考虑需实机 pilot + 针对具体失败的 documented delta。
- media_kit 红线仅对全屏功能解禁（FSCR-02 触及 media_kit_video/windows/utils.cc），其余部分不可改动。
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

### Phase 11: Linux 结构性实现与打磨

**Goal**: Linux 窗口外壳结构性正确（合成器分支、待实机验证），文档准确。
**Depends on**: Phase 6 (capability probe pattern), Phase 8 (corner path), Phase 10 (fullscreen structural pattern)
**Requirements**: ENAB-03, CORN-03, PLSH-01
**Success Criteria** (what must be TRUE):
  1. Linux 上应用启动时探测合成器（Wayland/X11/gamescope）并分支窗口外壳路径（结构性正确，待实机验证）。
  2. Linux borderless 场景 ClipRRect 回退路径产出结构性圆角（待实机验证）。
  3. Linux 全屏结构性路径（Wayland `xdg_toplevel.set_fullscreen` / X11 既有路径）按 window_manager Linux 插件源码正确实现，满足 FSCR-05 Linux 结构性正确同标准交付条款（待实机验证）。
  4. CLAUDE.md window_manager 版本由 "5.15.0" 修正为 "0.5.2"（PLSH-01，文档可观测）。
**Plans**: TBD

Plans:
- [ ] 11-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 6 → 7 → 8 → 9 → 10 → 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 6. 能力探测与 C1/C2 钉死 | 0/2 | Planning complete | - |
| 7. 去主题色边框 | 0/TBD | Not started | - |
| 8. 圆角统一 | 0/TBD | Not started | - |
| 9. 标题栏拖拽可靠性 | 0/TBD | Not started | - |
| 10. 全屏过渡无闪烁 | 0/TBD | Not started | - |
| 11. Linux 结构性实现与打磨 | 0/TBD | Not started | - |
