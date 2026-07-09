# Requirements: Player Fullscreen

**Defined:** 2026-07-09
**Core Value:** 全屏切换在任何场景下都稳定可靠

## v1 Requirements

### 状态模型 (STATE)

- [ ] **STATE-01**: FullscreenSnapshot 包含 isFullscreen、phase(stable/entering/leaving/forcedChange/error)、effectiveMode、restoreMode、displayId、lastError
- [ ] **STATE-02**: UI 通过 ValueListenable<FullscreenSnapshot> 查询当前全屏状态，不依赖插件回调
- [ ] **STATE-03**: 每个 windowId 独立状态容器，多窗口互不污染

### 事件系统 (EVT)

- [ ] **EVT-01**: FullscreenEvent 流包含 enterRequested/entered/leaveRequested/left/forcedChange/syncCorrected/error
- [ ] **EVT-02**: 业务层通过 Stream<FullscreenEvent> 监听全屏生命周期，不直接依赖 _WindowListener
- [ ] **EVT-03**: forcedChange 事件携带原始状态和实际状态的差异信息

### 错误处理 (ERR)

- [ ] **ERR-01**: FullscreenError 枚举包含 Unsupported/InvalidWindow/PermissionDenied/BusyTransition/PlatformFailure/RestoreFailure/StateDesync
- [ ] **ERR-02**: 每次全屏操作失败都通过 error 事件通知 UI，不静默吞错
- [ ] **ERR-03**: UI 对 PermissionDenied（Web 手势拒绝）和 Unsupported 有明确用户提示

### 命令队列 (CMD)

- [ ] **CMD-01**: per-window 命令队列，同一 windowId 只允许一个 in-flight 命令
- [ ] **CMD-02**: 连续两次相同目标命令合并为一次，避免重复原生调用
- [ ] **CMD-03**: 原生执行完成后回读真实状态，若与目标不一致发出 StateDesync

### 恢复策略 (RST)

- [ ] **RST-01**: windowed→fullscreen→exit 恢复到最近一次普通窗口几何
- [ ] **RST-02**: maximized→fullscreen→exit 恢复到 maximized（不是 windowed）
- [ ] **RST-03**: 副屏→fullscreen→exit 恢复到副屏原始位置和大小
- [ ] **RST-04**: minimized 状态不直接切全屏，先恢复窗口再进入

### 平台适配 (PLAT)

- [ ] **PLAT-01**: Windows — WS_THICKFRAME 样式正确剥离和恢复，焦点恢复，TopMost 残留清理
- [ ] **PLAT-02**: macOS — 等待系统 fullscreen 生命周期回调确认状态，不乐观更新
- [ ] **PLAT-03**: Linux — GTK/WM 差异下的状态回读与兜底同步
- [ ] **PLAT-04**: FullscreenCapability 查询每平台支持的能力（多窗口/多显示器/手势限制）

### 架构边界 (ARCH)

- [ ] **ARCH-01**: FullscreenAdapter 接口独立于 WindowBridge，UI 只依赖 FullscreenAdapter
- [ ] **ARCH-02**: WindowBridge 继续负责通用窗口操作（setAlwaysOnTop/setAspectRatio/minimize/close）
- [ ] **ARCH-03**: 旧 fullscreen_window 调用点渐进迁移到 FullscreenAdapter，保留 feature flag fallback

## v2 Requirements

### Web/Mobile 对齐

- **WEB-01**: Web 用户手势限制明确报 PermissionDenied 错误
- **MOB-01**: Android/iOS 系统 UI 模式与播放器控件状态同步

### 高级能力

- **MULTI-01**: 真正的多窗口全屏支持（windowId 参数生效）
- **DISP-01**: 多显示器感知（displayId 参数生效）
- **ANIM-01**: 全屏过渡动画统一

## Out of Scope

| Feature | Reason |
|---------|--------|
| 独立 pub 包 | 先在项目内完成抽象层，稳定后再考虑 |
| 复杂全屏动画 | 第一阶段聚焦状态正确性 |
| 遥测平台 | 只保留事件与错误码接口 |
| Web/Mobile 深度适配 | 桌面优先，Web/Mobile 降级 |
| win32 包依赖 | 用户确认导致全屏一帧卡顿 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STATE-01 | Phase A | Pending |
| STATE-02 | Phase A | Pending |
| STATE-03 | Phase A | Pending |
| EVT-01 | Phase A | Pending |
| EVT-02 | Phase A | Pending |
| EVT-03 | Phase A | Pending |
| ERR-01 | Phase A | Pending |
| ERR-02 | Phase A | Pending |
| ERR-03 | Phase A | Pending |
| CMD-01 | Phase B | Pending |
| CMD-02 | Phase B | Pending |
| CMD-03 | Phase B | Pending |
| RST-01 | Phase B | Pending |
| RST-02 | Phase B | Pending |
| RST-03 | Phase B | Pending |
| RST-04 | Phase B | Pending |
| PLAT-01 | Phase C | Pending |
| PLAT-02 | Phase C | Pending |
| PLAT-03 | Phase C | Pending |
| PLAT-04 | Phase C | Pending |
| ARCH-01 | Phase A | Pending |
| ARCH-02 | Phase A | Pending |
| ARCH-03 | Phase B | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-07-09*
*Last updated: 2026-07-09 after initial definition*
