# flutter_fullscreen 包评估文档

**评估日期:** 2026-07-12
**评估结论:** 不引入 (D-06)
**需求:** FULL-02

## 包信息

| 属性 | 值 |
|------|-----|
| 包名 | flutter_fullscreen |
| 仓库 | github.com/j7126/full_screen |
| 版本 | 1.2.0 (2025) |
| 平台 | Android/iOS/Linux/macOS/Windows/Web |
| 代码量 | 4 文件 ~350 行有效代码 |
| 依赖 | window_manager ^0.5.0, web ^1.1.0 |

## 对比表

| 维度 | flutter_fullscreen | 我们的实现 |
|------|-------------------|-----------|
| **核心依赖** | window_manager (黑盒) | Win32 FFI 直调 user32.dll |
| **WS_THICKFRAME 7px 缝隙** | 不解决 (window_manager 限制) | 已解决 (D-P06: 样式剥离) |
| **命令队列** | 无 | FullscreenCommandQueue 防重入 |
| **确认机制** | 无 | 三级确认链 (回调→轮询→超时) |
| **几何恢复** | 无 | _RestoreSnapshot 入前快照退出恢复 |
| **窗口样式控制** | 不控制 | WS_THICKFRAME/CAPTION 完整管理 |
| **错误处理** | throw string | sealed class + 自动恢复 |
| **HWND/HMONITOR 缓存** | 无 | 有 (T1/T4 优化) |
| **快速路径** | 无 | 5 FFI calls (vs 12 标准路径) |
| **焦点恢复** | 无 | setForegroundWindow + setFocus (D-P07) |
| **TopMost 清理** | 无 | HWND_NOTOPMOST (D-P08) |
| **多显示器** | 不处理 | MonitorFromWindow + clamp |
| **测试** | 无 | 79+ 测试 |
| **代码量** | ~350 行 | ~2000 行 (7 文件) |
| **可测试性** | 单例+静态方法 (不可 mock) | 构造函数注入 (可 mock) |

## 不引入的原因

### 原因 1: 完全依赖 window_manager

flutter_fullscreen 的 Windows/macOS/Linux 实现完全委托给 `window_manager` 包的 `setFullScreen()` 方法。这意味着：

- 无法控制窗口样式 (WS_THICKFRAME/CAPTION)
- 无法实现快速路径 (5 FFI vs 12 FFI)
- 无法做 HWND/HMONITOR 缓存
- 无法做焦点恢复和 TopMost 清理

### 原因 2: 无法解决 WS_THICKFRAME 7px 缝隙

这是我们自研 Win32 FFI 的根本原因。window_manager 的 `setFullScreen()` 使用 SC_MAXIMIZE 命令，无法精确控制窗口边框样式。flutter_fullscreen 包装了 window_manager，继承了这个限制。

用户明确确认："千万必要下载win32依赖，这个依赖会导致播放器全屏有一帧卡顿"。

### 原因 3: 不可测试

flutter_fullscreen 使用单例 + 静态方法模式 (`FullScreen.setFullScreen()`)，无法通过构造函数注入 mock。我们的实现通过 `Win32FullscreenApiWrapper` 支持完整的测试注入。

### 原因 4: 无错误恢复

flutter_fullscreen 在失败时 throw string，没有自动恢复机制。我们的实现使用 sealed class + 自动恢复窗口状态。

### 原因 5: 无确认机制

flutter_fullscreen 调用 `setFullScreen()` 后不确认状态是否真正改变。我们的实现有三级确认链确保状态一致性。

## 可借鉴的设计

| 设计 | 说明 | 适用性 |
|------|------|--------|
| 条件导入 | `if (dart.library.js_util)` 分离 Web 实现 | 编译期类型安全，可借鉴用于未来 Web 支持 |
| `abstract mixin class` 监听器 | State 直接 with FullScreenListener | 简洁，但我们的 ValueNotifier 模式更适合 |
| ObserverList | Flutter 内置 O(1) 监听器集合 | 可用于替代 List<Listener> |
| 编译期常量平台检测 | `const isAndroid = bool.fromEnvironment(...)` | 可用于减少运行时 Platform.isXXX 调用 |

## 引入条件

如果未来满足以下 **所有** 条件，可以考虑引入 flutter_fullscreen：

1. **flutter_fullscreen 解耦 window_manager** — 使用原生 API 直调而非 window_manager 包装
2. **支持 WS_THICKFRAME 样式控制** — 能精确控制窗口边框样式
3. **支持确认机制** — 有状态变化回调或查询接口
4. **支持构造函数注入** — 可测试，非单例模式
5. **用户确认不再需要快速路径** — 5 FFI vs 12 FFI 的性能差异不再重要

**当前评估：** 以上条件均不满足，不引入。

## 决策记录

- **D-06:** 不引入 flutter_fullscreen 包
- **D-07:** 输出本评估文档到 `.planning/research/`
- **结论:** 保留自研 Win32 FFI 实现，借鉴条件导入和 mixin 监听器设计模式

---

*评估完成: 2026-07-12*
