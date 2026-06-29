# Roadmap: PlayerEngine Refactoring

**Created:** 2026-06-29
**Granularity:** fine
**Mode:** interactive
**Total Requirements:** 22 v1 requirements across 5 categories

---

### Phase 1: 依赖清理
**Goal:** 移除外部 `player_engine` path 依赖，统一为本地相对路径导入
**Mode:** mvp
**Requirements:** DEP-01, DEP-02, DEP-03, DEP-04
**Success Criteria**:
1. `pubspec.yaml` 中不存在 `player_engine` path 依赖
2. `grep -r "package:player_engine" lib/` 返回零结果
3. `flutter analyze` 零错误零警告
4. `flutter test` 全部通过
5. `lib/kernel/engine/player_engine.dart` barrel export 包含全部 8 个符号

---

### Phase 2: 引擎组合重构
**Goal:** FvpEngine 委托 VolumeController/SubtitleConfigurator/D3D11Configurator，消除内联逻辑
**Mode:** mvp
**Requirements:** COMP-01, COMP-02, COMP-03, COMP-04, COMP-05
**Success Criteria**:
1. FvpEngine 中 VolumeController/SubtitleConfigurator/D3D11Configurator 相关逻辑委托给 helper 类
2. FvpEngine 行数从 ~547 降至 ~350
3. ValueNotifier 所有权保持在 FvpEngine 的 `final` 字段中（未改为 getter）
4. `flutter test` 全部通过（含 MockEngine 测试）
5. D3D11 属性在 `open()` 调用前正确设置（通过 D3D11Configurator.applyDefaults()）

---

### Phase 3: 接口优化
**Goal:** 通过 mixin 拆分 PlayerEngine 接口，实现能力隔离
**Mode:** mvp
**Requirements:** IFACE-01, IFACE-02, IFACE-03, IFACE-04, IFACE-05
**Success Criteria**:
1. TrackControl/VideoEffects/RendererConfig mixin 接口定义完成
2. 现有 57 个 UI 文件的 PlayerEngine import 无需修改（向后兼容）
3. `engine is TrackControl` 能力检查在 UI 层可用
4. FvpEngine 通过 `with TrackControl, VideoEffects, RendererConfig` 组合实现
5. `flutter analyze` + `flutter test` 全部通过

---

### Phase 4: 测试与平台验证
**Goal:** 确保重构后所有测试通过，平台特定行为正确
**Mode:** mvp
**Requirements:** TEST-01, TEST-02, TEST-03, TEST-04, PLAT-01, PLAT-02, PLAT-03, PLAT-04
**Success Criteria**:
1. MockEngine 继续实现完整 PlayerEngine 接口（含 mixin 检查）
2. 所有现有 widget 测试在重构后通过（零回归）
3. 新 helper 组件（VolumeController/SubtitleConfigurator/D3D11Configurator）有独立单元测试
4. Win32 DisplayConfig 平台通道冷启动时序正确
5. texture ID 生命周期与 Flutter Texture widget 同步无泄漏

---

## Coverage Summary

| Category | Count | Phase |
|----------|-------|-------|
| DEP (依赖清理) | 4 | Phase 1 |
| COMP (引擎组合重构) | 5 | Phase 2 |
| IFACE (接口优化) | 5 | Phase 3 |
| TEST (测试保障) | 4 | Phase 4 |
| PLAT (平台安全) | 4 | Phase 4 |
| **Total** | **22** | **4 phases** |

**Coverage: 22/22 = 100%**

---

## Dependency Chain

```
Phase 1 (依赖清理)
  ↓ no code dependency, but clean imports make diff readable
Phase 2 (引擎组合重构)
  ↓ helpers must be wired before interface split
Phase 3 (接口优化)
  ↓ interface must stabilize before full test validation
Phase 4 (测试与平台验证)
```

Each phase is independently shippable. No phase depends on a later phase.

---

*Last updated: 2026-06-29*
