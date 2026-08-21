# Simple Player Flutter 贡献者指南

欢迎为 Simple Player Flutter 做贡献！本指南帮助你快速上手开发流程。

## 目录

1. [开发环境搭建](#1-开发环境搭建)
2. [代码规范](#2-代码规范)
3. [提交规范](#3-提交规范)
4. [测试要求](#4-测试要求)
5. [PR 流程](#5-pr-流程)
6. [架构概述](#6-架构概述)

---

## 1. 开发环境搭建

### 前置条件

| 依赖 | 版本要求 | 说明 |
|------|---------|------|
| Flutter SDK | 3.x (Dart ^3.11.5) | 需启用桌面平台支持 |
| Visual Studio | 2022+ | Windows 开发需要 C++ 桌面开发工作负载 |
| Xcode | 14+ | macOS 开发需要 |
| GTK 3 + CMake | - | Linux 开发需要 |
| D3D11 兼容 GPU | - | Windows 硬件加速解码 |

### 快速开始

```bash
# 1. 克隆仓库
git clone <repo-url>
cd simple_player_flutter

# 2. 安装依赖
flutter pub get

# 3. 运行项目
flutter run -d windows    # Windows
flutter run -d macos      # macOS
flutter run -d linux      # Linux

# 4. 静态分析
flutter analyze

# 5. 运行测试
flutter test
```

### 代码生成

项目使用 `freezed` 生成不可变数据类。修改 `@freezed` 注解的类后需重新生成：

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 编译时标志

| 标志 | 默认值 | 说明 |
|------|-------|------|
| `USE_WINDOWS_NATIVE_FULLSCREEN` | `false` | 启用 Win32 FFI 全屏驱动 |

使用方式：

```bash
flutter run -d windows --dart-define=USE_WINDOWS_NATIVE_FULLSCREEN=true
```

---

## 2. 代码规范

### 2.1 核心原则

- **KISS** — 选择最简单能工作的方案，避免过度设计
- **DRY** — 提取重复逻辑，但仅在重复真实存在时引入抽象
- **YAGNI** — 不提前构建未被需要的功能或抽象
- **不可变性** — 始终创建新对象，永不修改已有对象（使用 `copyWith`）

### 2.2 类型安全（严格模式）

项目在 `analysis_options.yaml` 中启用了严格类型检查：

```yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

**必须遵守：**

- 禁止使用 `!`（bang 操作符）— 优先使用 `?.`、`??`、`if (x != null)`
- 禁止使用 `late` — 优先使用可空类型或构造函数初始化
- 禁止使用 `as` 强转 — 使用 `is` 类型检查 + 模式匹配
- 所有局部变量使用 `final`，编译时常量使用 `const`
- 必须提供的构造函数参数使用 `required`

```dart
// 错误
final name = user!.name;
final item = data as Map<String, dynamic>;

// 正确
final name = user?.name ?? 'Unknown';
if (data is Map<String, dynamic>) {
  final item = data;
}
```

### 2.3 函数与文件大小

| 类型 | 限制 |
|------|------|
| 纯逻辑函数 | < 20 行 |
| UI 构建函数 | < 50 行 |
| 文件 | < 500 行（最大 800 行） |

超过限制时拆分为更小的函数或提取模块。

### 2.4 命名规范

| 类别 | 风格 | 示例 |
|------|------|------|
| 文件名 | `snake_case.dart` | `display_config.dart` |
| 类/枚举 | `PascalCase` | `MediaState`, `PlayMode` |
| 枚举值 | `PascalCase` | `PlayMode.loopAll` |
| 变量/函数 | `camelCase` | `getRefreshRate()` |
| 私有成员 | `_前缀` | `_cachedHz`, `_initImpl()` |
| 布尔 getter | `is/has/should/can` 前缀 | `isPrimary`, `hasTracks` |
| 常量 | `static const` | `static const bgDeep = Color(...)` |
| 测试文件 | `_test.dart` 后缀 | `control_bar_test.dart` |

### 2.5 注释规范（强制 — 编写代码时同步写注释）

**核心原则：写一段功能代码，立即补该段注释，再写下一段。注释是代码的一部分。**

触发条件（遇到以下任一情况必须写注释）：

- **公开类/mixin/非平凡函数** → `///` doc comment，说明用途、参数、行为
- **非显而易见的逻辑**（魔法数字、算法步骤、副作用）→ 行内注释解释 *why*
- **状态变更、I/O 操作、外部调用** → 标注 side effect
- **3 步以上的顺序变换** → 逐步注释
- **TODO/FIXME** → 附带简要说明

注释语言：中文注释可以使用（项目现有惯例）。

```dart
// 错误 — 没有解释为什么
final adjusted = (raw * 0.85 + offset).clamp(0, maxValue);

// 正确 — 解释了原因
// 应用显示器 EDID 的 15% 过扫描补偿，然后钳位到面板最大值
final adjusted = (raw * 0.85 + offset).clamp(0, maxValue);
```

### 2.6 错误处理

- 指定 `on` 子句中的异常类型 — 禁止裸 `catch (e)`
- 禁止捕获 `Error` 子类型 — 它们表示编程 bug
- 所有错误必须显式处理，提供用户友好的错误消息
- 使用 `debugPrint()` + 优雅降级，永不静默 `catch (_) {}`

```dart
try {
  final result = await riskyOperation();
} on FileSystemException catch (e) {
  logEngine.e('[FvpEngine.open] 文件操作失败: $e');
  state.value = MediaState.error;
} on Exception catch (e) {
  logEngine.e('[FvpEngine.open] 未知错误: $e');
}
```

### 2.7 异步最佳实践

- 始终 `await` Future，或显式调用 `unawaited()` 表示 fire-and-forget
- 如果函数从不 `await`，不要标记为 `async`
- 在任何 `await` 之后使用 `BuildContext` 前检查 `context.mounted`
- 并发操作使用 `Future.wait`

```dart
// fire-and-forget
unawaited(EnginePrewarm.prewarm(...));

// await 后检查 mounted
await someAsyncOperation();
if (!context.mounted) return;
```

### 2.8 设计系统

所有视觉值必须通过 `Tokens.*` 静态常量访问，禁止硬编码颜色、字体或间距：

```dart
// 正确
color: Tokens.controlBarBg,
borderRadius: BorderRadius.circular(Tokens.controlBarRadius),

// 错误
color: Color(0xFF0C0F18),
borderRadius: BorderRadius.circular(16),
```

Glass-morphism 模式：

```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
  child: Container(
    decoration: BoxDecoration(
      color: Tokens.bgGlass,
      border: Border.all(color: Tokens.borderHighlight),
    ),
  ),
)
```

### 2.9 状态管理

项目使用 **ValueNotifier + ValueListenableBuilder**，不使用 Provider/Riverpod/Bloc：

```dart
// 引擎状态
final ValueNotifier<MediaState> state = ValueNotifier(MediaState.idle);
final ValueNotifier<int> position = ValueNotifier(0);

// Widget 重建
ValueListenableBuilder<int>(
  valueListenable: engine.position,
  builder: (context, value, child) {
    return Text(formatMs(value));
  },
)
```

### 2.10 Import 组织

按以下顺序排列 import：

1. Dart SDK: `dart:async`, `dart:io`, `dart:ui`
2. Flutter: `package:flutter/material.dart`
3. 第三方: `package:fvp/mdk.dart`, `package:logger/logger.dart`
4. 项目: `package:simple_player_flutter/...`
5. 相对路径: `../../helpers/fake_engine.dart`

### 2.11 FFI / C++ 桥接模式

- 在 `finally` 块中释放 FFI 内存 — `malloc.free()` 对应 `toNativeUtf8()`
- 跨线程传递的字符串必须复制 — `const char*` 可能在调用后被释放
- 文档记录内存所有权 — 谁分配，谁释放
- MethodChannel 命名: `com.simple_player/window`

### 2.12 日志

使用项目提供的模块化 logger，不要使用 `print()`：

```dart
logEngine.d('[FvpEngine] open: $path');           // 引擎模块
logBridge.e('[DisplayConfig] 检测失败: $e\n$st');  // 桥接模块
logServices.w('[PlaybackController] 重试失败');     // 服务模块
logUi.i('[PlayerScreen] 全屏切换');                 // UI 模块
```

### 2.13 静态分析检查清单

提交前确保通过以下检查：

- [ ] `flutter analyze` 零警告
- [ ] 代码可读且命名清晰
- [ ] 函数 < 50 行，文件 < 500 行
- [ ] 嵌套不超过 4 层
- [ ] 错误显式处理
- [ ] 无硬编码值（使用常量或 Tokens）
- [ ] 无 mutation（使用不可变模式）
- [ ] `debugPrint()` 而非 `print()`
- [ ] 内核层 (`lib/kernel/`) 不使用 `debugPrint`（使用 `KernelLogger`）

---

## 3. 提交规范

### 3.1 Commit Message 格式

```
<type>: <description>

<optional body>
```

### 3.2 类型

| 类型 | 用途 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat: 添加字幕延迟调节` |
| `fix` | 修复 bug | `fix: 全屏切换时控制栏不隐藏` |
| `refactor` | 重构（不改变行为） | `refactor: 提取 PlaybackNavigator` |
| `docs` | 文档更新 | `docs: 更新架构文档` |
| `test` | 添加或修改测试 | `test: 添加 DisplayConfig 单元测试` |
| `chore` | 构建/工具/依赖 | `chore: 升级 fvp 到 0.37.2` |
| `perf` | 性能优化 | `perf: Semantics 排除减少 58%` |
| `ci` | CI/CD 变更 | `ci: 添加 Flutter analyze 步骤` |

### 3.3 Commit 最佳实践

- 描述使用祈使句（动词开头）
- 第一行不超过 72 字符
- 正文解释 **为什么** 而非 **做了什么**
- 关联相关 issue：`Fixes #123`

### 3.4 分支命名

```
feat/<feature-name>      # 新功能
fix/<bug-description>    # Bug 修复
refactor/<scope>         # 重构
docs/<scope>             # 文档
```

---

## 4. 测试要求

### 4.1 最低覆盖率：80%

### 4.2 测试类型

| 类型 | 目录 | 用途 |
|------|------|------|
| 单元测试 | `test/unit/`, `test/kernel/` | 纯 Dart 逻辑、模型、工具函数 |
| Widget 测试 | `test/widget/` | UI 组件 (`testWidgets`) |
| 集成测试 | `test/integration/` | 多组件流程 |
| Golden 测试 | `test/golden/` | 视觉回归测试 |
| 回归测试 | `test/regression/` | 高风险区域、关键路径 |
| 性能测试 | `test/perf/` | 性能基准测试 |

### 4.3 运行测试

```bash
flutter test                                    # 运行所有测试
flutter test --watch                            # 监听模式
flutter test --coverage                         # 覆盖率报告
flutter test test/kernel/bridge/display_config_test.dart  # 单个文件
```

### 4.4 测试结构（AAA 模式）

```dart
test('60Hz 返回同步模式 (1)', () {
  // Arrange — 准备测试数据
  final hz = 60;

  // Act — 执行被测操作
  final result = DisplayConfig.syncModeForHz(hz);

  // Assert — 验证结果
  expect(result, '1');
});
```

### 4.5 测试命名

使用描述性名称，说明被测行为：

```dart
test('返回空数组当没有匹配的市场', () {});
test('缺少 API key 时抛出错误', () {});
test('Redis 不可用时回退到子字符串搜索', () {});
```

### 4.6 Mock 策略

项目使用**手写 Fake**（不使用 mockito/mocktail）：

```dart
/// FakeEngine — 手写测试替身，用于验证引擎接口契约。
///
/// 通过调用计数和可控行为，验证 PlaybackController 等上层组件的正确性。
class FakeEngine with EngineState, TrackControl, VideoEffects {
  int openCallCount = 0;
  String? failNextOpenWith;

  void configureMedia({int durationMs = 60000}) {
    _mediaInfo = MediaInfo(duration: durationMs, ...);
  }

  void simulateError(String message) {
    state.value = MediaState.error;
    errorMessage.value = message;
  }
}
```

**Mock 原则：**

- 需要 Mock：平台特定 API（FFI、MethodChannel）、外部依赖（文件系统、网络）、复杂服务（引擎、窗口管理器）
- 不需要 Mock：纯 Dart 逻辑（使用真实实现）、ValueNotifier（使用真实实例）、简单数据类

### 4.7 测试助手

位于 `test/helpers/`：

| 文件 | 用途 |
|------|------|
| `fake_engine.dart` | 引擎测试替身，带调用计数 |
| `fake_window_service.dart` | 窗口服务测试替身 |
| `integration_helpers.dart` | 集成测试工具函数 |

### 4.8 测试中的 Widget 构建

```dart
Widget buildSubject() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 200,
        child: ControlBar(engine: engine),
      ),
    ),
  );
}

testWidgets('渲染无错误', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.pump();
  expect(find.byType(ControlBar), findsOneWidget);
});
```

### 4.9 测试清理

```dart
late FakeEngine engine;

setUp(() {
  engine = FakeEngine();
});

tearDown(() {
  engine.dispose();
});
```

### 4.10 测试规则

- 禁止跳过测试或删除断言 — 失败的测试可以接受，静默失败不行
- 测试中的控制器名称必须唯一：`'test-${name}-${DateTime.now().millisecondsSinceEpoch}'`
- Widget 测试同时充当集成测试 — 测试完整应用流程，而非隔离组件

---

## 5. PR 流程

### 5.1 创建 PR 前

1. 确保所有自动化检查通过
2. 解决合并冲突
3. 分支与目标分支保持同步
4. 运行 `flutter analyze` 确保零警告
5. 运行 `flutter test` 确保所有测试通过
6. 检查测试覆盖率 >= 80%

### 5.2 PR 描述模板

```markdown
## 变更描述

简要描述此 PR 做了什么。

## 变更类型

- [ ] 新功能 (feat)
- [ ] Bug 修复 (fix)
- [ ] 重构 (refactor)
- [ ] 文档 (docs)
- [ ] 测试 (test)

## 测试计划

- [ ] 已添加/更新单元测试
- [ ] 已通过 `flutter analyze`
- [ ] 已通过 `flutter test`
- [ ] 覆盖率 >= 80%

## 截图/录屏（如适用）

## 关联 Issue

Fixes #<issue-number>
```

### 5.3 代码审查

**审查触发条件（强制）：**

- 编写或修改代码后
- 提交到共享分支前
- 安全敏感代码变更时
- 架构变更时

**审查清单：**

- [ ] 代码可读且命名清晰
- [ ] 函数聚焦（< 50 行）
- [ ] 文件内聚（< 800 行）
- [ ] 无深层嵌套（> 4 层）
- [ ] 错误显式处理
- [ ] 无硬编码密钥或凭证
- [ ] 无 `print()` 或调试语句
- [ ] 新功能有测试
- [ ] 测试覆盖率 >= 80%

**审查严重级别：**

| 级别 | 含义 | 行动 |
|------|------|------|
| CRITICAL | 安全漏洞或数据丢失风险 | **阻塞** — 合并前必须修复 |
| HIGH | Bug 或重大质量问题 | **警告** — 建议合并前修复 |
| MEDIUM | 可维护性问题 | **信息** — 建议修复 |
| LOW | 风格或小建议 | **可选** |

**批准标准：**

- **Approve**: 无 CRITICAL 或 HIGH 问题
- **Warning**: 仅有 HIGH 问题（谨慎合并）
- **Block**: 发现 CRITICAL 问题

### 5.4 PR 工作流

```bash
# 1. 从主分支创建特性分支
git checkout master
git pull
git checkout -b feat/my-feature

# 2. 开发并提交
git add .
git commit -m "feat: 添加我的功能"

# 3. 推送并创建 PR
git push -u origin feat/my-feature

# 4. 在 GitHub 上创建 PR，填写描述模板
```

### 5.5 安全检查清单

提交前必须确认：

- [ ] 无硬编码密钥（API keys、密码、tokens）
- [ ] 所有用户输入已验证
- [ ] 文件路径已消毒（防路径穿越）
- [ ] 错误消息不泄露敏感数据

---

## 6. 架构概述

### 6.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                    Entry Layer                           │
│  main.dart → app.dart → DeferredPlayerFeature           │
└──────────────────────────┬──────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
┌──────────────────────┐  ┌──────────────────────────────┐
│     Kernel Layer     │  │       Features Layer          │
│   lib/kernel/        │  │   lib/features/player/        │
│                      │  │                                │
│  ┌──────┐ ┌───────┐  │  │  ┌──────────────────────┐     │
│  │Engine│ │Bridge │  │  │  │  PlayerServices (DI)  │     │
│  │(fvp) │ │(Win32)│  │  │  └──────────┬───────────┘     │
│  └──────┘ └───────┘  │  │             │                 │
│  ┌──────┐ ┌───────┐  │  │  ┌──────────▼───────────┐     │
│  │Models│ │Persist│  │  │  │ PlaybackController    │     │
│  └──────┘ └───────┘  │  │  │ (Facade pattern)      │     │
│  ┌─────────────────┐  │  │  └──────────────────────┘     │
│  │ Services/Utils  │  │  └──────────────────────────────┘
│  └─────────────────┘  │
└──────────┬───────────┘
           ▼
┌──────────────────────────────────────────────────────────┐
│                      UI Layer                             │
│                      lib/ui/                              │
│  ┌────────┐ ┌────────┐ ┌───────┐ ┌──────┐ ┌────────┐   │
│  │ Player │ │Playlist│ │Shared │ │Widgets│ │Dialogs │   │
│  │ Screen │ │ Panel  │ │(Glass)│ │ (OSD) │ │(Settings│  │
│  └────────┘ └────────┘ └───────┘ └──────┘ └────────┘   │
│                tokens.dart (Design Tokens)                │
└──────────────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│                  Platform Layer (Native)                   │
│  windows/ (Win32 FFI) │ macos/ (Swift) │ linux/ (GTK)    │
└──────────────────────────────────────────────────────────┘
```

### 6.2 各层职责

| 层 | 目录 | 职责 |
|----|------|------|
| Entry | `lib/main.dart`, `lib/app.dart` | 应用引导、MaterialApp 外壳、主题/语言设置 |
| Kernel | `lib/kernel/` | 核心逻辑、平台抽象、数据模型、持久化 |
| Features | `lib/features/player/` | 业务逻辑组合、DI 容器、播放控制 |
| UI | `lib/ui/` | 所有视觉组件和用户交互 |
| Platform | `windows/`, `macos/`, `linux/` | 平台原生代码 |

### 6.3 核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| `FvpEngine` | `kernel/engine/fvp_engine.dart` | fvp/MDK 引擎封装，6 个辅助组合 |
| `PlaybackController` | `features/player/services/playback_controller.dart` | Facade：统一入口，组合 navigator + fileOps + monitor |
| `WindowBridge` | `kernel/window_bridge/window_bridge.dart` | 窗口管理抽象接口（3 状态 + 命令） |
| `Playlist` | `kernel/playlist/playlist.dart` | 状态机：有序项、当前索引、3 种播放模式 |
| `PlayerScreen` | `ui/player/player_screen.dart` | 主播放器 UI：组合键盘 + 控制 + 视频 |
| `Tokens` | `ui/theme/tokens.dart` | 编译时设计令牌：颜色、间距、圆角 |
| `GlassContainer` | `ui/shared/glass_container.dart` | 可复用毛玻璃包装器 |

### 6.4 状态管理

- **ValueNotifier + ValueListenableBuilder** — 无 Provider/Riverpod/Bloc
- `MediaEngine` 通过 ValueNotifier 暴露播放状态（position、volume、mute 等）
- `PlaybackController` 协调播放列表 + 引擎状态
- Widget 通过 `ValueListenableBuilder` 包装器重建
- `MergedListenable` 合并多个 notifier
- 无全局状态容器 — 服务持有各自的 notifier

### 6.5 数据流（播放路径）

```
用户触发播放 (文件选择/拖放/播放列表)
  → PlaybackController.openAndPlay(path)
    → PlaybackNavigator.playIndex(index)
      → FvpEngine.open(path)
        → MediaState.loading → idle
      → PlaybackNavigator 恢复断点、检测字幕
      → FvpEngine.play()
        → MediaState.playing, 启动 PositionPoller
  → UI 通过 ValueListenableBuilder 重建
```

### 6.6 设计模式

| 模式 | 应用位置 |
|------|---------|
| Facade | `PlaybackController` — 统一播放控制入口 |
| Factory | `DesktopFullscreenDriverFactory` — 平台特定驱动选择 |
| Observer | `StateMonitor` — 引擎状态监听 |
| Dependency Inversion | `PlaybackContract` — 子模块依赖倒置 |
| Immutable Value Object | `VideoProcessingState`, `PlaylistItem` — `copyWith` 不可变更新 |
| State Machine | `MediaStateTransition` — 合法状态转换守卫 |
| Deferred Loading | `DeferredPlayerFeature` — 延迟加载重模块 |
| Mixin Composition | `EngineState`, `TrackControl`, `VideoEffects` — 引擎能力组合 |

### 6.7 错误处理策略

**策略：防御性 catch + 日志 + 优雅降级。永不崩溃。**

- `SettingsStore.load()` 返回安全默认值（永不向调用方抛异常）
- `FvpEngine._guardedAction()` 包装所有引擎操作：disposed 检查 + try-catch + 错误类型分类
- `PlaybackNavigator.playIndex()` 失败时恢复旧播放列表索引
- `WindowService._handleEnter/Leave()` 返回 bool 成功状态，调用方回滚

### 6.8 平台层

| 平台 | 技术 | 关键功能 |
|------|------|---------|
| Windows | Win32 FFI (user32.dll, D3D11) | 全屏、显示枚举、窗口控制 |
| macOS | Swift/C++ | 原生窗口管理 |
| Linux | GTK | 原生窗口管理 |

### 6.9 关键依赖

| 依赖 | 用途 |
|------|------|
| `fvp` ^0.37.2 | MDK/FFmpeg 播放引擎，D3D11 硬件解码 |
| `window_manager` ^0.5.2 | 窗口管理（无边框、全屏、标题栏） |
| `ffi` ^2.1.0 | Win32 API FFI 绑定 |
| `shared_preferences` ^2.5.5 | 设置持久化 |
| `hotkey_manager` ^0.2.3 | 全局快捷键 |
| `desktop_drop` ^0.7.1 | 拖放文件支持 |

---

## 快速参考

### 常用命令

```bash
flutter pub get                    # 安装依赖
flutter run -d windows             # 运行（Windows）
flutter analyze                    # 静态分析
flutter test                       # 运行测试
flutter test --coverage            # 覆盖率
dart run build_runner build        # 代码生成
dart format .                      # 格式化代码
```

### 关键文件

| 文件 | 用途 |
|------|------|
| `pubspec.yaml` | 依赖和项目配置 |
| `analysis_options.yaml` | Lint 规则和严格模式 |
| `lib/ui/theme/tokens.dart` | 设计令牌（所有视觉值） |
| `lib/kernel/engine/fvp_engine.dart` | 播放引擎核心 |
| `lib/features/player/services/playback_controller.dart` | 播放控制入口 |
| `test/helpers/fake_engine.dart` | 测试替身 |

### 有用的链接

- [Flutter 文档](https://docs.flutter.dev/)
- [Dart 文档](https://dart.dev/guides)
- [fvp 插件](https://github.com/wang-bin/fvp)
- [项目文档目录](../) — 详细架构文档
