# Phase 13: Window Foundation — 执行计划

**目标**: 窗口从第一帧起即为无边框，启动零闪烁；Window 层代码精简至 50% 行数
**依赖**: Phase 12
**需求**: WIN-05, WIN-06
**风险**: 高（WM_NCCALCSIZE spike）

## 成功标准

1. C++ `WM_NCCALCSIZE` 在 `HandleTopLevelWindowProc` 之前拦截，非客户区折叠为零
2. `WS_CAPTION` 保留以维持 DWM 最大化/还原动画
3. 启动时无边框闪烁（第一帧即为无边框状态）
4. Dart 端三重异步边框移除路径合并为单一同步路径
5. Window 层代码行数减少 50%+

## 关键洞察

`Win32Window::WndProc` 是消息最早入口，在 `FlutterWindow::MessageHandler` 之前执行。之前 3 次 C++ 失败都把拦截点放在 `MessageHandler` 中，但那里 `HandleTopLevelWindowProc` 先消费消息。这次在 WndProc 中拦截，引擎无法绕过。

## 三波实施

### Wave 1: WM_NCCALCSIZE Spike（1-2h）

**目标**: 验证 WndProc 中拦截 WM_NCCALCSIZE 可行性

**修改文件**:
- `windows/runner/win32_window.h` — 添加 `is_frameless_` 标志 + `SetFrameless()`/`IsFrameless()`
- `windows/runner/win32_window.cpp` — WndProc 中拦截 WM_NCCALCSIZE
- `windows/runner/flutter_window.cpp` — OnCreate 启用 frameless + DWM 阴影

**C++ 核心代码**:

WndProc 拦截（在 MessageHandler 调用之前）:
```cpp
if (message == WM_NCCALCSIZE && wparam == TRUE && that->IsFrameless()) {
  LONG_PTR style = GetWindowLongPtr(window, GWL_STYLE);
  if (!(style & WS_POPUP)) {  // 全屏时跳过（方案 B）
    auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
    params->rgrc[0] = params->rgrc[1];  // 客户区 = 窗口
    return 0;
  }
}
```

OnCreate 启用:
```cpp
SetFrameless(true);
MARGINS margins = {0, 0, 1, 0};
DwmExtendFrameIntoClientArea(GetHandle(), &margins);
```

**验证**: OutputDebugString 确认消息顺序 → 视觉测试无闪烁

**失败备选**:
- Alt A: WM_CREATE 中同步修改 style
- Alt B: DwmExtendFrameIntoClientArea(-1)
- Alt C: 接受闪烁，优化异步路径速度

### Wave 2: C++ 实现 + Dart 路径合并（2-3h）

**依赖**: Wave 1 成功

**Dart 层变更**:

| 操作 | 文件 | 内容 |
|------|------|------|
| 删除 | `main.dart:31` | 移除 `await WindowService.removeBorderImmediate()` |
| 删除 | `window_service.dart` | 移除 `_removeBorder()`、`_baseStyle`、`removeBorderImmediate()` |
| 保留 | `main.dart:26` | `TitleBarStyle.hidden` 作为兜底 |
| 修复 | `window_service.dart:122` | `onWindowClose` 改 async，await 保存几何（H-1） |
| 修复 | `window_service.dart:207` | `_savedFrame` 分配前释放旧值（H-2） |
| 添加 | `win32_bindings.dart` | `swpNomove`/`swpNosize` 常量（M-1） |

### Wave 3: Window 层精简（3-4h）

**依赖**: Wave 2 完成

**精简目标**: WindowService 408 行 → ~330 行（-20%）

- 移除边框移除相关代码（~50 行）
- 简化全屏恢复逻辑（~30 行，不再需要 `_baseStyle`）
- 添加 Timeline 仪器化到 maximize/restore

## 修改文件清单

| 文件 | Wave | 变更类型 |
|------|------|----------|
| `windows/runner/win32_window.h` | 1 | 添加 frameless 标志 |
| `windows/runner/win32_window.cpp` | 1 | WndProc 拦截 WM_NCCALCSIZE |
| `windows/runner/flutter_window.cpp` | 1 | OnCreate 启用 frameless |
| `lib/main.dart` | 2 | 移除 removeBorderImmediate 调用 |
| `lib/kernel/bridge/window_service.dart` | 2,3 | 移除边框代码 + 修复竞态 + 精简 |
| `lib/kernel/bridge/win32_bindings.dart` | 2 | 添加常量 |

## 依赖关系

```
Wave 1 (Spike: 1-2h)
  ├─ 成功 → Wave 2 (C++ + Dart: 2-3h) → Wave 3 (精简: 3-4h)
  └─ 失败 → 备选方案评估
```

## 风险

| 风险 | 级别 | 缓解 |
|------|------|------|
| 引擎拦截 WM_NCCALCSIZE | **高** | WndProc 在 MessageHandler 之前，引擎无法拦截 |
| DWM 动画丢失 | 低 | 保留 WS_CAPTION，仅视觉折叠 NC 区域 |
| 全屏切换冲突 | 中 | 方案 B 检查 WS_POPUP 自动绕过 |
| DragToResizeArea 冲突 | 低 | Widget 层 vs Win32 消息层，互相独立 |

## 验收标准

- [ ] 窗口从第一帧起无边框（无闪烁）
- [ ] DWM 最大化/还原动画保留
- [ ] DragToResizeArea 缩放功能正常
- [ ] Win11 圆角保持
- [ ] 全屏进入/退出正常
- [ ] 现有窗口测试无回归
- [ ] WindowService 减少 ~80 行

## 代码审查发现（Wave 2 一并修复）

| ID | 级别 | 问题 | 修复 |
|----|------|------|------|
| CR-1 | CRITICAL | 三重异步边框移除竞争 | C++ 同步处理，删除 Dart 路径 |
| H-1 | HIGH | onWindowClose 异步竞争 | 改 async await |
| H-2 | HIGH | _savedFrame 内存泄漏 | 分配前 free 旧值 |
| H-4 | HIGH | FFI 无返回值校验 | 添加关键路径检查 |
| M-1 | MEDIUM | Magic Numbers | 添加命名常量 |

---
*计划创建: 2026-05-31*
