# 原生窗口缩放与 resize 渲染稳定性计划

## 目标

- 删除 Flutter 层 `DragToResizeArea`/`SmartDragToResizeArea`，不通过 Widget 手势模拟窗口尺寸。
- 普通 frameless 窗口的四边、四角拖拽全部交给 Windows 原生 resize loop。
- Dart 层继续通过 `window_manager` 管理窗口样式、最小尺寸、状态和 resize 回调；Windows runner 只封装原生 hit-test，不向 UI 泄漏 Win32 细节。
- resize 期间冻结高成本视频/玻璃渲染路径，resize 结束后恢复，并保持视频 Texture/Element identity。
- 修复 WindowService 的异步生命周期和 mode 状态竞态。

## 实现步骤

1. **修复 WindowService 生命周期与模式一致性**
   - 为 `_setModeSerialized()` 的每个平台 await 建立 generation/dispose guard，dispose 后不再访问 notifier。
   - fullscreen → windowed/maximized/minimized 时先清理 `_fullscreenIntent`，失败时不提交错误状态。
   - maximize/unmaximize/minimize 成功后显式提交对应 `WindowMode`，同时避免平台回调重复通知；回调只作为外部窗口操作的同步入口。
   - 保留 `_modeOperation` 串行链，但记录前序操作错误并保持调用者 Future 的错误语义；避免后续操作被失败链永久阻塞。
   - 初始化 Future 增加失败日志和可重试语义；`waitUntilReadyToShow` 与 `_initWindow` 的 fire-and-forget 边界统一捕获 `Exception`。

2. **完成 Windows 原生边缘命中**
   - 在 `FlutterWindow::MessageHandler()` 中对 `WM_NCHITTEST` 明确走 `Win32Window::MessageHandler()`，确保 Flutter/plugin 不会抢先消费。
   - 保留 `WM_NCCALCSIZE` 返回 0 的白边修复；由 `WM_NCHITTEST` 根据 DPI、窗口 rect 和 `WS_THICKFRAME` 返回四边/四角 `HT*`。
   - 最大化、最小化、fullscreen intent 或 `setResizable(false)` 时返回 `HTCLIENT`，避免全屏/非可调整状态进入原生 resize loop。
   - 删除确认未使用的 C++ include，并为 hit-test 辅助逻辑补充可测试的纯函数或 runner 集成测试 seam。

3. **接通 resize 事件与渲染降级**
   - 依赖 `window_manager` 的 `onWindowResize` 作为唯一 Dart resize 信号源；不重新引入 Flutter 边缘手势。
   - 保留 `_startResizeTimer()` 的 session/generation/debounce 机制：原生拖拽开始立即 `isResizing=true`，连续事件只续期当前 session，500ms 无事件后获取最终尺寸并恢复 false。
   - 在 `PlayerScreen`/`PlayerVideoControls`/控制栏玻璃组件中确认 `windowService.isResizing` 已传递到所有高成本路径：resize 时跳过 `BackdropFilter`、冻结自动隐藏和保留视频内容缓存；结束后恢复正常渲染。
   - 若当前仅有状态信号但没有实际降级，增加最小状态分支并保持 cached video child、`RepaintBoundary` 和 `VideoTextureResizeProbe` 的 identity 不变；不修改 media_kit。

4. **测试优先补齐回归覆盖**
   - WindowService：dispose-after-await、mode 串行化、全屏 intent 清理、maximize/unmaximize 显式状态、初始化失败重试。
   - WindowService resize：原生连续事件只产生一个 session、立即 true、debounce 后 false、旧 generation 不覆盖新尺寸、净尺寸不变也结束会话。
   - Widget：resize 时控制栏/玻璃高成本路径降级，结束后恢复；视频 surface identity 不变。
   - Windows runner：四边/四角命中、DPI scaling、不可调整/最大化/最小化返回 `HTCLIENT`；若构建环境不支持 runner 单测，至少加入可独立测试的 hit-test 计算 seam。

5. **验证**
   - `dart format`。
   - `flutter analyze`，记录并区分预存 warning。
   - `flutter test` 及必要的覆盖率检查。
   - `flutter build windows`。
   - 实机验证普通窗口四边/四角、最小尺寸 854×513、最大化/还原、media_kit 全屏、Snap、100/125/150% DPI、跨显示器 DPI、窗口持久化和 resize 渲染恢复。

## 风险与边界

- `window_manager.setResizable(true)` 只控制窗口样式，不会替代 frameless 窗口的 `WM_NCHITTEST`；因此原生 runner 命中逻辑是必要实现，但仍由 window_manager 管理可调整状态。
- 不恢复 Flutter `DragToResizeArea`，不在 Dart UI 处理 Win32 hit-test，不修改 media_kit。
- 平台状态回调可能延迟或重复，所有异步状态提交必须经过 dispose/generation guard。
