---
status: investigating
trigger: "只读分析 D:\\simple_player_flutter 的 Windows frameless/window bridge/C++ runner 与全屏相关实现。结合当前 git 工作区修改，定位全屏时白边/边框缝隙可能的根因及最小修复方案。不要改文件；指出准确文件和函数。"
created: 2026-08-03T05:57:49Z
updated: 2026-08-03T05:57:49Z
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: Confirmed: window_manager intercepts WM_NCCALCSIZE before FlutterWindow::MessageHandler. waitUntilReadyToShow applies TitleBarStyle.hidden, whose native SetTitleBarStyle forcibly clears is_frameless_. The plugin then takes its hidden/non-maximized path and deliberately subtracts 8px from right/bottom (and offsets left), leaving a resize inset. The runner's return-0 handler is therefore bypassed. Calling setAsFrameless after waitUntilReadyToShow restores the plugin flag before first show and routes all later non-client sizing through its frameless branch.
test: Static source trace across plugin registration, waitUntilReadyToShow ordering, SetTitleBarStyle/SetAsFrameless, and media_kit fullscreen implementation.
expecting: Source-level call order exactly matches the suspected mechanism; media_kit removes WS_OVERLAPPEDWINDOW while entering fullscreen, and WindowService's mode call itself does not alter native geometry.
next_action: Record confirmed root cause and read-only minimum fix recommendation with precise functions.
bug_class: Bohrbug
candidate_causes: code: native non-client-area calculation; config/environment: Windows DWM/window_manager style interaction
and_gate: yes — a visible gap requires both the runner's conditional layout behavior and a Dart/plugin window style state that selects it.

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Frameless and fullscreen Windows player content fills the intended client/display area with no white border or edge seam.
actual: White border/edge gap can appear when fullscreen/window chrome state is active; working tree contains an uncommitted initialization-time setAsFrameless change intended to address it.
errors: None reported.
reproduction: Launch the Windows player and enter fullscreen; inspect all edges, especially after hidden title-bar/frameless initialization.
started: Not supplied; current working-tree modification is under investigation.

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-03T05:57:49Z
  checked: Current git working tree
  found: lib/kernel/bridge/window_service.dart adds await windowManager.setAsFrameless() inside the waitUntilReadyToShow callback after hidden titleBarStyle has been applied.
  implication: The proposed correction targets window_manager lifecycle ordering rather than Flutter video layout.

- timestamp: 2026-08-03T05:59:27Z
  checked: windows/runner/win32_window.cpp history
  found: Commit a13e2d74 added the runner's WM_NCCALCSIZE return-0 handler specifically to eliminate WS_THICKFRAME ~7px borders, but FlutterWindow::MessageHandler gives registered plugins first refusal before that handler.
  implication: The runner mitigation cannot control messages for which window_manager returns a result.

- timestamp: 2026-08-03T06:00:41Z
  checked: window_manager 0.5.2 Windows implementation
  found: WindowManagerPlugin::HandleWindowProc handles WM_NCCALCSIZE before the runner. With title_bar_style_ == hidden and is_frameless_ == false, its non-maximized branch adjusts right and bottom by -8 (and left by +8), then returns 0. WindowManager::SetTitleBarStyle unconditionally sets is_frameless_ = false; WindowManager::SetAsFrameless sets it true and triggers SWP_FRAMECHANGED.
  implication: The exact 8px seam derives from the plugin's hidden-title-bar resize accommodation, not a Flutter layout margin.

- timestamp: 2026-08-03T06:01:14Z
  checked: Fullscreen callers and media_kit_video 1.3.1 Windows native implementation
  found: Player keyboard/control actions call WindowService.setMode only to maintain Dart intent/state, then VideoState.toggleFullscreen. media_kit Utils::EnterNativeFullscreen removes WS_OVERLAPPEDWINDOW and resizes to monitor.rcMonitor. SmartDragToResizeArea is disabled in fullscreen but remains present, so it is not a source of native white edges.
  implication: The observed fullscreen issue is exposed by the native style/message transition; the bridge init ordering is the minimal application-controlled fix.

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: window_manager 0.5.2 processes WM_NCCALCSIZE before the app runner. WindowService.init requests TitleBarStyle.hidden; its native SetTitleBarStyle resets is_frameless_ to false. For a non-maximized hidden window, the plugin's HandleWindowProc deliberately retains an 8px right/bottom resize allowance, which appears as the white border/edge seam. The runner's unconditional WM_NCCALCSIZE return 0 does not run because the plugin has already returned a result.
fix: Keep the existing working-tree change: in WindowService.init's windowManager.waitUntilReadyToShow callback, await windowManager.setAsFrameless() immediately before any bounds/show/maximize operation. It must be after waitUntilReadyToShow's internal setTitleBarStyle(hidden), because that call clears the frameless flag. Do not change media_kit fullscreen, UI padding, or the runner handler.
verification: Static source trace confirms cause and ordering. Runtime Windows verification remains required: launch, inspect all four windowed edges; toggle fullscreen repeatedly; exit fullscreen and confirm window resize behavior remains supplied by SmartDragToResizeArea.
files_changed:
  - lib/kernel/bridge/window_service.dart
