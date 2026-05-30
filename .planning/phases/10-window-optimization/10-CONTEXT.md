# Phase 10: Window Optimization - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

窗口启动恢复、全屏/最大化状态恢复、多显示器边界验证、双重 WindowService 修复。覆盖 WIN-04 需求的全部 4 个子项。

不涉及：架构重构（Phase 8 已完成）、性能优化（Phase 11）、Debug 工具（Phase 12）、流媒体功能。

</domain>

<decisions>
## Implementation Decisions

### 崩溃安全几何保存 (D-01)

**D-01: 保持现有 500ms 防抖 + close handler 机制**
- 当前 `SettingsStore.saveWindowGeometry` 使用 500ms 防抖 + `onWindowClose` 立即保存
- 不添加定期保存或原子写入保护 — SettingsStore RC-4 顺序写入已足够
- 极端崩溃场景（500ms 窗口内）丢失少量位置数据可接受

### 全屏状态恢复 (D-02)

**D-02: 启动时不自动恢复全屏状态**
- `_savedFrame`（全屏退出时的原始位置）仅在内存中，崩溃后丢失
- 启动时清除 `isFullscreen` 标志，用户手动重新进入全屏
- 避免崩溃后无法退出全屏的困境（无 _savedFrame 可恢复）

### Claude's Discretion

以下决策由规划代理基于研究结果自行决定：

- **启动窗口恢复策略**：研究建议 WindowBootstrap 类读取 SettingsStore 几何数据，在 `waitUntilReadyToShow` 回调中应用，`show()` 后调用 `ensureVisible()`
- **多显示器边界检查**：研究建议使用 `screen_retriever.getAllDisplays()` + 至少 100px 可见重叠判断
- **双重 WindowService 修复**：研究建议改为单例注入（App 创建一次，传递给 PlayerServices）
- **最大化状态恢复**：研究建议恢复 `isMaximized`（有 `_savedMaximizeFrame` 支持），在 `show()` + `ensureVisible()` 后调用 `windowService.maximize()`
- **WindowOptions 与手动 setPosition/setSize 的时序**：需要实测确认是否被覆盖

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 窗口管理核心
- `lib/kernel/bridge/window_service.dart` — 当前实现（370 行），所有 FFI 调用、fullscreen 转换、geometry 保存
- `lib/kernel/bridge/win32_bindings.dart` — FFI struct 定义和 Win32Bindings 类
- `lib/main.dart` — 启动流程（硬编码 WindowOptions，geometry 未恢复）
- `lib/app.dart` — WindowService 创建（双重实例 bug 的一半）

### 持久化
- `lib/kernel/persistence/settings_store.dart` — SettingsStore（RC-3 清理、RC-4 顺序写入、500ms 防抖、windowWidth/windowHeight/windowX/windowY/isMaximized/isFullscreen 字段）

### 服务层
- `lib/features/player/player_services.dart` — PlayerServices（双重实例 bug 的另一半）
- `lib/features/player/player_feature.dart` — PlayerFeature（PlayerServices 的创建点）

### 测试
- `test/kernel/bridge/window_service_test.dart` — WindowService 测试（如果存在）
- `test/kernel/persistence/settings_store_test.dart` — SettingsStore 测试

### 外部依赖
- `window_manager` 0.5.1 — ensureVisible、setPosition、setSize、setBounds API
- `screen_retriever` 0.2.0（transitive）— getAllDisplays、getPrimaryDisplay API

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SettingsStore.saveWindowGeometry` — 500ms 防抖保存，已有 RC-3/RC-4 安全保护
- `WindowService._scheduleGeometrySave` — 窗口移动/调整时触发保存
- `WindowService.maximize()` / `restore()` — 自定义 FFI 最大化/恢复，使用 rcWork 区域
- `WindowService.setFullscreen()` — Phase 9 添加了 5 秒超时保护

### Established Patterns
- ValueNotifier 状态管理 — WindowService 暴露 `isFullscreenNotifier`、`isMaximizedNotifier`
- FFI try/finally — Phase 9 确立的指针安全模式
- `removeBorderImmediate()` — 启动时移除 WS_CAPTION，在 `waitUntilReadyToShow` 回调中调用

### Integration Points
- `main.dart` → `waitUntilReadyToShow` 回调 — 几何恢复的插入点
- `App` → `DeferredPlayerFeature` → `PlayerFeature` → `PlayerServices` — WindowService 注入链
- `WindowService.onWindowClose` — 几何立即保存的触发点

</code_context>

<specifics>
## Specific Ideas

### 研究推荐的启动流程

```
main.dart
  → windowManager.ensureInitialized()
  → SettingsStore.load()
  → WindowBootstrap.restoreOrCenter(settings)
    → if saved position exists AND on visible monitor:
      → windowManager.setPosition(savedPosition)
      → windowManager.setSize(savedSize)
    → else:
      → windowManager.center()
    → windowManager.ensureVisible()
  → WindowService.removeBorderImmediate()
  → windowManager.show() + focus()
  → if settings.isMaximized: windowService.maximize()
  → App(coordinator, windowService)  // 单例注入
```

### 研究发现的 Pitfall
1. WindowOptions 可能覆盖手动 setPosition/setSize — 需要在回调内设置几何
2. ensureVisible() 在 show() 前调用可能检测错误 — 应在 show() 后调用
3. maximize() 使用 FFI SetWindowPos — 启动时恢复最大化可能无动画

</specifics>

<deferred>
## Deferred Ideas

- `_savedFrame` 持久化以支持全屏崩溃恢复 — 用户决定不实现，避免复杂度
- 定期保存（每 30 秒）— 用户决定不需要，现有机制足够
- 原子写入保护 — SettingsStore RC-4 已提供顺序写入保护

</deferred>

---

*Phase: 10-Window Optimization*
*Context gathered: 2026-05-30*
