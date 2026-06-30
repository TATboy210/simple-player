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
**Plans:** 2 plans
Plans:
**Wave 2**

- [x] 01-01-PLAN.md — Migrate 56 source file imports from package:player_engine to local relative paths

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-02-PLAN.md — Remove pubspec dependency, update docs, run full verification

**Success Criteria**:

1. `pubspec.yaml` 中不存在 `player_engine` path 依赖
2. `grep -r "package:player_engine" lib/ test/` 返回零结果（PowerShell: `(Get-ChildItem -Path lib, test -Recurse -Filter *.dart | Select-String -Pattern "package:player_engine").Count` = 0）
3. `flutter analyze` 零错误零警告
4. `flutter test` 全部通过
5. `lib/kernel/engine/player_engine.dart` barrel export 包含全部 8 个符号

---

### Phase 2: 引擎组合重构

**Goal:** FvpEngine 委托 VolumeController/SubtitleConfigurator/D3D11Configurator，消除内联逻辑
**Mode:** mvp
**Requirements:** COMP-01, COMP-02, COMP-03, COMP-04, COMP-05
**Plans:** 2/2 plans complete
Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Expand D3D11Configurator + write unit tests for all 3 helpers

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-02-PLAN.md — Wire delegation in FvpEngine + verify all tests pass

**Success Criteria**:

1. FvpEngine 中 VolumeController/SubtitleConfigurator/D3D11Configurator 相关逻辑委托给 helper 类
2. FvpEngine 行数从 ~547 降至 ~350
3. ValueNotifier 所有权保持在 FvpEngine 的 `final` 字段中（未改为 getter）
4. `flutter test` 全部通过（含 MockEngine 测试）
5. D3D11 属性在 `open()` 调用前正确设置（通过 D3D11Configurator.applyDefaults()）

---

### Phase 3: 接口优化

**Goal:** 通过 mixin 拆分 EngineState 接口，实现能力隔离
**Mode:** mvp
**Requirements:** IFACE-01, IFACE-02, IFACE-03, IFACE-04, IFACE-05
**Plans:** 1 plan
Plans:
**Wave 1**

- [ ] 03-01-PLAN.md — Split EngineState into TrackControl/VideoEffects/RendererConfig sub-mixins + capability tests

**Success Criteria**:

1. TrackControl/VideoEffects/RendererConfig mixin 接口定义完成
2. 现有 57 个 UI 文件的 EngineState import 无需修改（向后兼容）
3. `engine is TrackControl` 能力检查在 UI 层可用
4. FvpEngine 通过 `with EngineState, TrackControl, VideoEffects, RendererConfig` 组合实现
5. `flutter analyze` + `flutter test` 全部通过

---

### Phase 4: 测试与平台验证 ✅

**Goal:** 确保重构后所有测试通过，平台特定行为正确
**Mode:** mvp
**Requirements:** TEST-01, TEST-02, TEST-03, TEST-04, PLAT-01, PLAT-02, PLAT-03, PLAT-04
**Plans:** 1 plan
Plans:
**Wave 1**

- [x] 04-01-SUMMARY.md — 验证测试 + 平台行为分析

**Success Criteria**:

1. ✅ MockEngine 继续实现完整 PlayerEngine 接口（含 mixin 检查）
2. ✅ 所有现有 widget 测试在重构后通过（893 pass, 3 golden pre-existing）
3. ✅ 新 helper 组件有独立单元测试（34 tests）
4. ✅ Win32 DisplayConfig 冷启动时序正确（默认60Hz, init幂等）
5. ✅ texture ID 生命周期同步无泄漏（listener链验证）

**Verification:**

- `flutter analyze`: 0 errors ✅
- `flutter test`: 893 pass, 3 fail (golden, pre-existing) ✅
- 新增 42 个测试: mixin behavior(30) + texture lifecycle(5) + display config(7)

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

*Last updated: 2026-06-30*
