# window_bridge 行为契约（规格）

> 本文件是窗口层的**行为规格**。架构级重写（三平台：Windows/macOS/Linux X11+Wayland）
> 中代码组织可变，以下契约不可降级；每条契约在 test/unit/kernel/window_bridge/
> 有对应测试锁定。取证背景：docs/audit/resize-drag-ab-2026-11.md（本地存档）、
> docs/audit/upstream-issue-nativeapi-windows-resize-overhead.md（上游 issue 草稿）。

## 十条核心契约

1. **nativeapi 几何事件零订阅**（三平台统一）。nativeapi 在每个
   WM_WINDOWPOSCHANGED / configure-event / NSWindowDidResize 步骤于窗口线程
   构建并投递 moved+resized 事件（实测左缘拖拽每步 2 事件、零合并），是
   边缘拖拽"内容追边框"的根因。本层**不注册任何 nativeapi 事件监听**。
2. **几何检测源 = 引擎指标**：`WindowMetricsObserver`（didChangeMetrics，
   按 physicalSize 去抖）→ `WindowService.noteGeometryChanged()`。
3. **resize 会话**：500ms 防抖 + generation 计数；`isResizing` 仅在会话
   边沿翻转；`resizeSessionId` 仅在会话开始递增。
4. **模式模型**：setMode 先落意图值；外部改动（Win+↑/Snap/任务栏）在下一个
   几何边沿由现查 `isMaximized` 校准；全屏意图/全屏期间校准让位。
   `setMode` 语义 =「意图立即提交，原生状态在下一几何边沿校准」——
   无落定等待（nativeapi 命令为同步 FFI marshal）。
5. **生命周期**：`init()` 隐藏态恢复几何（单飞、失败可重试）→ 首帧栅格化后
   `reveal()`（组合根等待，800ms 超时降级亮窗）。持久化的最大化在隐藏态
   完成，窗口以最大化形态首现，无普通→最大化闪变。
6. **reveal 前吞掉一切几何信号**（恢复几何自身引发的尺寸变化不产生假会话/
   假落盘）。
7. **关窗 hide-first 单飞序列**：hide → 排空落盘队列+persist → closing
   listeners → dispose + exit(0)。每步 800ms 超时兜底；任何失败不阻断退出；
   多路触发（✕/runner 专线/系统）共享同一次执行。
8. **落盘**：串行队列防交错；存「最近普通矩形+最大化标志」（最大化不覆盖
   还原尺寸——仅 windowed 态采样）；尺寸 clamp 到最小值；全屏期不落盘。
9. **还原矩形采样**：首沿立即 + 120ms 冷却尾沿合并（NormalBoundsTracker），
   resize 热路径不逐事件读 FFI。
10. **恢复可达性**：持久化位置不在任何显示器工作区（副屏拔线）→ 只应用
    尺寸+居中；workAreas 查询失败 → 信任原值（自动退化"不搬家"）。

## 平台矩阵

### 窗口句柄定位（platform/window_handle_locator.dart）
三平台 runner 各导出 `SimplerPlayerGetMainWindowHandle()` C 符号（主路径，
隐藏态可用）；fallback：Windows=FindWindowExW 按类名+PID 枚举，
macOS/Linux=`WindowManager.getCurrent() ?? getAll().firstOrNull`。

### 关窗通道（platform/close_notifier_bridge.dart + 各 runner）
三平台 runner 各导出 `SetCloseNotifier(void(*)())`（同一 C ABI）：
- Windows：SC_CLOSE（✕/Alt+F4/系统菜单）→ WM_CLOSE → runner 拦截 → notifier。
- macOS：`windowShouldClose` → notifier + return false；Cmd+Q →
  `applicationShouldTerminate` → notifier + `.terminateCancel`。
- Linux：GTK `delete-event`（X11 WM_DELETE_WINDOW 与 Wayland xdg close 共同
  归宿）→ notifier + return TRUE。
- notifier 缺失/安装失败：runner 放行原生关闭（降级 = 无落盘退出，Dart ✕
  按钮仍走 hide-first）。
- 强制路径（WM_DESTROY/注销、macOS -close、Linux destroy/kill）不可拦截，
  由契约 3+8 的防抖落盘兜底（快照最多滞后一个会话）。

### reveal 时序
- Windows：建窗即隐藏 + runner 首帧回调 Show 兜底 + Dart reveal 主路径。
- macOS：awakeFromNib 不亮窗（隐藏态实例化）；Dart reveal 主路径；首帧
  等待超时走 showDegraded 降级。
- Linux：runner first-frame 回调 gtk_widget_show 兜底 + Dart reveal 主路径。

### 平台差异收口（platform/platform_profile.dart）
`WindowPlatformProfile.detect()` 是 service/port 层之外唯一允许平台判定的
地方（service/port 层禁止 Platform.isX）：
- `dropDwmFrame`：Windows 10（build<22000）去 DWM frame 防主题色顶线；
  init 顺序契约 = hasShadow=false 先于 hideTitleBar。
- `supportsWindowPositioning`：Wayland（Linux 且 WAYLAND_DISPLAY 存在）为
  false → 恢复只 setSize（跳过定位/center）、落盘 position=null。
  误判方向安全（少恢复位置，不丢尺寸）。
- `needsResizeHotZones`：Linux 为 true（decorated(FALSE) 后无系统 resize
  边缘，UI 层挂不可见热区 → `startResizing(edge)`）；Windows（保留 sizing
  frame）/macOS（hidden 保留 frame）为 false。
- macOS `titleBarStyle.hidden` 强制 `setMovable:NO`：自绘标题栏 +
  startDragging（performWindowDragWithEvent）不受影响，无需处理。

## 测试 seam（构造注入，禁止在测试中触发真 FFI）
WindowService：persistence / bindWindow / exitOnClose / profile（含
dropDwmFrame 兼容映射）/ installCloseNotifier。
WindowHandleLocator：策略闭包列表。WindowPlatformProfile.detect：
osVersion / environment / operatingSystem 探测闭包。
WindowMetricsObserver：currentSize。NormalBoundsTracker：window/canTrack。
