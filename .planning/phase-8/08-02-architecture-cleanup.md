# 08-02: 架构清理 — 抽象泄漏修复、遗留代码移除

## Context

逆向分析发现 2 个架构问题:
- **ARCH-01**: `is WindowsFullscreenDriver` 类型检查泄漏抽象层
- **ARCH-02**: WindowService 中遗留 `fullscreen_window` 直连代码

## 长期记忆约束

- **Window 反模式** [[project_window_anti_patterns]]: 避免 kernel 深度耦合窗口管理
- **Fullscreen FFI 反模式** [[anti_pattern_fullscreen_ffi]]: 不要引入 win32 包依赖
- **Singleton 重构** [[feedback_singleton_refactoring]]: 删除遗留代码前 grep 所有引用点
- **Comment while coding** [[feedback_comment_while_coding]]: 架构变更必须解释 *why*

## Task 1: ARCH-01 — 抽象泄漏修复

**文件**: `lib/kernel/bridge/desktop_fullscreen_adapter.dart`

**问题**: `DesktopFullscreenAdapter` 用 `is WindowsFullscreenDriver` 类型检查来决定是否使用 Windows 快速路径。这违反了 Liskov 替换原则 — 如果换一个 Windows 驱动实现，快速路径就丢失了。

**方案**: 在 `FullscreenDriver` 抽象层添加能力查询:
```dart
// fullscreen_driver.dart — 添加能力标志
abstract class FullscreenDriver {
  /// 是否支持批量快照查询（Windows FFI 快速路径）
  bool get supportsBatchSnapshot => false;
}
```

```dart
// windows_fullscreen_driver.dart — 覆盖
@override
bool get supportsBatchSnapshot => true;
```

```dart
// desktop_fullscreen_adapter.dart — 替换类型检查
// BEFORE: if (_driver is WindowsFullscreenDriver) { ... }
// AFTER:  if (_driver.supportsBatchSnapshot) { ... }
```

**影响范围**: 仅 desktop_fullscreen_adapter.dart 中的 2 处类型检查

**验证**: `flutter test test/kernel/bridge/desktop_fullscreen_adapter_test.dart`

## Task 2: ARCH-02 — 遗留代码移除

**文件**: `lib/kernel/bridge/window_service.dart` (lines 298-299, 319-320)

**问题**: `fullScreenWindow.setFullScreen()` 是 v1.2 遗留代码，绕过了 FullscreenAdapter 抽象层。代码中有 `@deprecated(v1.2)` 标记和 `TODO(ARCH-03)` 注释。

**安全检查**:
1. grep `fullScreenWindow` 确认所有引用点
2. 确认 `_fullscreenAdapter != null` 在所有调用路径上为 true
3. 确认没有其他文件直接使用 `fullScreenWindow`

**修改**:
```dart
// 删除 else 分支中的 fullScreenWindow 直连代码
case WindowMode.fullscreen:
  if (_fullscreenAdapter != null) {
    _state.mode.value = WindowMode.fullscreen;
    try {
      await _fullscreenAdapter.setFullscreen(true);
    } on Exception catch (e) {
      _state.mode.value = WindowMode.windowed;
      debugPrint('[WindowService] fullscreen failed: $e');
    }
  }
  // 已移除: else { fullScreenWindow.setFullScreen(true) }

case WindowMode.windowed:
  if (_state.mode.value == WindowMode.fullscreen &&
      _fullscreenAdapter != null) {
    _state.mode.value = WindowMode.windowed;
    await _fullscreenAdapter.setFullscreen(false);
  } else if (_state.mode.value == WindowMode.maximized) {
    await windowManager.unmaximize();
  }
  // 已移除: else if (_fullscreenAdapter == null) { fullScreenWindow.setFullScreen(false) }
```

**清理**:
- 删除 `fullScreenWindow` 字段声明
- 删除相关 import
- 删除 `@deprecated(v1.2)` 注释和 `TODO(ARCH-03)` 标记

**验证**:
- `flutter analyze` 无 warning
- `flutter test` 全部通过

## 完成标准

- [ ] 无 `is WindowsFullscreenDriver` 类型检查
- [ ] 无 `fullScreenWindow` 直连代码
- [ ] `FullscreenDriver` 有 `supportsBatchSnapshot` 能力查询
- [ ] 所有现有测试通过
- [ ] `flutter analyze` 无新增 warning
