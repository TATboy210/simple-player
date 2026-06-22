# Phase 14: Window Layer V2 — 学习并超越参考项目

## 问题清单（10 个）

| 编号 | 问题 | 严重度 |
|------|------|--------|
| W-01 | 命令直接写状态，与 OS 回调竞争 | P0 |
| W-02 | `_isAnimating` Timer 软锁，异常时卡死 | P0 |
| W-03 | `GetForegroundWindow()` 可能指向错误窗口 | P0 |
| W-04 | 全局可变状态 `_savedStyle` 非实例封装 | P1 |
| W-05 | 缺少失败回滚 | P1 |
| W-06 | WindowService God Object (225行 6职责) | P1 |
| W-07 | 缺少 NoopWindowBridge 降级 | P1 |
| W-08 | resize 只有 bool，缺交互状态模型 | P2 |
| W-09 | 双重 dispose（App + PlayerServices） | P2 |
| W-10 | 全屏退出保存延迟 300ms 可能丢失 | P2 |

## 超越参考项目的 5 个方向

1. **接口驱动** — `WindowBridge` 抽象接口（参考项目用单例）
2. **构造器注入** — 可测试（参考项目用 `WindowBridge.I`）
3. **DisplayConfig 集成** — 全屏时适配刷新率
4. **InteractionState 三态** — `idle/resizing/moving`（参考项目只有 bool）
5. **Composition Root** — main() 中组装（参考项目用 Bootstrap 单例）

## 目标文件结构

```
lib/kernel/bridge/
├── window_bridge.dart          # 扩展接口
├── window_mode.dart            # NEW: WindowMode 枚举
├── window_state.dart           # NEW: 状态容器 (5 VN)
├── window_service.dart         # REWRITE: 薄协调者 (~80行)
├── fullscreen_controller.dart  # NEW: Win32 FFI + 回滚 + mutex
├── aspect_ratio_service.dart   # NEW: 宽高比管理
├── window_lifecycle_bus.dart   # NEW: 事件总线 + interaction
├── window_persistence.dart     # NEW: 几何持久化 + debounce guard
├── noop_window_bridge.dart     # NEW: 空实现降级
├── win32_fullscreen.dart       # DELETE: 逻辑迁入 fullscreen_controller
├── window_bootstrap.dart       # SIMPLIFY
└── display_config.dart         # ENHANCE
```

## 实施计划（7 个子阶段）

### 14-1: 状态容器 + 枚举 ✅
- 新建 `window_mode.dart` (WindowMode 枚举)
- 新建 `window_state.dart` (状态容器 5 VN + _BoolProxy)
- **测试**：16 个

### 14-2: FullscreenController ✅
- 新建 `fullscreen_controller.dart` (Win32 FFI + mutex + 回滚)
- 删除 `win32_fullscreen.dart`（逻辑迁入）
- **测试**：9 个

### 14-3: AspectRatioService ✅
- 新建 `aspect_ratio_service.dart` (纯逻辑，无 FFI)
- **测试**：12 个

### 14-4: WindowLifecycleBus ✅
- 新建 `window_lifecycle_bus.dart` (事件总线 + lastInteractionTime)
- **测试**：6 个

### 14-5: WindowPersistence ✅
- 新建 `window_persistence.dart` (debounce + in-flight guard)
- **测试**：8 个

### 14-6: WindowService 重写 ✅
- 重写为薄协调者 (150行，原 225行)
- 组合 WindowState + FullscreenController + AspectRatioService + WindowLifecycleBus + WindowPersistence
- OS 回调驱动状态（命令不直接写）
- 向后兼容 WindowBridge 接口
- **测试**：11 个

### 14-7: NoopWindowBridge + 测试 ✅
- 新建 `noop_window_bridge.dart` (idempotent dispose)
- 更新 `fake_window_service.dart` (完整调用追踪)
- **测试**：17 个 (noop) + 62 (bridge layer)

## 依赖关系

```
14-1 (状态容器) ← 先做
  ↓
14-2 (FullscreenController) ← 依赖 14-1
  ↓
14-3 (AspectRatio)    ← 可并行
14-4 (LifecycleBus)   ← 可并行
14-5 (Persistence)    ← 可并行
  ↓
14-6 (WindowService 重写) ← 依赖 14-1~14-5
  ↓
14-7 (Noop + 测试) ← 依赖 14-6
```

## 成功标准

- [x] 10 个问题 (W-01~W-10) 全部修复
- [x] WindowService 从 225 行减到 ~150 行（薄协调者）
- [x] 全屏切换无状态竞争（OS 回调驱动）
- [x] 全屏切换有互斥锁 (try/finally)
- [x] 全屏切换失败可回滚（nested try-catch）
- [x] 现有测试全部通过（736 tests）
- [x] 新增 79 测试（bridge layer），总测试 736
- [x] UI 层仍只依赖 WindowBridge 接口
