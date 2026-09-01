# Requirements: Simple Player — v1.1 窗口外观与全屏体验

**Defined:** 2026-09-01
**Core Value:** 窗口外壳完全自绘自治——系统主题、平台差异不得渗透到窗口视觉与交互

## Milestone v1.1 Requirements

### 使能层

- [ ] **ENAB-01**: 启动时一次性 `DwmCapabilities` 探测（Windows build number + borderColor/cornerPreference 等属性可用性布尔），所有 DWM 属性调用以其为门，Win10 上绝不调用 Win11 22000+ 专属属性
- [ ] **ENAB-02**: C1 缝隙修复钉死——`WM_NCCALCSIZE` 多分支处理器（fullscreen→8px inset / maximized→overshoot / default→return 0）附回归测试 + 守卫注释，后续任何 chrome 工作不得使其回归
- [ ] **ENAB-03**: Linux 合成器探测（Wayland/X11/gamescope）结构性实现

### 边框

- [ ] **BORD-01**: Win11 上窗口边缘无系统强调色描边（`DWMWA_BORDER_COLOR = DWMWA_COLOR_NONE`，build 22000+ 门控）
- [ ] **BORD-02**: Win10 上接受 1px 主题色边框为已知平台差异（用户裁决 2026-09-01 选项1；文档化于 PROJECT.md Key Decisions，不做强行去除）
- [ ] **BORD-03**: DWM 属性在主题/DPI/模式变化后重新应用（settle-point 重应用：启动 + `WM_THEMECHANGED` + `WM_DPICHANGED` + 全屏落定后）

### 圆角

- [ ] **CORN-01**: Win11 上窗口四角为系统原生圆角（`DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND`）
- [ ] **CORN-02**: Win10 接受直角（Windows Terminal/VLC/VS Code 同款行业取舍，文档化平台差异）
- [ ] **CORN-03**: Linux 通用桌面结构性圆角路径（borderless 场景 `ClipRRect` 回退；标记待实机验证）

### 全屏

- [ ] **FSCR-01**: 进入全屏时标题栏即时隐藏（消除渐隐与异步 resize 的竞态），退出时渐隐恢复
- [ ] **FSCR-02**: media_kit 全屏 `SetWindowPos` 加 `SWP_NOCOPYBITS` + 全屏态 `WM_NCPAINT` 抑制（红线解禁范围内，仅限全屏功能）
- [ ] **FSCR-03**: 退出全屏恢复进入前的窗口模式（最大化↔窗口化），而非一律窗口化
- [ ] **FSCR-04**: 进/出全屏过渡零可见闪烁（实机 UAT 验收 + `textureIdChanges` 探测）
- [ ] **FSCR-05**: 全屏体验达到成熟播放器产品级——对照 mpv/VLC/Windows Terminal 行为基线；执行期授权使用编程插件与 skills（code-reviewer/feature-dev 等）交叉审查；Win10/Win11 实机验收，Linux 结构性正确同标准交付

### 拖拽

- [ ] **DRAG-01**: Windows 上标题栏拖拽改走原生 `HTCAPTION` 命中测试（`WM_NCHITTEST` → `SC_MOVE` 模态拖拽循环），偶发不跟手消除
- [ ] **DRAG-02**: 双击最大化与拖拽共存；标题栏按钮簇区域不触发拖拽；最大化状态下拖拽守卫（`IsZoomed`）
- [ ] **DRAG-03**: 非 Windows 平台保留现有拖拽路径（`startDragging` fallback）

### 打磨

- [ ] **PLSH-01**: 文档修正 window_manager 版本笔误（CLAUDE.md 5.15.0 → 实际 0.5.2）

## Future Requirements (deferred)

- **CORNR-01**: corner-preference 用户设置项（round/square，Win11 only）
- **MAC-01**: macOS 窗口外壳验证（结构性支持已存在，非发布目标）
- **MULTI-01**: 多显示器全屏几何恢复
- **WIN10-ROUND-01**: Win10 伪圆角（当前为反模式，除非用户日后明确要求）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 全屏后边缘有缝修复 | 已解决（C1），本里程碑钉死防回归，不重开 |
| 全局 DWMNCRP 方案 | 2026-08-27 实机撤回，用户红线「勿重提」 |
| 方案A（FFI 桥）/ 方案B（DWM 禁用）全屏样式 | 2026-08-27 实机 revert |
| `window_manager.setFullScreen` | frameless 下 no-op（`is_frameless_` guard）；上游 PR #531 存在未修回归 #579 |
| Win10 伪圆角（透明分层窗口） | 所有成熟软件均接受 Win10 直角；`WS_EX_LAYERED` 禁用 DXGI flip 模型，视频性能不可接受 |
| 自绘全屏进/出动画 | 动画与过渡竞争（VLC/mpv 均即时切换） |
| 自绘拖拽（mouse-move + SetWindowPos） | 丢失 Snap Layout/多显示器/DPI/Aero Peek |
| media_kit 非全屏部分修改 | 红线仅为全屏功能解禁 |
| 播放功能演进 | 与窗口外壳无关 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENAB-01 | Phase 6 | Pending |
| ENAB-02 | Phase 6 | Pending |
| ENAB-03 | Phase 11 | Pending |
| BORD-01 | Phase 7 | Pending |
| BORD-02 | Phase 7 | Pending |
| BORD-03 | Phase 7 | Pending |
| CORN-01 | Phase 8 | Pending |
| CORN-02 | Phase 8 | Pending |
| CORN-03 | Phase 11 | Pending |
| FSCR-01 | Phase 10 | Pending |
| FSCR-02 | Phase 10 | Pending |
| FSCR-03 | Phase 10 | Pending |
| FSCR-04 | Phase 10 | Pending |
| FSCR-05 | Phase 10 | Pending |
| DRAG-01 | Phase 9 | Pending |
| DRAG-02 | Phase 9 | Pending |
| DRAG-03 | Phase 9 | Pending |
| PLSH-01 | Phase 11 | Pending |

**Coverage:**
- v1.1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-01*
*Last updated: 2026-09-02 after roadmap creation*
