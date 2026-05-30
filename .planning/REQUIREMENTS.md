# Requirements — Simple Player Flutter v1.2.1

**日期:** 2026-05-31
**策略:** 窗口丝滑化（最高优先级）+ 架构精简 + HLS ABR

## v1.2.1 需求

### 窗口丝滑化 (WIN)

- [ ] **WIN-05**: 窗口边框闪烁消除
  - C++ `WM_NCCALCSIZE` 同步帧无边框处理（在 `HandleTopLevelWindowProc` 之前拦截）
  - 保留 `WS_CAPTION` 以维持 DWM 动画能力
  - 移除 Dart 端三重异步边框移除路径冲突
  - 启动时零闪烁（窗口从第一帧起即为无边框）
  - 文件: `windows/runner/flutter_window.cpp`, `windows/runner/win32_window.cpp`, `lib/main.dart`, `lib/app.dart`
  - 风险: Flutter 引擎可能在自定义处理器之前消费 WM_NCCALCSIZE（需要 spike 验证）

- [ ] **WIN-06**: Window 层精简
  - 725 行 4 文件 → 更紧凑的实现
  - 合并 `window_service.dart` + `window_bootstrap.dart` 冗余逻辑
  - 移除已废弃的边框移除代码路径
  - 文件: `lib/kernel/bridge/window_service.dart`, `lib/kernel/bridge/window_bootstrap.dart`, `windows/runner/win32_window.cpp`, `windows/runner/flutter_window.cpp`

### 架构精简 (ARCH)

- [ ] **ARCH-02**: SettingsStore 简化
  - 25+ save 方法 → 通用 `_get<T>`/`_set<T>` 泛型模式
  - 减少样板代码，统一存储接口
  - 文件: `lib/kernel/persistence/settings_store.dart`

- [ ] **ARCH-03**: 单例迁移
  - 6 个 static mutable 单例 → 构造函数注入（DI）
  - 接口定义 + 具体实现分离
  - 提升可测试性，消除隐式全局状态
  - 文件: 涉及 `WindowService`, `PlaybackController`, `SettingsStore`, `PlaylistStore`, `ThumbnailService`, `MediaEngine` 等

- [ ] **PLATFORM-03**: 平台抽象层
  - 定义 `PlatformService` 抽象接口（窗口、系统、路径操作）
  - `WindowsPlatformService` 委托现有 `WindowService`（不重写）
  - 仅接口定义，不做 macOS/Linux 具体实现
  - 文件: `lib/kernel/platform/` (新建)

### HLS 自适应码率 (HLS)

- [ ] **HLS-01**: HLS ABR 流媒体支持
  - 基于吞吐量的带宽估计（EWMA），非 BBA 算法
  - URL 类型路由：`.m3u8` → ABR 配置，其他 → 低延迟配置
  - `fflags +nobuffer` 仅应用于非 HLS URL
  - MDK/FFmpeg 内置 `hls.c` demuxer 变体选择
  - 文件: `lib/kernel/services/abr_service.dart` (新建), `lib/kernel/engine/fvp_engine.dart`
  - 风险: MDK `MediaInfo` 是否暴露比特率/缓冲指标（需要 spike 验证）

## 延后需求 (v1.3+)

- **WIN-07**: 全屏平滑过渡动画 — 被 Flutter 引擎 `HandleTopLevelWindowProc` 拦截阻塞
- **PLATFORM-02**: macOS/Linux 平台实现 — 当前仅需接口定义
- **ARCH-01**: FvpEngine 拆分 — 需要引擎层详细报告

## 不在范围内

| 功能 | 原因 |
|------|------|
| 第三方窗口包 (window_manager) | 自建方案，完全控制 |
| 移动平台 (iOS/Android) | 仅桌面端 |
| 状态管理迁移 (Provider/Riverpod/Bloc) | ValueNotifier 保留 |
| BBA 算法 | 桌面带宽稳定，吞吐量方案覆盖 80% 场景 |
| macOS/Linux 平台实现 | v1.2.1 仅定义接口 |

## 可追溯性

| 需求 | Phase | 状态 | 来源 |
|------|-------|------|------|
| WIN-05 | Phase 13 | 待规划 | 用户请求 + 研究分析 |
| WIN-06 | Phase 13 | 待规划 | 用户请求 |
| ARCH-02 | Phase 15 | 待规划 | 用户请求 |
| ARCH-03 | Phase 15 | 待规划 | 用户请求 |
| PLATFORM-03 | Phase 15 | 待规划 | 用户请求 |
| HLS-01 | Phase 14 | 待规划 | 用户请求 + 研究分析 |

**覆盖率:**
- v1.2.1 需求: 6 个
- 已映射到 phase: 6
- 未映射: 0 ✓

---
*需求定义: 2026-05-31*
*最后更新: 2026-05-31 after v1.2.1 milestone research*
