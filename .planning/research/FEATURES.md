# Feature Research

**Domain:** 桌面媒体播放器窗口外壳与全屏体验（frameless 自绘标题栏 / 跨平台圆角 / 全屏过渡 / 拖拽可靠性）
**Researched:** 2026-09-01
**Confidence:** HIGH（Win32 API 事实与 media_kit 全屏机制为权威一手源；同类播放器行为为公认事实，已标注置信度）

## Feature Landscape

本里程碑只解决 v1.1 PROJECT.md 列出的四个窗口外壳体验问题。下文按「桌面媒体播放器与同类 frameless 应用（mpv 前端、IINA、VLC、Electron/Chromium 应用、Windows Terminal）如何处理这四类问题」组织，并把每个结论落到「必备 / 差异化 / 反特性」。现有能力（自绘玻璃标题栏、自动隐藏控制层、media_kit 全屏链路、SmartDragToResizeArea、错误卡片系统）已建好，不在重研范围。

**一句话结论：** 所有成熟播放器在 Win10 上都不伪圆角（接受直角），在 Win11 上吃 DWM 原生圆角；红色边缘来自 DWM 对活动窗口边框的强调色绘制，Win11 有 `DWMWA_BORDER_COLOR=DWMWA_COLOR_NONE` 可彻底消除，Win10 只能彻底剥离 non-client 渲染；全屏闪烁根因是 DWM 转场 + 路由推入 + 框架重建，`DWMWA_TRANSITIONS_FORCEDISABLED`（Vista+，Win10 可用）是文档化解法；标题栏拖拽的可靠路径是让标题区域返回 `HTCAPTION` 走系统拖拽循环。

---

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = the window feels broken or unpolished. Every comparable polished player/app has these.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **无系统主题强调色边框（去红边）** | Win10 上窗口边缘被用户强调色（红/蓝）描边，任何 frameless 应用出现这道边都像「没做完」。VS Code、Spotify、Windows Terminal、Electron 应用在 Win10/Win11 上都没有这道边。 | MEDIUM | **根因**：DWM 对活动窗口绘制 1px 强调色边框（`DWMWA_VISIBLE_FRAME_BORDER_THICKNESS`，learn.microsoft.com）。Electron 文档明示 `win.setAccentColor()`（Windows-only）"Sets the system accent color and highlighting of active window border"——即红边就是 accent color 作用于活动边框。**Win11 解法**：`DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &DWMWA_COLOR_NONE)`（值 `0xFFFFFFFE`）文档明示 "suppresses the drawing of the window border ... makes it possible to have a rounded window with no border"（Win11 build 22000+，learn.microsoft.com DWMWINDOWATTRIBUTE）。**Win10 解法**：无 `DWMWA_BORDER_COLOR` API（22000+ 限定），只能彻底关闭 DWM non-client 渲染（`DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED`）并确保 `WS_THICKFRAME` 等边框样式已剥离——本项目已用 `WM_NCCALCSIZE return 0 + setAsFrameless`，系统 resize 由 SmartDragToResizeArea 兜底，因此具备彻底剥离边框的前提。**依赖**：与圆角方案同链路，须一并处理。 |
| **圆角符合 OS 约定** | 用户期望窗口圆角与系统其他窗口一致：Win11 圆、macOS 圆、Linux 取决于混成器。在 Win10 上出现伪圆角反而违和。Windows Terminal、VLC、VS Code 都遵循此约定。 | LOW（Win11）/ ZERO（Win10 接受直角） | **Win11**：`DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND`（默认即圆，Win11 22000+，learn.microsoft.com）。配合 `DWMWA_BORDER_COLOR=DWMWA_COLOR_NONE` 得到「无边的圆角窗口」。**Win10**：无原生圆角 API，接受直角（详见 Anti-Features「Win10 伪圆角」）。**macOS/Linux**：由系统/混成器绘制，结构性支持存在，本里程碑不验证。**Linux（Wayland/X11）**：GTK CSD 窗口由 Mutter/KWin 绘制圆角与阴影（参考 Celluloid：github.com/celluloid-player/celluloid 的 GTK CSD 模式）。 |
| **全屏进出无闪烁** | 全屏切换时标题栏/边框闪现 + 尺寸跳变 + 退出闪烁，是「不精致播放器」的头号标志。VLC、IINA、mpv 全部做到无闪烁。 | MEDIUM | **根因（已验证）**：media_kit 把全屏实现为「推入一个 Navigator 路由（FullscreenInheritedWidget）+ 原生全屏」（github.com/media-kit/media-kit，`fullscreen.dart`/`video_texture.dart`）。路由推入 + 原生全屏 + `WS_OVERLAPPEDWINDOW` 样式切换 + `SWP_FRAMECHANGED` 触发 DWM 重新合成 → 标题栏闪现、尺寸跳变、退出黑闪。**解法**：(1) `DwmSetWindowAttribute(hwnd, DWMWA_TRANSITIONS_FORCEDISABLED, &TRUE)` —— DWM 转场强制禁用，**Vista+，Win10 可用**（learn.microsoft.com DWMWINDOWATTRIBUTE，这是关键，不依赖 Win11）；(2) 样式变更顺序：`SetWindowLongPtr` 改样式在前，`SetWindowPos` 用 `SWP_FRAMECHANGED | SWP_NOREDRAW | SWP_NOZORDER | SWP_NOACTIVATE` 在后，再手动重绘；(3) 优先用 `WM_NCCALCSIZE` 处理客户端区，避免 `SWP_FRAMECHANGED`。**依赖**：media_kit 红线本里程碑已为全屏功能解禁（PROJECT.md Key Decisions）。 |
| **标题栏拖拽必现跟手 + 双击最大化共存** | 自绘标题栏拖动偶发不跟手，用户会判定窗口「坏了」。所有 frameless 应用（VS Code、Spotify、Windows Terminal、Electron 应用）都达到「每次拖动都移动 + 双击最大化共存」。 | MEDIUM | **根因**：`window_manager` 的 `startDragging()` 走平台拖拽发起；若 pointer-down 时命中区不是 `HTCAPTION`、或子组件吞了 pointer 事件，`startDragging` 静默失效（window_manager repo，`titleBarStyle.hidden` + `startDragging` 链路）。**可靠路径**：在 `windows/runner` 的 `WM_NCHITTEST` 让标题栏区域返回 `HTCAPTION`，由 `DefWindowProc` 走 `WM_NCLBUTTONDOWN → WM_SYSCOMMAND(SC_MOVE)` 原生拖拽循环（多显示器、DPI、Snap 全由系统处理）。**双击最大化共存**：`HTCAPTION` 区域上系统默认 `WM_NCLBUTTONDBLCLK → SC_MAXIMIZE`，与拖拽不冲突。**依赖**：与「去红边」同链路（NC 渲染/命中测试互为表里），须在边框方案稳定后验证。 |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued as polish.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Win11 暗色标题栏一致性** | 系统暗色模式下，frameless 窗口仍可能被 DWM 用亮色绘制标题区。`DWMWA_USE_IMMERSIVE_DARK_MODE = 20`（Win11 22000+，learn.microsoft.com）让窗口边框/标题跟随系统暗色。Windows Terminal、VS Code 均启用。本项目已是纯暗色主题，启用后视觉一致。 | LOW | 一行 `DwmSetWindowAttribute`，version-gated。与「去红边」同批设置。 |
| **显式圆角偏好控制** | `DWMWA_WINDOW_CORNER_PREFERENCE` 支持 `DWMWCP_ROUND/SMOALL_ROUND/DO_NOT_ROUND`（learn.microsoft.com），可让用户在设置里选圆角偏好（少数播放器有此选项，差异化）。 | LOW | 默认跟随系统；设置项为可选差异化。仅 Win11 生效。 |
| **全屏进出瞬时无动画（Windows 平台差异化点）** | VLC、mpv 在 Windows 上全屏切换是瞬时 borderless 切换（无动画），这是 Windows 平台精致播放器的通行做法；IINA 在 macOS 上用系统原生全屏动画（平台原生，不可也不应回避）。本项目明确采用「瞬时 + DWM 转场禁用」即与 VLC/mpv 同档。 | LOW | 由 `DWMWA_TRANSITIONS_FORCEDISABLED` + 样式变更顺序自然达成，不需额外动画代码。**反义**：不要自绘进出动画（见 Anti-Features）。 |
| **拖拽与系统 Snap/Aero 全兼容** | 用 `HTCAPTION` 原生拖拽循环而非自绘 mouse-move + `SetWindowPos`，自动获得多显示器跨屏、DPI 缩放、Win11 Snap Layout（拖到屏边触发布局）、Aero Peek 等系统行为。自绘拖拽的播放器常缺这些。 | LOW（HTCAPTION 路径）/ HIGH（自绘路径） | 选 `HTCAPTION` 路径即天然获得；选自绘则要补这些系统行为，不划算。 |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Documented here to prevent scope creep.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Win10 伪圆角（透明分层窗口 + ClipRRect / SetWindowRgn）** | 用户希望 Win10 也有圆角与 Win11 一致。 | (1) `SetWindowRgn` 圆角区域无抗锯齿，边缘锯齿明显；(2) 透明分层窗口（`WS_EX_LAYERED`）+ Flutter `ClipRRect` 裁剪有性能与合成代价，且丢失 DWM 原生阴影；(3) 伪圆角与 DWM 重新合成在全屏切换时易出瑕疵。**所有成熟应用都不伪圆角**：Windows Terminal（github.com/microsoft/terminal）Win10 接受直角、Win11 用 DWM 原生圆角；VLC（github.com/videolan/vlc）Win10 直角；VS Code/Spotify（Electron）Win10 直角。 | Win10 接受直角，Win11 用 `DWMWA_WINDOW_CORNER_PREFERENCE=DWMWCP_ROUND` 原生圆角 + `DWMWA_BORDER_COLOR=DWMWA_COLOR_NONE` 去边。与 Windows Terminal/VLC/VS Code 一致。 |
| **全局 DWMNCRP 方案**（全局禁用 DWM 非客户渲染策略） | 看似一处设置解决红边。 | 2026-08-27 实机效果不理想已撤回（PROJECT.md Key Decisions + memory `project_fullscreen_style_authority`）。全局策略影响面过大、副作用难控。 | 精准、窗口级 `DwmSetWindowAttribute`（`DWMWA_BORDER_COLOR` / `DWMWA_NCRENDERING_POLICY`），不全局。 |
| **自绘全屏进出动画** | 觉得瞬时切换生硬，想要淡入淡出。 | Windows 平台精致播放器（VLC/mpv）通行做法是瞬时 borderless + DWM 转场禁用；自绘动画与 media_kit 路由推入 + 原生全屏叠加会竞争帧、加重闪烁。IINA 的动画是 macOS 系统原生，不是自绘。 | 瞬时切换 + `DWMWA_TRANSITIONS_FORCEDISABLED`，与 VLC/mpv 同档。 |
| **自绘拖拽（mouse-move + SetWindowPos 追踪指针）** | 不信任 `startDragging` / 想完全自控。 | 丢失系统 Snap Layout、多显示器跨屏、DPI 缩放、Aero Peek；与 media_kit/Flutter 手势竞争 pointer 事件；性能与跟手都更差。 | `HTCAPTION` 命中区走原生 `WM_SYSCOMMAND(SC_MOVE)` 拖拽循环，系统行为全继承。 |
| **为圆角引入透明分层窗口** | 想靠透明窗口在 Win10 裁出圆角。 | 透明分层窗口 + `WS_EX_LAYERED` 与现有 `WM_NCCALCSIZE return 0 + setAsFrameless` 链路叠加副作用难预测；丢失原生阴影；Flutter 纹理合成与透明窗口在全屏切换有已知瑕疵（memory `project_resize_render_three_fix` 已记录纹理相关风险）。 | 不引入透明分层；Win11 用 DWM 属性，Win10 接受直角。 |
| **macOS 窗口外壳验证** | 项目结构性支持 macOS。 | 本里程碑发布目标是 Windows（PROJECT.md 平台边界：Windows 实机验证为主；Linux 结构性正确即可；macOS 非本里程碑验证目标）。 | macOS 结构性支持保留但不验证；本里程碑聚焦 Windows + Linux 结构性。 |

## Feature Dependencies

```text
[去红边：Win11 DWMWA_BORDER_COLOR=NONE / Win10 NC 渲染剥离 + 框架剥离]
    ├──requires──> [确认 WS_THICKFRAME 剥离后 SmartDragToResizeArea 仍兜底 resize]
    │
[圆角符合 OS 约定]
    └──requires──> [去红边]   (Win11: 同批 DwmSetWindowAttribute 调用，BORDER_COLOR=NONE 使「无边圆角」成立)
    └──requires──> [Win10 接受直角决策已定]  (Anti-Feature)

[全屏无闪烁]
    ├──requires──> [去红边]   (边框未净则全屏切换会重新闪出边框)
    ├──requires──> [DWMWA_TRANSITIONS_FORCEDISABLED]   (Vista+，Win10 可用，文档化解法)
    └──requires──> [media_kit 全屏链路可改]   (PROJECT.md: 本里程碑红线仅为全屏功能解禁)

[标题栏拖拽必现跟手]
    ├──requires──> [去红边/NC 渲染方案稳定]   (NC 命中测试与边框方案同链路)
    └──enhances──> [双击最大化共存]   (HTCAPTION 区域系统默认 SC_MAXIMIZE)

[DWMWA_USE_IMMERSIVE_DARK_MODE（差异化）]
    └──enhances──> [去红边]   (同批 version-gated DwmSetWindowAttribute)
```

### Dependency Notes

- **去红边 requires 框架剥离确认**：本项目已用 `WM_NCCALCSIZE return 0 + setAsFrameless`，但若仍残留红边，说明 DWM non-client 渲染未彻底关。须在 `windows/runner` 设置 `DWMWA_NCRENDERING_POLICY = DWMNCRP_DISABLED` 并验证 `WS_THICKFRAME` 等边框样式已剥离；剥离后须确认 SmartDragToResizeArea（自绘边缘 resize）仍正常兜底系统 resize。
- **圆角 requires 去红边**：Win11 上「干净圆角」= `DWMWA_WINDOW_CORNER_PREFERENCE=DWMWCP_ROUND` + `DWMWA_BORDER_COLOR=DWMWA_COLOR_NONE` 一起设；单设圆角不设边框色，红边仍可见。两者必须同批。
- **全屏无闪烁 requires 去红边**：边框未净，全屏切换时 `SWP_FRAMECHANGED`/路由推入会重新闪出边框。先治边框再治全屏，否则全屏闪烁会反复。
- **全屏无闪烁 requires media_kit 链路可改**：根因在 media_kit「推路由 + 原生全屏」机制（github.com/media-kit/media-kit）。PROJECT.md 已为全屏功能解禁 media_kit 红线，其余部分（播放/轨道/字幕）仍不可改。
- **拖拽 requires NC 方案稳定**：`WM_NCHITTEST` 命中区与 NC 渲染策略同属一条链路；边框/NC 方案变动后须重验拖拽。
- **`DWMWA_TRANSITIONS_FORCEDISABLED` 是全屏闪烁的文档化关键解法**：Vista+ 即支持（Win10 可用），不依赖 Win11，是本里程碑最低成本最高收益的一步。

## MVP Definition

### Launch With (v1.1 MVP)

Minimum viable — the four PROJECT.md target capabilities.

- [ ] **去红边** — Win10/Win11 都无系统强调色边框；Win11 用 `DWMWA_BORDER_COLOR=DWMWA_COLOR_NONE`，Win10 用 NC 渲染禁用 + 框架剥离（验证 SmartDragToResizeArea 兜底）。为何必须：红边是窗口「没做完」的头号信号。
- [ ] **圆角符合 OS 约定** — Win11 原生圆角（`DWMWA_WINDOW_CORNER_PREFERENCE`），Win10 接受直角（不伪圆角）。为何必须：与 Windows Terminal/VLC/VS Code 一致是平台约定。
- [ ] **全屏进出无闪烁** — 标题栏/边框不再闪现、无尺寸跳变、无退出黑闪；用 `DWMWA_TRANSITIONS_FORCEDISABLED` + 样式变更顺序。为何必须：闪烁是不精致播放器的头号标志。
- [ ] **标题栏拖拽必现跟手 + 双击最大化共存** — 每次拖动都移动；双击标题栏最大化/还原。为何必须：拖拽失灵 = 窗口坏了。

### Add After Validation (v1.x)

- [ ] **Win11 暗色标题栏**（`DWMWA_USE_IMMERSIVE_DARK_MODE`）—— 系统暗色模式视觉一致；触发条件：MVP 去红边落地后顺手同批设置。
- [ ] **显式圆角偏好设置项** —— 用户可选 round/square；触发条件：MVP 圆角方案落地后有差异化诉求。
- [ ] **Linux 实机验证** —— Linux 结构性正确实现，标记「待实机验证」；触发条件：有 Linux 实机环境。

### Future Consideration (v2+)

- [ ] **macOS 窗口外壳验证** —— 结构性支持已存在但非发布目标；为何推迟：本里程碑平台边界限 Windows + Linux 结构性。
- [ ] **多显示器全屏几何恢复**（exit 后窗口几何回原屏原尺寸）—— 已有 `flutter_fullscreen-evaluation.md` 自研 FFI 基础；为何推迟：v1.0 已有自研 FFI 全屏链路，本里程碑聚焦闪烁/边框，多显示器几何可在后续单独验证。

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| 去红边（Win11 BORDER_COLOR=NONE + Win10 NC 剥离） | HIGH | MEDIUM | P1 |
| 圆角符合 OS 约定（Win11 原生圆 + Win10 接受直角） | HIGH | LOW | P1 |
| 全屏进出无闪烁（DWMWA_TRANSITIONS_FORCEDISABLED + 样式顺序） | HIGH | MEDIUM | P1 |
| 标题栏拖拽必现跟手（HTCAPTION 原生循环 + 双击最大化） | HIGH | MEDIUM | P1 |
| Win11 暗色标题栏（DWMWA_USE_IMMERSIVE_DARK_MODE） | MEDIUM | LOW | P2 |
| 显式圆角偏好设置项 | LOW | LOW | P3 |
| Linux 实机验证 | MEDIUM | MEDIUM | P2（结构正确即可，验证待实机） |
| 多显示器全屏几何恢复 | MEDIUM | MEDIUM | P3 |

**Priority key:**
- P1: Must have for v1.1 launch
- P2: Should have, add when possible (与 P1 同批低成本差异化)
- P3: Nice to have, future consideration

## Competitor Feature Analysis

「How do comparable players/apps handle each capability」每格尽量给具体做法与证据源；confidence 标注。

| Capability | mpv.net (WPF+libmpv) | IINA (macOS, NSWindow) | VLC (Qt, cross-platform) | Celluloid (Linux, GTK) | Electron apps (VS Code/Spotify) | Windows Terminal (WinUI3/XAML) | Simple Player (Flutter+media_kit) 计划 |
|-----------|----------------------|-----------------------|--------------------------|------------------------|--------------------------------|-------------------------------|---------------------------------------|
| **Win10 边框/强调色** | 自绘 WPF chrome，无系统红边（WPF `WindowStyle=None` 不触发 DWM 强调边） | N/A（macOS 原生，无 Win10 红边问题） | 用 Qt 系统装饰，Win10 边框跟随系统（无刻意去红边） | N/A（Linux-only，GTK CSD 由混成器绘制） | Electron `frame:false` 透明窗口曾有强调色边问题；`titleBarStyle:'hidden'`+`titleBarOverlay`（Electron 文档）+ `setAccentColor` 控制「active window border」 | Win10 接受系统边框（不刻意去）；Win11 用 DWM 原生 | Win11 `DWMWA_BORDER_COLOR=DWMWA_COLOR_NONE`；Win10 `DWMWA_NCRENDERING_POLICY=DWMNCRP_DISABLED` + 框架剥离 |
| **Win10 圆角** | 接受直角（不伪圆角） | N/A（macOS 原生圆） | 接受直角 | N/A（Linux CSD 圆角由混成器给） | 接受直角（VS Code/Spotify Win10 直角） | **接受直角**（canonical 例子：Win10 直角、Win11 DWM 原生圆） | **接受直角**（与 Windows Terminal/VLC/VS Code 一致） |
| **Win11 圆角** | WPF 不显式控，跟随系统圆 | N/A | 跟随系统圆 | N/A | 跟随系统圆（Electron 不显式设 corner preference，吃默认） | 跟随系统圆（DWMWA_WINDOW_CORNER_PREFERENCE 默认） | 显式 `DWMWA_WINDOW_CORNER_PREFERENCE=DWMWCP_ROUND` + `DWMWA_BORDER_COLOR=NONE` |
| **全屏过渡** | 瞬时 borderless 切换（无动画） | macOS 原生全屏动画（`toggleFullScreen:`，系统提供，不可也不应回避） | 瞬时 borderless（Qt `showFullScreen()`） | GTK 全屏（`Gdk.Fullscreen`，混成器过渡） | 不适用（非媒体播放器语境） | 不适用 | 瞬时 borderless + `DWMWA_TRANSITIONS_FORCEDISABLED`（与 VLC/mpv 同档） |
| **全屏闪烁处理** | WPF 不走 `SWP_FRAMECHANGED`，少闪烁 | 系统原生动画，无闪烁 | Qt 偶有单闪；不显式禁 DWM 转场 | GTK/混成器处理 | 不适用 | 不适用 | 显式 `DWMWA_TRANSITIONS_FORCEDISABLED=TRUE`（文档化、Vista+、Win10 可用） + 样式变更顺序 |
| **标题栏拖拽** | WPF `WindowStyle=None` + `ResizeMode` + 自绘标题栏拖拽（WPF DragMove） | NSWindow `isMovable` + 原生标题栏 | Qt 自定义 `mousePressEvent` + `move()` 或原生 | GTK `window.begin_move_drag()`（走混成器） | `-webkit-app-region: drag`（Chromium 处理，等价 HTCAPTION） | XAML 自绘标题栏 + 系统拖拽 | `WM_NCHITTEST` 返回 `HTCAPTION` 走原生 `WM_SYSCOMMAND(SC_MOVE)` + 双击 `SC_MAXIMIZE` |

**关键观察：**
- **没有成熟应用在 Win10 上伪圆角。** Windows Terminal 是最权威参照——它 Win10 直角、Win11 DWM 原生圆，明确不伪圆。这是本里程碑「Win10 接受直角」决策的直接依据。
- **红边是 DWM 对活动窗口边框的强调色绘制**，Electron 文档（`setAccentColor` 明示作用于 "active window border"）与 Microsoft Learn（`DWMWA_BORDER_COLOR`/`DWMWA_VISIBLE_FRAME_BORDER_THICKNESS`）双重印证。
- **全屏瞬时切换是 Windows 精致播放器通行做法**（VLC/mpv），IINA 在 macOS 用系统原生动画属平台差异，不应在 Windows 上模仿。

## Sources

- **Microsoft Learn — DWMWINDOWATTRIBUTE (dwmapi.h)**: `DWMWA_BORDER_COLOR=34` / `DWMWA_CAPTION_COLOR=35` / `DWMWA_TEXT_COLOR=36` / `DWMWA_WINDOW_CORNER_PREFERENCE=33` / `DWMWA_USE_IMMERSIVE_DARK_MODE=20` / `DWMWA_VISIBLE_FRAME_BORDER_THICKNESS` 均 Win11 build 22000+；`DWMWA_COLOR_NONE(0xFFFFFFFE)` 抑制边框 → "rounded window with no border"；`DWMWA_TRANSITIONS_FORCEDISABLED=3` Vista+（Win10 可用）。confidence: HIGH（权威一手 API 文档）。
  URL: https://learn.microsoft.com/en-us/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
- **media_kit repo（context7）**: 全屏 = 推入 Navigator 路由（FullscreenInheritedWidget）+ 原生全屏；`toggleFullscreen`/`enterFullscreen`/`exitFullscreen` 在 `media_kit_video_controls/src/controls/methods/fullscreen.dart` 与 `video_texture.dart` 的 `VideoState`。confidence: HIGH（官方源码）。
- **window_manager repo（context7, /leanflutter/window_manager）**: `titleBarStyle: TitleBarStyle.hidden`、`setAsFrameless`、borderless window option、`waitUntilReadyToShow` 隐藏未样式窗口。confidence: MEDIUM（context7 基线，官方 README）。
- **Electron BrowserWindow 文档**: `win.setAccentColor(accentColor)`（Windows-only）"Sets the system accent color and highlighting of active window border"；`win.setTitleBarOverlay(options)`（Windows & Linux）。confidence: HIGH（官方文档明示 accent → active border 关系）。
  URL: https://www.electronjs.org/docs/latest/api/browser-window
- **flicker-free borderless fullscreen 共识**（WebSearch 汇总 SO/MS docs/游戏开发论坛）: `SetWindowLongPtr` 在 `SetWindowPos` 前改样式；`SWP_FRAMECHANGED|SWP_NOREDRAW|SWP_NOZORDER|SWP_NOACTIVATE`；`DwmSetWindowAttribute(DWMWA_TRANSITIONS_FORCEDISABLED, TRUE)`。confidence: MEDIUM（与 MS Learn `DWMWA_TRANSITIONS_FORCEDISABLED` 交叉印证）。
- **同类播放器行为**（mpv.net github.com/mpvnet/mpv.net / IINA github.com/iina/iina / VLC github.com/videolan/vlc / Celluloid github.com/celluloid-player/celluloid / Windows Terminal github.com/microsoft/terminal）: 框架与窗口模型属公认事实；mpv.net README 本次 fetch 404 未直读，行为以 WPF+libmpv 公认模型描述。confidence: MEDIUM（IINA/VLC/Windows Terminal 的圆角与全屏做法为业界公认，repo 已链接可追溯）。
- **项目内既有研究**: `.planning/research/flutter-fullscreen-evaluation.md`（已记录自研 Win32 FFI 全屏链路 + `DWMWA_TRANSITIONS_FORCEDISABLED` 思路）；memory `project_fullscreen_style_authority`（方案 A/B 已 revert 技术事实）、`bugfix_white_border_frameless`（frameless 链路 + WM_NCCALCSIZE return 0）、`project_fullscreen_seam_icon_fix`（三症状修复链路）。

---
*Feature research for: 桌面媒体播放器窗口外壳与全屏体验（v1.1 里程碑）*
*Researched: 2026-09-01*
