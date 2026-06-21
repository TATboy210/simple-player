# Simple Player Flutter — v1 架构解构

**分析日期:** 2026-06-21
**工具:** code-review-graph MCP (tree-sitter 知识图谱)
**范围:** v1 生产代码，排除 v2/ 原型目录
**图规模:** 1523 节点, 10355 条边, 18 个社区

---

## 1. 社区结构 (v1 有效社区: 16/18)

| 社区 | 节点数 | 内聚度 | 目录 | 职责 |
|------|--------|--------|------|------|
| **player-state** | 333 | 0.33 | `lib/ui/` | 所有 UI 组件、对话框、播放器屏幕 |
| **engine-save** | 232 | 0.45 | `lib/kernel/` | 引擎、持久化、桥接、模型 |
| **services-play** | 68 | 0.50 | `lib/features/player/services/` | 播放服务层 |
| **helpers-subtitle** | 44 | 0.59 | `lib/kernel/services/` | 字幕处理 |
| **runner-window** | 34 | 0.18 | `windows/runner/` | C++ Win32 窗口运行器 |
| **l10n-ago** | 33 | 0.72 | `lib/l10n/` | 国际化 |
| **services-register** | 32 | 0.00 | 测试辅助 | 服务注册 |
| **player-subject** | 31 | 0.03 | 测试辅助 | 测试 subject 构建器 |
| **lib-state** | 11 | 0.35 | `lib/` 状态 | 状态管理 |
| **golden-golden** | 9 | 0.14 | 测试 | Golden 测试 |
| **utils-output** | 8 | 0.15 | `lib/kernel/utils/` | 工具类 |
| **perf-rebuild** | 7 | 0.08 | 测试 | 性能测试 |
| **feature-describe** | 5 | 0.00 | 测试 | Feature 测试 |
| **services-fake** | 3 | 0.17 | 测试 | 测试 Fake |
| **integration** | 3 | 0.00 | 测试 | 集成测试 |
| **scripts-find** | 2 | 0.00 | 脚本 | 构建脚本 |

> egl-mpv (177节点) 和 events-command (202节点) 为 v2 专属社区，已排除。

### 社区内聚度分析

- **高内聚 (>0.5):** l10n-ago (0.72), helpers-subtitle (0.59), services-play (0.50) — 这些模块职责清晰
- **中内聚 (0.3-0.5):** engine-save (0.45), lib-state (0.35), player-state (0.33) — 有耦合但可接受
- **低内聚 (<0.3):** runner-window (0.18), golden-golden (0.14), utils-output (0.15) — 松散组织

---

## 2. 枢纽节点 (Hub Nodes) — v1 过滤

| 节点 | 类型 | 文件 | 度数 | 角色 |
|------|------|------|------|------|
| **SettingsStore** | Class | `lib/kernel/persistence/settings_store.dart` | 37 | 配置中心，25+ save 方法 |
| **FvpEngine** | Class | `lib/kernel/engine/fvp_engine.dart` | 34 | 引擎核心，12+ 职责 |
| **FakeEngine** | Class | `test/helpers/fake_engine.dart` | 33 | 测试替身，镜像引擎接口 |
| **WindowService** | Class | `lib/kernel/bridge/window_service.dart` | 20 | 窗口管理桥接 |
| **VideoProcessingService** | Class | `lib/features/player/services/video_processing_service.dart` | 15 | 视频处理 |
| **KeyboardHandler** | Class | `lib/ui/player/keyboard_handler.dart` | 16 | 键盘快捷键 |
| **AuroraBackground** | Class | `lib/ui/shared/aurora_background.dart` | 16 | 视觉效果 |

### 关键发现

1. **SettingsStore 是最大枢纽** (度37) — 25+ 个 `_save()` 调用者，任何设置变更都经过它
2. **FvpEngine 是第二大枢纽** (度34) — 692 行 god object，承担 12+ 职责
3. **FakeEngine 度数(33) 几乎等于 FvpEngine(34)** — 测试替身与生产代码同等复杂

---

## 3. 桥接节点 (Bridge Nodes) — 架构瓶颈

| 节点 | 中介中心性 | 风险 |
|------|-----------|------|
| **SettingsStore** | 0.000159 | 最高 — 跨越 kernel/persistence 和所有消费者 |
| **FakeEngine** | 0.000094 | 测试基础设施瓶颈 |
| **AppLocalizations** | 0.000046 | 生成代码，低风险 |
| **Playlist** | 0.000027 | 播放列表是数据流枢纽 |
| **WindowService** | 0.000012 | 窗口管理桥接层 |
| **PlaylistItem** | 0.000012 | 数据模型，被广泛引用 |
| **PlaylistStore** | 0.000012 | 持久化层 |
| **VideoProcessingService** | 0.000007 | 视频处理管道 |

### 架构瓶颈分析

- **SettingsStore** 是最大的单点故障 — 修改它影响 37 个下游节点
- **Playlist + PlaylistItem + PlaylistStore** 三件套构成数据流核心
- **WindowService** 是平台抽象的关键桥接点

---

## 4. 执行流 (Flows) — v1 过滤

检测到 13 个执行流，全部来自 C++ runner 层：

| 流名称 | 入口 | 深度 | 节点数 | 关键度 |
|--------|------|------|--------|--------|
| RegisterWithRegistrar | FlutterDesktopPluginRegistrarRegister | 3 | 12 | 0.38 |
| WndProc (x2) | Win32Window::WndProc | 3 | 9 | 0.38 |
| Create (x2) | Win32Window::Create | 2 | 8 | 0.37 |
| ~Win32Window (x2) | Win32Window::~Win32Window | 2 | 4 | 0.29 |
| SetChildContent (x2) | FlutterWindow::SetChildContent | 1 | 2 | 0.32 |
| GetCommandLineArguments (x2) | GetCommandLineArguments | 1 | 2 | 0.36 |

> 注：Dart 层的执行流未被检测到（tree-sitter 对 Dart 的调用图解析有限）

---

## 5. 大文件热点 — v1 过滤 (≥200 行)

| 文件 | 行数 | 语言 | 风险评估 |
|------|------|------|----------|
| `lib/l10n/app_localizations.dart` | 1023 | Dart | ⚪ 生成代码，无需手动维护 |
| **`lib/kernel/engine/fvp_engine.dart`** | **693** | **Dart** | 🔴 **God object — 需要分解** |
| `test/kernel/persistence/settings_store_test.dart` | 677 | Dart | ⚪ 测试文件，规模合理 |
| `test/widget/player/progress_bar_test.dart` | 500 | Dart | ⚪ 测试文件 |
| `test/widget/player/auto_hide_controller_test.dart` | 475 | Dart | ⚪ 测试文件 |
| `lib/l10n/app_localizations_en.dart` | 473 | Dart | ⚪ 生成代码 |
| `lib/l10n/app_localizations_zh.dart` | 471 | Dart | ⚪ 生成代码 |
| **`lib/kernel/persistence/settings_store.dart`** | **440** | **Dart** | 🟡 **单体持久化类 — 考虑拆分** |
| **`lib/ui/dialogs/settings_panel.dart`** | **403** | **Dart** | 🟡 **设置面板 — 可提取子组件** |
| `test/kernel/playlist/playlist_test.dart` | 393 | Dart | ⚪ 测试文件 |
| `test/helpers/fake_engine.dart` | 373 | Dart | 🟡 测试替身过重 |
| **`lib/ui/shared/aurora_background.dart`** | **359** | **Dart** | 🟡 **视觉组件 — 可优化** |
| `test/kernel/services/playback_controller_test.dart` | 343 | Dart | ⚪ 测试文件 |

---

## 6. 知识缺口 (Knowledge Gaps)

### 6.1 孤立节点 (50 个)

主要集中在：
- `lib/features/player/` — 多个 Widget 的 `createState`、`initState`、`build` 方法
- `lib/kernel/bridge/` — WindowService 的各个方法
- `lib/features/player/services/` — VideoProcessingService 的 setter 方法

**原因：** tree-sitter 对 Dart Widget 生命周期方法的调用图解析有限

### 6.2 未测试热点 (v1 过滤)

| 节点 | 度数 | 测试状态 |
|------|------|----------|
| SettingsStore | 37 | ⚠️ 有测试但覆盖不全 |
| FvpEngine | 34 | ⚠️ 依赖 FakeEngine 间接测试 |
| WindowService | 20 | ⚠️ 平台依赖，难以单元测试 |
| VideoProcessingService | 15 | ⚠️ 需要引擎 mock |

### 6.3 单文件社区 (2 个)

- **services-fake** (3 节点) — `subtitle_service_test.dart` 内的 fake
- **perf-rebuild** (7 节点) — `control_bar_perf_test.dart` 性能测试

---

## 7. v1 架构总结

### 依赖方向

```
lib/ui/ (333 nodes)
  ↓ ValueListenableBuilder
lib/features/player/services/ (68 nodes)
  ↓ PlaybackController / VideoProcessingService
lib/kernel/ (232 nodes)
  ↓ FvpEngine / SettingsStore / WindowService
fvp package (外部)
  ↓ MDK/FFmpeg
windows/runner/ (34 nodes)
  ↓ Win32 API
```

### 关键架构特征

1. **3 层架构:** Kernel → Features → UI，依赖单向向下
2. **ValueNotifier 响应式:** 无 Provider/Riverpod/Bloc，纯 ValueListenableBuilder
3. **MethodChannel 桥接:** `com.simple_player/window` 统一通道
4. **Mixin 组合:** PlaybackController 混入 3 个 mixin
5. **fvp 引擎抽象:** PlayerEngine 接口 + FvpEngine 实现 + FakeEngine 测试

### 优先重构建议

| 优先级 | 目标 | 理由 |
|--------|------|------|
| P0 | FvpEngine 分解 (693→<300行) | God object, 12+ 职责 |
| P1 | SettingsStore 拆分 (440→<300行) | 25+ save 方法, 最大枢纽 |
| P2 | SettingsPanel 提取子组件 (403行) | UI 复杂度 |
| P3 | AuroraBackground 优化 (359行) | 视觉组件独立性 |

### 代码规模

- **v1 生产代码:** ~150 个 Dart 文件
- **测试代码:** ~57 个测试文件, 767+ 测试用例
- **C++ Runner:** 4 个文件, ~34 个节点
- **生成代码:** l10n (3 文件, ~2000 行)

---

*Generated by code-review-graph MCP analysis, 2026-06-21*
