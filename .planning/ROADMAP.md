# Roadmap: Player Fullscreen v3 Simplification

**Created:** 2026-07-09
**v3 Phases:** 3
**v3 Requirements:** 8
**Mode:** standard

---

## v1/v2 Phases (已完成)

<details>
<summary>✅ v1.0 Fullscreen Architecture (Phases 1-4) — SHIPPED 2026-07-10</summary>

v1 建立了 FullscreenAdapter、CommandQueue、状态机、错误模型。现已确认过度工程化。

</details>

<details>
<summary>✅ v2.0 Performance (Phase 5) — SHIPPED 2026-07-11</summary>

FFI 路径优化、HWND 缓存、零闪烁过渡。核心 FFI 优化保留。

</details>

---

## v3 Phases — 架构简化

### Phase 8: 删除不必要的抽象层

**Goal:** 删除 Adapter、CommandQueue、4 个 Model 类，减少 ~757 行源码 + ~2,000 行测试
**Requirements:** SIMPLIFY-01, SIMPLIFY-02, SIMPLIFY-03

**Success Criteria:**

1. `fullscreen_adapter.dart` (68行) 已删除
2. `fullscreen_command_queue.dart` (258行) 已删除
3. `fullscreen_snapshot.dart` (127行) 已删除
4. `fullscreen_error.dart` (145行) 已删除
5. `fullscreen_event.dart` (108行) 已删除
6. `fullscreen_request.dart` (51行) 已删除
7. `flutter analyze` 零 error，`flutter test` 全通过

**Plans:**

- [ ] 08-01: 删除 CommandQueue + 4 Model 类
- [ ] 08-02: 删除 FullscreenAdapter 抽象层

---

### Phase 9: 合并与精简

**Goal:** 合并 DesktopFullscreenAdapter 逻辑进 WindowService，精简 Driver 接口到 5 方法
**Requirements:** SIMPLIFY-04, SIMPLIFY-05

**Success Criteria:**

1. WindowService 直接调用 FullscreenDriver，无中间层
2. FullscreenDriver 接口只有 5 个方法
3. 双状态系统已消除（单一 ValueNotifier<bool>）
4. flutter test 全通过

**Plans:**

- [ ] 09-01: WindowService 直接调用 Driver + 简化状态管理
- [ ] 09-02: 精简 FullscreenDriver 接口

---

### Phase 10: 平台整合与测试清理

**Goal:** 借鉴 plugin_platform_interface 建立联合插件地基，macOS/Linux 复用原生代码，清理测试
**Requirements:** SIMPLIFY-06, SIMPLIFY-07, SIMPLIFY-08

**Success Criteria:**

1. FullscreenPlatform 接口使用 PlatformInterface + _token 模式
2. Windows FFI（x86 + ARM 自适应）
3. macOS/Linux 复用 fullscreen_window 原生代码
4. 总代码从 3,248 行减少到 ~800 行
5. 测试从 3,555 行减少到 ~1,500 行

**Plans:**

- [ ] 10-01: FullscreenPlatform 接口 + Windows FFI 实现
- [ ] 10-02: macOS/Linux 原生代码整合
- [ ] 10-03: 测试清理

---

## Progress

| Phase | Plans | Status |
|-------|-------|--------|
| 1-4. v1 架构建立 | 13/13 | ✅ Complete |
| 5. 性能优化 | 4/4 | ✅ Complete |
| 8. 删除抽象层 | 0/2 | Not started |
| 9. 合并与精简 | 0/2 | Not started |
| 10. 平台整合 | 0/3 | Not started |

---

*Last updated: 2026-07-11 — v3 simplification roadmap*
