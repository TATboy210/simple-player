# Requirements: PlayerEngine 架构优化与依赖清理

**Defined:** 2026-06-29
**Core Value:** 移除脆弱的外部依赖，通过组合模式优化引擎内部结构，保持所有现有功能完整

## v1 Requirements

### 依赖清理 (DEP)

- [x] **DEP-01**: 移除 pubspec.yaml 中的 `player_engine` path 依赖
- [x] **DEP-02**: 将 56 个文件的 import 从 `package:player_engine/player_engine.dart` 改为本地相对路径
- [ ] **DEP-03**: 验证 barrel export 文件 `player_engine.dart` 包含所有 8 个导出符号
- [ ] **DEP-04**: 确认 6 个 engine 内部文件的自引用 import 正确解析

### 引擎组合重构 (COMP)

- [x] **COMP-01**: 提取 VolumeController 为独立 helper（音量/静音逻辑）
- [x] **COMP-02**: 提取 SubtitleConfigurator 为独立 helper（字幕配置逻辑）
- [x] **COMP-03**: 提取 D3D11Configurator 为独立 helper（D3D11 属性配置）
- [x] **COMP-04**: FvpEngine 通过委托调用新 helper 而非内联逻辑
- [x] **COMP-05**: 保持 ValueNotifier 所有权在 FvpEngine 中不变（CRITICAL — 改为 getter 会破坏 MockEngine）

### 接口优化 (IFACE)

- [ ] **IFACE-01**: 定义 TrackControl mixin（音频/字幕轨道管理方法）
- [ ] **IFACE-02**: 定义 VideoEffects mixin（视频特效/色彩校正方法）
- [ ] **IFACE-03**: 定义 RendererConfig mixin（D3D11/渲染器配置方法）
- [ ] **IFACE-04**: PlayerEngine 保持向后兼容 — 现有 30 方法签名不变
- [ ] **IFACE-05**: UI 层可通过 `engine is TrackControl` 做能力检查

### 测试保障 (TEST)

- [ ] **TEST-01**: MockEngine 继续实现完整 PlayerEngine 接口
- [ ] **TEST-02**: 所有现有 widget 测试在重构后通过
- [ ] **TEST-03**: 新 helper 组件有独立单元测试
- [ ] **TEST-04**: mixin 组合的 MockEngine 验证测试

### 平台安全 (PLAT)

- [ ] **PLAT-01**: D3D11 属性必须在 `open()` 调用前设置（否则静默忽略）
- [ ] **PLAT-02**: Win32 DisplayConfig 平台通道冷启动时序正确
- [ ] **PLAT-03**: mdk.Player 单例冲突检测
- [ ] **PLAT-04**: texture ID 生命周期与 Flutter Texture widget 同步

## v2 Requirements

### 架构改进

- **ARCH-01**: FvpEngine 从 547 行精简至 ~200 行
- **ARCH-02**: PlayerEngine 接口从 30+ 方法按 mixin 拆分
- **ARCH-03**: 正式状态机（9 状态，显式转换）
- **ARCH-04**: 错误恢复策略（重试、编解码器回退）

### 平台扩展

- **PLAT-05**: D3D11 配置跨平台抽象
- **PLAT-06**: 热重载引擎交换能力

## Out of Scope

| Feature | Reason |
|---------|--------|
| 引入 media_kit 作为引擎 | API 能力不兼容（无 setProperty/D3D11/均衡器） |
| 将 PlayerEngine 发布为独立包 | 只有一个消费者，增加维护负担 |
| 实现第二个引擎 | 无实际需求，MockEngine 已满足测试 |
| 改变 ValueNotifier 为 Stream | 57 个 UI 文件依赖，收益不明确 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEP-01 | Phase 1 | Pending |
| DEP-02 | Phase 1 | Pending |
| DEP-03 | Phase 1 | Pending |
| DEP-04 | Phase 1 | Pending |
| COMP-01 | Phase 2 | Complete |
| COMP-02 | Phase 2 | Complete |
| COMP-03 | Phase 2 | Complete |
| COMP-04 | Phase 2 | Complete |
| COMP-05 | Phase 2 | Complete |
| IFACE-01 | Phase 3 | Pending |
| IFACE-02 | Phase 3 | Pending |
| IFACE-03 | Phase 3 | Pending |
| IFACE-04 | Phase 3 | Pending |
| IFACE-05 | Phase 3 | Pending |
| TEST-01 | Phase 4 | Pending |
| TEST-02 | Phase 4 | Pending |
| TEST-03 | Phase 4 | Pending |
| TEST-04 | Phase 4 | Pending |
| PLAT-01 | Phase 4 | Pending |
| PLAT-02 | Phase 4 | Pending |
| PLAT-03 | Phase 4 | Pending |
| PLAT-04 | Phase 4 | Pending |

**Coverage:**

- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-29*
*Last updated: 2026-06-29 after initial definition*
