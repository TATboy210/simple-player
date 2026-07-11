# 08-01: UI 层 Bug 修复 — F 键接线、isFs 分离、错误处理

## Context

逆向分析发现 3 个 UI 层 bug:
- **BUG-01**: F 键快捷键未接线 — `KeyboardHandler.onToggleFullscreen` 未传入
- **BUG-02**: `isFs` 混淆全屏和最大化 — `m.isFullscreen || m.isMaximized`
- **BUG-03**: `setMode()` 错误被静默吞掉 — 无 try-catch

## 长期记忆约束

- **Singleton 重构反模式** [[feedback_singleton_refactoring]]: 修改回调链时必须 grep 所有引用点
- **Fullscreen 架构反模式** [[anti_pattern_fullscreen_architecture]]: 避免双状态源
- **Comment while coding** [[feedback_comment_while_coding]]: 每修改一段代码立即补注释

## Task 1: BUG-01 — F 键接线

**文件**: `lib/ui/player/player_screen.dart` (lines 163-194)

**问题**: `KeyboardHandler` 构造时传了 `onExitFullscreen` (ESC) 但没传 `onToggleFullscreen` (F)。keyboard_handler.dart:137 调用 `onToggleFullscreen?.call()` 但它是 null。

**修改**:
```dart
// 在 KeyboardHandler 构造中添加 onToggleFullscreen
onToggleFullscreen: () {
  widget.windowService.setMode(
    m == WindowMode.windowed ? WindowMode.fullscreen : WindowMode.windowed,
  );
},
```

**验证**: `flutter test test/ui/player/keyboard_handler_test.dart`

## Task 2: BUG-02 — isFs 分离

**文件**: `lib/ui/player/player_screen.dart` (line 161)

**问题**: `isFs = m.isFullscreen || m.isMaximized` 把最大化当作全屏处理，导致:
- ControlsOverlay auto-hide 在最大化时错误触发
- 全屏样式在最大化时错误应用

**修改**:
```dart
// 将 isFs 拆分为两个独立语义
final isFullscreen = m == WindowMode.fullscreen;
final isMaximized = m == WindowMode.maximized;
```

**下游影响**: 检查 `isFs` 的所有使用点:
- `_buildVideoContent` 参数
- `ControlsOverlay` 的 `isFullscreen` 参数
- `CustomTitleBar` 可见性逻辑

**验证**: `flutter test test/ui/player/player_screen_test.dart`

## Task 3: BUG-03 — 错误处理

**文件**: `lib/kernel/bridge/window_service.dart` (lines 314-315)

**问题**: `await _fullscreenAdapter.setFullscreen(true)` 无 try-catch，异常时:
- mode 已设为 fullscreen (line 314) 但实际未全屏
- 状态不一致，用户看到半全屏

**修改**:
```dart
case WindowMode.fullscreen:
  if (_fullscreenAdapter != null) {
    _state.mode.value = WindowMode.fullscreen;
    try {
      await _fullscreenAdapter.setFullscreen(true);
    } on Exception catch (e) {
      // 回滚 mode 到 windowed，与 adapter 错误事件同步
      _state.mode.value = WindowMode.windowed;
      debugPrint('[WindowService] fullscreen failed: $e');
    }
  } else {
    // ... existing legacy fallback
  }
```

**验证**: `flutter test test/kernel/bridge/window_service_test.dart`

## 完成标准

- [ ] F 键按下切换全屏/窗口
- [ ] ESC 仅在全屏时退出（已工作）
- [ ] 最大化不触发全屏 auto-hide
- [ ] 全屏失败时 mode 回滚到 windowed
- [ ] 所有现有测试通过
- [ ] `flutter analyze` 无新增 warning
