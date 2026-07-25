# 插件系统架构设计文档

> Simple Player Flutter Plugin System Architecture Design
> Phase: Technical Research | Date: 2026-07-20 | Status: DRAFT

---

## 1. 执行摘要

### 1.1 目标

为 Simple Player Flutter 构建一个轻量级、类型安全的插件系统，使第三方开发者和内部模块能够以解耦的方式扩展播放器功能，而不修改核心内核代码。

### 1.2 核心功能

- **解码器插件**: 支持自定义解码器（如硬件加速、特殊编解码器）
- **渲染器插件**: 替换或增强渲染管线（如自定义 shader、OSD 叠加）
- **UI 插件**: 注入自定义 UI 组件（如弹幕、歌词、水印）
- **功能插件**: 扩展播放器行为（如截图、录制、投屏、字幕下载）
- **事件钩子**: 在播放器生命周期关键节点注入自定义逻辑

### 1.3 预期收益

| 维度 | 当前状态 | 插件化后 |
|------|----------|----------|
| 扩展性 | 需修改内核代码 | 零侵入扩展 |
| 可测试性 | 组件耦合紧 | 插件独立测试 |
| 社区贡献 | 不可能 | 开放插件 API |
| 功能迭代 | 全量编译 | 按需加载 |
| 稳定性 | 核心变更影响全部 | 插件故障隔离 |

---

## 2. 需求分析

### 2.1 解码器扩展

当前 `FvpEngine` 通过 fvp (MDK/FFmpeg) 硬编码解码管线。插件系统需支持:

- **自定义解码器注册**: 注册第三方解码器（如 VP9/AV1 硬件加速、特殊容器格式）
- **解码器优先级**: 多个解码器可用时按优先级选择
- **降级策略**: 解码失败时自动回退到内置解码器
- **Codec 协商**: 根据媒体信息（编解码、分辨率、帧率）匹配最优解码器

```
MediaEngine.open(path)
  → PluginManager.queryDecoders(mediaInfo)
  → 按优先级排序
  → 尝试注册的解码器
  → 失败则回退 FvpEngine 默认
```

### 2.2 渲染器扩展

当前 `RendererControl` 暴露 D3D11 同步和硬件解码开关。插件系统需支持:

- **后处理 Shader**: 在纹理输出后注入自定义 fragment shader（色彩校正、滤镜、LUT）
- **OSD 叠加层**: 在视频帧上叠加自定义内容（字幕渲染、水印、弹幕）
- **渲染器替换**: 完全替换默认渲染管线（如 HDR tone mapping）
- **渲染钩子**: `onBeforeRender` / `onAfterRender` 事件

### 2.3 UI 扩展

当前 UI 层通过 `ValueListenableBuilder` 监听 `EngineStateView`。插件系统需支持:

- **面板注入**: 在设置对话框中注入自定义标签页
- **控件注入**: 在控制栏中注入自定义按钮
- **浮层注入**: 在视频区域叠加自定义浮层（弹幕、歌词）
- **菜单项注入**: 在右键菜单中注入自定义操作

### 2.4 功能扩展

- **文件操作**: 自定义文件打开/拖放处理（如网络流、光盘）
- **元数据**: 自定义媒体信息解析器（如 NFO、CUE sheet）
- **网络**: 自定义协议支持（如 RTSP、HLS 自定义源）
- **持久化**: 自定义设置存储后端
- **快捷键**: 注册自定义全局/局部快捷键

### 2.5 非功能性需求

| 需求 | 目标 |
|------|------|
| 启动开销 | < 50ms（静态插件零开销，动态插件异步加载） |
| 内存开销 | 每个插件 < 1MB 额外内存 |
| API 稳定性 | SemVer 语义化版本，主版本号变更才 breaking |
| 故障隔离 | 单个插件崩溃不影响核心播放 |
| 类型安全 | 编译时类型检查，零 `dynamic` |

---

## 3. 架构设计

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────┐
│                    Application Layer                  │
│  PlayerScreen / ControlsOverlay / SettingsDialog      │
├─────────────────────────────────────────────────────┤
│                   Plugin Host Layer                   │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │ PluginManager│ │ PluginLoader │ │ PluginBus    │ │
│  │  (registry)  │ │  (discovery) │ │  (events)    │ │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ │
├─────────┼────────────────┼────────────────┼─────────┤
│         │          Plugin Interface Layer  │         │
│  ┌──────▼──────────────────────────────────▼──────┐  │
│  │  PlayerPlugin (base)                           │  │
│  │  ├── DecoderPlugin      (解码器扩展)           │  │
│  │  ├── RendererPlugin     (渲染器扩展)           │  │
│  │  ├── UiPlugin           (UI 扩展)              │  │
│  │  ├── FileHandlerPlugin  (文件处理扩展)         │  │
│  │  ├── MetadataPlugin     (元数据扩展)           │  │
│  │  └── LifecycleHookPlugin(生命周期钩子)         │  │
│  └────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│                    Core Engine Layer                  │
│  MediaEngine (EngineStateView + PlaybackControl +     │
│    TrackControl + SubtitleConfig +                    │
│    VideoEffectControl + RendererControl +             │
│    VolumeControl)                                     │
│  PlaybackController / Playlist / Scanner              │
├─────────────────────────────────────────────────────┤
│                    Platform Layer                     │
│  FvpEngine / WindowBridge / MethodChannel             │
└─────────────────────────────────────────────────────┘
```

### 3.2 核心组件

#### 3.2.1 PluginManager

插件系统的中央协调器，负责插件注册、查询、生命周期管理。

```dart
/// 插件管理器 — 中央协调器.
///
/// 管理所有已注册插件的生命周期、查询和事件分发。
/// 作为单例存在，由 [App] 在启动时初始化。
///
/// Contract:
/// - 所有方法在 isolate-safe 范围内操作（不跨 isolate）
/// - 插件注册后不可重复注册（幂等）
/// - dispose 时按注册逆序销毁所有插件
class PluginManager {
  /// 已注册插件表 — key 为插件 ID
  final Map<String, PlayerPlugin> _plugins = {};

  /// 事件总线实例
  final PluginBus _bus;

  /// 插件加载器
  final PluginLoader _loader;

  /// 注册插件（编译时静态注册）
  ///
  /// - [plugin]: 插件实例
  /// - throws: [PluginDuplicateException] 若 ID 已注册
  /// - throws: [PluginDependencyException] 若依赖未满足
  void register(PlayerPlugin plugin);

  /// 按类型查询已注册插件
  ///
  /// - [T]: 插件接口类型（如 DecoderPlugin, RendererPlugin）
  /// - Returns: 按优先级排序的插件列表
  List<T> queryByType<T extends PlayerPlugin>();

  /// 按 ID 查询单个插件
  PlayerPlugin? queryById(String id);

  /// 初始化所有已注册插件（按依赖拓扑排序）
  Future<void> initializeAll();

  /// 销毁所有插件（按注册逆序）
  Future<void> disposeAll();
}
```

#### 3.2.2 PluginInterface

所有插件的基础接口，定义生命周期和元数据。

```dart
/// 插件基础接口 — 所有插件的根类型.
///
/// 每个插件必须声明唯一 ID、版本、依赖列表，
/// 并实现标准生命周期方法。
abstract class PlayerPlugin {
  /// 插件唯一标识符（如 'com.example.subtitle_renderer'）
  String get id;

  /// 插件版本（SemVer 格式）
  String get version;

  /// 插件显示名称
  String get displayName;

  /// 插件描述
  String get description;

  /// 依赖的其他插件 ID 列表
  ///
  /// PluginManager 在初始化时按此列表进行拓扑排序，
  /// 确保被依赖的插件先于依赖方初始化。
  List<String> get dependencies => const [];

  /// 插件优先级（数值越大越优先，默认 0）
  ///
  /// 同类型插件共存时，按此值排序选择。
  int get priority => 0;

  /// 生命周期: 注册后立即调用，用于验证环境
  ///
  /// - 检查平台兼容性、依赖可用性
  /// - throws: [PluginInitException] 若环境不满足
  Future<void> onRegister(PluginContext context);

  /// 生命周期: 所有插件注册完成后调用
  ///
  /// - 可在此访问其他已注册插件
  /// - 可在此注册事件监听
  Future<void> onInitialize(PluginContext context);

  /// 生命周期: 播放器就绪后调用
  ///
  /// - 可在此注册 UI 组件、快捷键
  Future<void> onStart(PluginContext context);

  /// 生命周期: 播放器关闭前调用
  ///
  /// - 释放资源、取消订阅
  Future<void> onStop(PluginContext context);

  /// 生命周期: 从注册表移除时调用
  ///
  /// - 最终清理
  Future<void> onDispose(PluginContext context);
}
```

#### 3.2.3 PluginLoader

插件发现与加载机制。

```dart
/// 插件加载器 — 发现与加载插件.
///
/// 支持三种加载模式:
/// 1. 静态注册: 编译时确定，在 main() 中手动 register
/// 2. 动态发现: 运行时扫描插件目录
/// 3. 热重载: 开发模式下支持插件代码热替换（仅 debug）
class PluginLoader {
  final PluginManager _manager;

  /// 静态注册 — 编译时确定的内置插件
  ///
  /// 在 main() 中调用，零运行时开销。
  /// ```dart
  /// loader.registerBuiltin(MyDecoderPlugin());
  /// loader.registerBuiltin(MyRendererPlugin());
  /// ```
  void registerBuiltin(PlayerPlugin plugin);

  /// 动态发现 — 扫描指定目录
  ///
  /// - [directory]: 插件目录路径
  /// - [recursive]: 是否递归扫描子目录
  /// - Returns: 发现的插件数量
  ///
  /// 扫描规则:
  /// - 查找包含 `plugin.yaml` 清单文件的目录
  /// - 验证清单格式和版本兼容性
  /// - 调用 PluginManager.register() 注册
  Future<int> discoverFromDirectory(
    String directory, {
    bool recursive = false,
  });

  /// 从清单文件加载单个插件
  Future<PlayerPlugin?> loadFromManifest(String manifestPath);
}
```

### 3.3 组件交互序列

```
App 启动
  │
  ├─→ PluginLoader.registerBuiltin(内置插件...)
  │     └─→ PluginManager.register() × N
  │           └─→ plugin.onRegister(context)
  │
  ├─→ PluginManager.initializeAll()
  │     └─→ 拓扑排序 → plugin.onInitialize(context) × N
  │
  ├─→ MediaEngine 初始化
  │     └─→ PluginManager.queryByType<DecoderPlugin>()
  │           └─→ 注册解码器链
  │
  ├─→ PluginManager.queryByType<UiPlugin>()
  │     └─→ 注入 UI 组件到 PlayerScreen
  │
  └─→ PluginManager.queryByType<LifecycleHookPlugin>()
        └─→ 注册事件监听到 PluginBus
```

---

## 4. 插件接口设计

### 4.1 基础接口继承体系

```
PlayerPlugin (abstract)
  │
  ├── DecoderPlugin
  │     decode(MediaSource) → DecodedFrame
  │     canDecode(CodecInfo) → bool
  │
  ├── RendererPlugin
  │     onBeforeRender(Frame)
  │     onAfterRender(Frame)
  │     getShaders() → List<FragmentShader>
  │
  ├── UiPlugin
  │     buildPanel(BuildContext) → Widget?
  │     buildOverlay(BuildContext) → Widget?
  │     buildControlButton(BuildContext) → Widget?
  │     buildMenuItem() → MenuItem?
  │
  ├── FileHandlerPlugin
  │     canHandle(String path) → bool
  │     open(String path) → MediaSource?
  │     getSupportedExtensions() → List<String>
  │
  ├── MetadataPlugin
  │     parse(String path) → Map<String, dynamic>?
  │     getSupportedFormats() → List<String>
  │
  └── LifecycleHookPlugin
        onMediaOpen(MediaInfo)
        onMediaClose()
        onStateChange(MediaState, MediaState)
        onPositionUpdate(int position)
        onSeekComplete(int position)
        onError(PlayerError)
```

### 4.2 解码器插件接口

```dart
/// 解码器插件 — 替换或增强默认解码管线.
///
/// 实现者提供自定义解码器，PluginManager 在 open() 时
/// 按优先级尝试所有注册的解码器插件。
abstract class DecoderPlugin extends PlayerPlugin {
  /// 是否能解码指定媒体
  ///
  /// - [source]: 媒体源信息（路径、格式、编解码）
  /// - Returns: true 表示可以处理
  bool canDecode(MediaSource source);

  /// 执行解码
  ///
  /// - [source]: 媒体源
  /// - [engine]: 引擎实例，用于读取状态和配置
  /// - Returns: 解码结果（成功/失败/降级）
  Future<DecodeResult> decode(MediaSource source, MediaEngine engine);

  /// 解码器能力声明
  ///
  /// 用于 PluginManager 在注册时预筛选。
  DecoderCapabilities get capabilities;
}

/// 解码结果 — sealed class 保证穷举
sealed class DecodeResult {
  const DecodeResult();
}

/// 解码成功
final class DecodeSuccess extends DecodeResult {
  const DecodeSuccess(this.textureId);
  final int textureId;
}

/// 解码失败，建议降级
final class DecodeFallback extends DecodeResult {
  const DecodeFallback(this.reason);
  final String reason;
}

/// 解码错误
final class DecodeError extends DecodeResult {
  const DecodeError(this.error);
  final PlayerError error;
}
```

### 4.3 渲染器插件接口

```dart
/// 渲染器插件 — 在渲染管线中注入后处理逻辑.
///
/// 支持两种模式:
/// 1. 钩子模式: 在默认渲染前后注入逻辑
/// 2. 替换模式: 完全接管渲染管线
abstract class RendererPlugin extends PlayerPlugin {
  /// 渲染模式
  RendererMode get mode;

  /// 前处理钩子 — 在默认渲染前调用
  ///
  /// - [frame]: 当前帧数据
  /// - [state]: 当前播放状态
  /// - Returns: 修改后的帧数据（或原样返回）
  Frame onBeforeRender(Frame frame, EngineStateView state);

  /// 后处理钩子 — 在默认渲染后调用
  ///
  /// - [frame]: 已渲染帧
  /// - [state]: 当前播放状态
  /// - Returns: 修改后的帧数据
  Frame onAfterRender(Frame frame, EngineStateView state);

  /// 注册自定义 fragment shader
  ///
  /// - Returns: shader 列表，按声明顺序执行
  List<FragmentProgram> get shaders => const [];

  /// 渲染管线声明
  ///
  /// 用于 PluginManager 在初始化时验证渲染器兼容性。
  RendererDeclaration get declaration;
}

enum RendererMode {
  /// 钩子模式 — 在默认管线前后注入
  hook,

  /// 替换模式 — 完全接管渲染
  replace,
}
```

### 4.4 UI 插件接口

```dart
/// UI 插件 — 注入自定义界面组件.
///
/// 所有 build 方法返回 null 表示不注入，
/// 返回 Widget 则按声明的位置插入。
abstract class UiPlugin extends PlayerPlugin {
  /// 设置面板标签页
  ///
  /// - [context]: BuildContext
  /// - Returns: 标签页 Widget（含标题和内容），null 表示不注入
  Tab? buildSettingsTab(BuildContext context);

  /// 视频叠加层
  ///
  /// - [context]: BuildContext
  /// - [state]: 当前播放状态（只读）
  /// - Returns: 叠加层 Widget，null 表示不注入
  Widget? buildVideoOverlay(BuildContext context, EngineStateView state);

  /// 控制栏按钮
  ///
  /// - [context]: BuildContext
  /// - Returns: 按钮 Widget，null 表示不注入
  Widget? buildControlButton(BuildContext context);

  /// 右键菜单项列表
  ///
  /// - Returns: 菜单项列表，空表示不注入
  List<MenuItem> buildContextMenuItems();

  /// 浮层 Widget（弹幕、歌词等全屏覆盖层）
  ///
  /// - [context]: BuildContext
  /// - [state]: 当前播放状态（只读）
  /// - Returns: 浮层 Widget，null 表示不注入
  Widget? buildFloatingOverlay(BuildContext context, EngineStateView state);
}
```

### 4.5 生命周期钩子插件接口

```dart
/// 生命周期钩子插件 — 在播放器事件节点注入逻辑.
///
/// 所有钩子方法均为异步，PluginManager 依次调用所有注册的钩子。
/// 单个钩子失败不影响其他钩子执行（故障隔离）。
abstract class LifecycleHookPlugin extends PlayerPlugin {
  /// 媒体打开前
  ///
  /// - [path]: 文件路径
  /// - Returns: true 继续打开，false 阻止打开
  Future<bool> onBeforeMediaOpen(String path) async => true;

  /// 媒体打开后
  ///
  /// - [info]: 媒体元信息
  Future<void> onAfterMediaOpen(MediaInfo info) async {}

  /// 媒体关闭前
  Future<void> onBeforeMediaClose() async {}

  /// 媒体关闭后
  Future<void> onAfterMediaClose() async {}

  /// 状态变更
  ///
  /// - [from]: 旧状态
  /// - [to]: 新状态
  Future<void> onStateChange(MediaState from, MediaState to) async {}

  /// 位置更新（节流后，约每 250ms 一次）
  ///
  /// - [positionMs]: 当前位置（毫秒）
  Future<void> onPositionUpdate(int positionMs) async {}

  /// Seek 完成
  ///
  /// - [positionMs]: seek 目标位置（毫秒）
  Future<void> onSeekComplete(int positionMs) async {}

  /// 播放错误
  ///
  /// - [error]: 错误信息
  Future<void> onError(PlayerError error) async {}

  /// 播放完成（自然播放到末尾）
  Future<void> onPlaybackComplete() async {}
}
```

---

## 5. 加载机制

### 5.1 静态注册（推荐）

编译时确定插件列表，零运行时发现开销。

```dart
// main.dart
void main() async {
  final pluginManager = PluginManager();
  final loader = PluginLoader(pluginManager);

  // 静态注册内置插件
  loader.registerBuiltin(SubtitleRendererPlugin());
  loader.registerBuiltin(ScreenshotPlugin());
  loader.registerBuiltin(DanmakuPlugin());

  // 初始化
  await pluginManager.initializeAll();

  // 正常启动播放器
  runApp(App(pluginManager: pluginManager));
}
```

**优点**: 零发现开销、编译时类型检查、tree-shaking 友好
**适用**: 内置功能插件、核心扩展

### 5.2 动态发现

运行时扫描插件目录，支持第三方插件。

```yaml
# plugin.yaml — 插件清单文件
id: com.example.danmaku
version: 1.0.0
name: 弹幕引擎
description: 视频弹幕渲染插件
entry_point: lib/danmaku_plugin.dart
min_player_version: 1.8.0
dependencies:
  - com.example.subtitle_renderer
permissions:
  - network
  - filesystem
```

```dart
// 动态发现
final count = await loader.discoverFromDirectory(
  '${appDir}/plugins',
  recursive: true,
);
debugPrint('Discovered $count plugins');
```

**优点**: 支持第三方扩展、运行时可插拔
**适用**: 社区插件、实验性功能

### 5.3 热重载（仅 Debug）

开发模式下支持插件代码热替换。

```dart
// debug 模式下的插件热重载
if (kDebugMode) {
  loader.enableHotReload(
    watchDirectory: '${projectDir}/plugins',
    debounce: Duration(milliseconds: 500),
  );
}
```

**限制**: 仅限 Debug 模式、不支持状态保持、不支持新增依赖

### 5.4 加载策略对比

| 策略 | 发现开销 | 类型安全 | 第三方支持 | 适用场景 |
|------|----------|----------|------------|----------|
| 静态注册 | 零 | 编译时 | 不支持 | 内置插件 |
| 动态发现 | 扫描目录 | 运行时 | 支持 | 社区插件 |
| 热重载 | 文件监听 | 运行时 | 支持 | 开发调试 |

---

## 6. 生命周期管理

### 6.1 状态机

```
                 register()
    Created ──────────────────→ Registered
                                   │
                            initializeAll()
                                   │
                                   ▼
                              Initialized
                                   │
                              start()
                                   │
                                   ▼
                               Running ←─── resume()
                                 │             │
                           stop()│             │
                                 ▼             │
                              Stopped ─────────┘
                                 │
                            dispose()
                                 │
                                 ▼
                              Disposed
```

### 6.2 生命周期方法详解

| 阶段 | 方法 | 调用时机 | 典型操作 |
|------|------|----------|----------|
| 注册 | `onRegister` | `PluginManager.register()` 后 | 环境检查、依赖验证 |
| 初始化 | `onInitialize` | 所有插件注册完成后 | 获取其他插件引用、注册事件 |
| 启动 | `onStart` | MediaEngine 就绪后 | 注册 UI 组件、快捷键 |
| 运行中 | — | 正常播放期间 | 响应事件、处理用户交互 |
| 停止 | `onStop` | 播放器关闭前 | 取消订阅、暂停后台任务 |
| 销毁 | `onDispose` | 从注册表移除时 | 释放资源、清理临时文件 |

### 6.3 依赖拓扑排序

```dart
/// 拓扑排序 — 确保依赖先于依赖方初始化.
///
/// Algorithm: Kahn's algorithm (BFS-based topological sort)
/// - 构建依赖图
/// - 计算入度
/// - BFS 遍历，入度为 0 的节点入队
/// - 若存在环 → throw [PluginCircularDependencyException]
List<PlayerPlugin> _topologicalSort(List<PlayerPlugin> plugins) {
  final graph = <String, List<String>>{};
  final inDegree = <String, int>{};

  for (final plugin in plugins) {
    graph[plugin.id] = plugin.dependencies;
    inDegree.putIfAbsent(plugin.id, () => 0);
    for (final dep in plugin.dependencies) {
      inDegree[dep] = (inDegree[dep] ?? 0) + 1;
    }
  }

  final queue = inDegree.entries
      .where((e) => e.value == 0)
      .map((e) => e.key)
      .toList();

  final sorted = <PlayerPlugin>[];
  while (queue.isNotEmpty) {
    final id = queue.removeAt(0);
    sorted.add(plugins.firstWhere((p) => p.id == id));
    for (final dep in graph[id] ?? []) {
      inDegree[dep] = inDegree[dep]! - 1;
      if (inDegree[dep] == 0) queue.add(dep);
    }
  }

  if (sorted.length != plugins.length) {
    throw PluginCircularDependencyException(
      'Circular dependency detected in plugin graph',
    );
  }
  return sorted;
}
```

### 6.4 故障隔离

单个插件的生命周期方法失败不应影响其他插件:

```dart
Future<void> _safeLifecycleCall(
  PlayerPlugin plugin,
  Future<void> Function(PluginContext) method,
  PluginContext context,
) async {
  try {
    await method(context);
  } on Exception catch (e, stack) {
    debugPrint('[PluginManager] Plugin "${plugin.id}" lifecycle error: $e');
    debugPrint(stack.toString());
    // 记录错误但不阻断其他插件
    _pluginErrors[plugin.id] = PluginError(e, stack);
  }
}
```

---

## 7. 通信机制

### 7.1 事件总线 (PluginBus)

插件之间、插件与核心之间的通信通过类型化事件总线实现。

```dart
/// 插件事件总线 — 类型化发布/订阅.
///
/// 使用 [Stream] 实现，支持:
/// - 类型过滤: 只接收指定类型的事件
/// - 优先级: 高优先级监听器先收到事件
/// - 取消订阅: 通过 StreamSubscription 管理
///
/// Contract:
/// - 事件不可变（immutable）
/// - 监听器按优先级降序排列
/// - 同步分发（不跨 isolate）
class PluginBus {
  final StreamController<PluginEvent> _controller =
      StreamController<PluginEvent>.broadcast();

  /// 发布事件
  ///
  /// - [event]: 事件实例（必须不可变）
  void emit(PluginEvent event) {
    _controller.add(event);
  }

  /// 订阅指定类型的事件
  ///
  /// - [T]: 事件类型
  /// - [handler]: 事件处理器
  /// - [priority]: 优先级（数值越大越先执行，默认 0）
  /// - Returns: StreamSubscription，用于取消订阅
  StreamSubscription<T> on<T extends PluginEvent>(
    void Function(T event) handler, {
    int priority = 0,
  }) {
    return _controller.stream
        .where((e) => e is T)
        .cast<T>()
        .listen(handler);
  }
}
```

### 7.2 事件类型体系

```dart
/// 插件事件基类 — 所有事件必须不可变
sealed class PluginEvent {
  const PluginEvent();
  DateTime get timestamp => DateTime.now();
}

// --- 播放事件 ---
final class MediaOpenedEvent extends PluginEvent {
  const MediaOpenedEvent(this.mediaInfo);
  final MediaInfo mediaInfo;
}

final class MediaClosedEvent extends PluginEvent {
  const MediaClosedEvent();
}

final class StateChangedEvent extends PluginEvent {
  const StateChangedEvent(this.from, this.to);
  final MediaState from;
  final MediaState to;
}

final class PositionUpdatedEvent extends PluginEvent {
  const PositionUpdatedEvent(this.positionMs);
  final int positionMs;
}

final class PlaybackErrorEvent extends PluginEvent {
  const PlaybackErrorEvent(this.error);
  final PlayerError error;
}

// --- UI 事件 ---
final class SettingsTabChangedEvent extends PluginEvent {
  const SettingsTabChangedEvent(this.tabIndex);
  final int tabIndex;
}

final class ContextMenuRequestedEvent extends PluginEvent {
  const ContextMenuRequestedEvent(this.position);
  final Offset position;
}

// --- 自定义事件（插件间通信）---
final class CustomPluginEvent extends PluginEvent {
  const CustomPluginEvent(this.sourceId, this.action, this.payload);
  final String sourceId;
  final String action;
  final Map<String, dynamic> payload;
}
```

### 7.3 插件间直接通信

对于需要请求-响应模式的场景，提供服务定位器:

```dart
/// 插件服务定位器 — 按 ID 获取其他插件实例.
///
/// 仅在 onInitialize 及之后的生命周期阶段可用。
/// 在 onRegister 阶段调用会返回 null。
class PluginServiceLocator {
  final PluginManager _manager;

  /// 获取指定 ID 的插件
  T? getPlugin<T extends PlayerPlugin>(String id) {
    final plugin = _manager.queryById(id);
    return plugin is T ? plugin : null;
  }

  /// 获取所有指定类型的插件
  List<T> getPluginsByType<T extends PlayerPlugin>() {
    return _manager.queryByType<T>();
  }
}
```

### 7.4 数据传递

```dart
/// 插件上下文 — 在生命周期方法中传递给插件.
///
/// 包含插件运行所需的所有服务引用。
/// 不可变，每个生命周期阶段创建新实例。
class PluginContext {
  const PluginContext({
    required this.engine,
    required this.bus,
    required this.serviceLocator,
    required this.storage,
  });

  /// 引擎状态视图（只读）
  final EngineStateView engine;

  /// 事件总线
  final PluginBus bus;

  /// 服务定位器
  final PluginServiceLocator serviceLocator;

  /// 插件持久化存储
  final PluginStorage storage;
}

/// 插件存储 — 每个插件独立的键值存储.
///
/// 基于 SharedPreferences，key 自动加插件 ID 前缀。
class PluginStorage {
  PluginStorage(this._pluginId, this._prefs);
  final String _pluginId;
  final SharedPreferences _prefs;

  String _key(String key) => 'plugin.$_pluginId.$key';

  Future<void> setString(String key, String value) =>
      _prefs.setString(_key(key), value);

  String? getString(String key) => _prefs.getString(_key(key));

  Future<void> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);

  bool? getBool(String key) => _prefs.getBool(_key(key));

  // ... 其他类型方法
}
```

---

## 8. 安全与权限

### 8.1 权限模型

每个插件在清单文件中声明所需权限，PluginManager 在注册时验证。

```yaml
# plugin.yaml 中的权限声明
permissions:
  - network          # 网络访问
  - filesystem       # 文件系统读写
  - clipboard        # 剪贴板访问
  - notification     # 系统通知
  - engine_control   # 引擎控制（play/pause/seek）
  - ui_injection     # UI 组件注入
  - renderer_access  # 渲染管线访问
```

### 8.2 权限等级

| 等级 | 权限 | 风险 | 审批策略 |
|------|------|------|----------|
| SAFE | `ui_injection`, `engine_control` | 低 | 自动批准 |
| NORMAL | `filesystem`, `clipboard`, `notification` | 中 | 用户确认 |
| DANGEROUS | `network`, `renderer_access` | 高 | 用户确认 + 每次提醒 |

### 8.3 沙箱隔离

```dart
/// 权限检查器 — 验证插件权限.
///
/// 在插件调用受保护 API 前检查权限。
/// 未授权调用抛出 [PluginPermissionDeniedException]。
class PermissionGuard {
  final Map<String, Set<PluginPermission>> _grantedPermissions;

  /// 检查权限
  ///
  /// - [pluginId]: 插件 ID
  /// - [permission]: 所需权限
  /// - throws: [PluginPermissionDeniedException] 若未授权
  void check(String pluginId, PluginPermission permission) {
    final granted = _grantedPermissions[pluginId] ?? {};
    if (!granted.contains(permission)) {
      throw PluginPermissionDeniedException(
        'Plugin "$pluginId" requires permission: ${permission.name}',
      );
    }
  }

  /// 授予权限
  void grant(String pluginId, PluginPermission permission) {
    _grantedPermissions
        .putIfAbsent(pluginId, () => {})
        .add(permission);
  }
}
```

### 8.4 错误隔离

```dart
/// 插件沙箱 — 包装插件调用，捕获异常.
///
/// 确保单个插件的异常不会传播到核心播放器。
/// 连续失败达到阈值后自动禁用插件。
class PluginSandbox {
  final Map<String, int> _failureCounts = {};
  static const int _maxFailures = 3;

  /// 安全执行插件操作
  Future<T?> execute<T>(
    String pluginId,
    Future<T> Function() operation, {
    T? fallback,
  }) async {
    try {
      final result = await operation();
      _failureCounts[pluginId] = 0; // 重置失败计数
      return result;
    } on Exception catch (e, stack) {
      _failureCounts[pluginId] =
          (_failureCounts[pluginId] ?? 0) + 1;

      debugPrint(
        '[PluginSandbox] Plugin "$pluginId" failed '
        '(${_failureCounts[pluginId]}/$_maxFailures): $e',
      );

      if (_failureCounts[pluginId]! >= _maxFailures) {
        debugPrint(
          '[PluginSandbox] Plugin "$pluginId" auto-disabled after $_maxFailures failures',
        );
        // 通知 PluginManager 禁用该插件
        PluginManager.instance.disablePlugin(pluginId);
      }

      return fallback;
    }
  }
}
```

---

## 9. 实施路线图

### Phase 1: 核心框架（2 周）

**目标**: 最小可用插件系统，支持静态注册和基础生命周期。

| 任务 | 估时 | 优先级 |
|------|------|--------|
| 定义 `PlayerPlugin` 基础接口 | 2h | P0 |
| 实现 `PluginManager` (注册/查询/生命周期) | 4h | P0 |
| 实现 `PluginBus` (事件总线) | 3h | P0 |
| 实现 `PluginContext` 和 `PluginStorage` | 2h | P0 |
| 拓扑排序算法 + 循环依赖检测 | 2h | P0 |
| 故障隔离 (PluginSandbox) | 2h | P0 |
| 单元测试 (80%+ 覆盖率) | 4h | P0 |

**交付物**:
- `lib/kernel/plugin/` 目录下 6 个文件
- 30+ 单元测试
- 示例内置插件（截图插件）

**里程碑**: 可以注册、初始化、销毁一个内置插件

### Phase 2: 功能接口（3 周）

**目标**: 实现所有功能插件接口，与现有播放器集成。

| 任务 | 估时 | 优先级 |
|------|------|--------|
| `DecoderPlugin` 接口 + FvpEngine 集成 | 6h | P0 |
| `RendererPlugin` 接口 + Texture 管线集成 | 8h | P1 |
| `UiPlugin` 接口 + PlayerScreen 注入点 | 6h | P1 |
| `LifecycleHookPlugin` 接口 + PlaybackController 钩子 | 4h | P0 |
| `FileHandlerPlugin` 接口 + file_operations 集成 | 3h | P1 |
| `MetadataPlugin` 接口 + media_info 集成 | 2h | P2 |
| 权限系统 (PermissionGuard) | 3h | P1 |
| PluginLoader 动态发现 | 4h | P1 |
| 集成测试 | 6h | P0 |

**交付物**:
- 完整插件接口层
- 与 PlaybackController、PlayerScreen 的集成
- 3 个示例插件（截图、OSD、生命周期日志）
- 50+ 集成测试

**里程碑**: 可以通过插件扩展解码、渲染、UI

### Phase 3: 生态建设（4 周）

**目标**: 插件文档、示例、CLI 工具、第三方支持。

| 任务 | 估时 | 优先级 |
|------|------|--------|
| 插件模板项目（mason brick） | 4h | P1 |
| 插件开发文档（API reference + guide） | 6h | P0 |
| 示例插件集合（5+ 个） | 8h | P1 |
| PluginLoader 热重载支持 | 4h | P2 |
| 插件版本兼容性检查 | 3h | P1 |
| 插件性能监控 | 3h | P2 |
| 插件发布 CLI 工具 | 4h | P2 |

**交付物**:
- 插件开发指南 (docs/plugin-development.md)
- 5+ 完整示例插件
- mason brick 模板
- 插件 API 文档

**里程碑**: 第三方开发者可以独立开发和发布插件

### 总时间线

```
Week 1-2:  Phase 1 — 核心框架
Week 3-5:  Phase 2 — 功能接口
Week 6-9:  Phase 3 — 生态建设
```

---

## 10. 设计模式

### 10.1 采用的设计模式

| 模式 | 应用位置 | 目的 |
|------|----------|------|
| **Registry** | `PluginManager._plugins` | 集中管理插件实例 |
| **Strategy** | `DecoderPlugin`, `RendererPlugin` | 运行时切换实现 |
| **Observer** | `PluginBus` (发布/订阅) | 松耦合事件通信 |
| **Template Method** | `PlayerPlugin` 生命周期 | 标准化生命周期流程 |
| **Chain of Responsibility** | 解码器优先级链 | 按优先级尝试解码 |
| **Facade** | `PluginContext` | 简化插件访问核心服务 |
| **Adapter** | `PluginStorage` | 统一存储接口 |
| **Sandbox** | `PluginSandbox` | 故障隔离 |
| **Service Locator** | `PluginServiceLocator` | 插件间发现 |
| **Builder** | `Tab?`, `Widget?` 返回值 | 可选组件注入 |

### 10.2 与现有架构的对齐

| 现有模式 | 插件系统对应 |
|----------|--------------|
| `MediaEngine` ISP 分解 (7 接口) | `PlayerPlugin` 接口分解 (6 接口) |
| `ValueNotifier` + `ValueListenableBuilder` | `PluginBus` 事件流 |
| `PlaybackController` 编排 | `PluginManager` 编排 |
| `Tokens.*` 设计令牌 | 插件 UI 注入遵循 Tokens |
| Sealed class 错误处理 | `DecodeResult`, `PluginEvent` sealed |
| `debugPrint` 日志 | 插件沙箱统一日志 |

### 10.3 关键设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 事件总线 vs 直接引用 | 事件总线为主，直接引用为辅 | 松耦合，插件可独立测试 |
| 同步 vs 异步生命周期 | 异步 | 插件可能需要 I/O（网络、文件） |
| 全局单例 vs 注入 | 注入 (PluginContext) | 可测试性，避免隐式依赖 |
| 编译时 vs 运行时类型检查 | 编译时优先 | Dart 类型系统优势，零运行时开销 |
| 插件数量限制 | 无硬限制 | 由 PluginSandbox 软限制（失败计数） |
| 事件同步 vs 异步分发 | 同步 | 保持事件顺序，简化调试 |

### 10.4 反模式警告

| 反模式 | 说明 | 预防 |
|--------|------|------|
| God Plugin | 单个插件做太多事 | 接口分离，每种功能一个插件 |
| 隐式依赖 | 插件依赖未声明的其他插件 | 拓扑排序 + 依赖声明验证 |
| 同步阻塞 | 插件在主线程做耗时操作 | PluginSandbox 超时检测 |
| 状态泄漏 | 插件持有核心对象强引用 | PluginContext 提供只读视图 |
| 事件风暴 | 插件在高频事件中做重操作 | 事件节流 + 优先级机制 |

---

## 附录 A: 文件结构

```
lib/kernel/plugin/
├── plugin_manager.dart          # 中央协调器
├── plugin_loader.dart           # 发现与加载
├── plugin_bus.dart              # 事件总线
├── plugin_context.dart          # 插件上下文
├── plugin_storage.dart          # 持久化存储
├── plugin_sandbox.dart          # 故障隔离
├── permission_guard.dart        # 权限检查
├── plugin_service_locator.dart  # 服务定位器
├── interfaces/
│   ├── player_plugin.dart       # 基础接口
│   ├── decoder_plugin.dart      # 解码器接口
│   ├── renderer_plugin.dart     # 渲染器接口
│   ├── ui_plugin.dart           # UI 接口
│   ├── file_handler_plugin.dart # 文件处理接口
│   ├── metadata_plugin.dart     # 元数据接口
│   └── lifecycle_hook_plugin.dart # 生命周期钩子
├── events/
│   ├── plugin_event.dart        # 事件基类
│   ├── playback_events.dart     # 播放相关事件
│   └── ui_events.dart           # UI 相关事件
├── models/
│   ├── decode_result.dart       # 解码结果 sealed class
│   ├── renderer_declaration.dart # 渲染器声明
│   └── plugin_manifest.dart     # 清单文件模型
└── exceptions/
    ├── plugin_exception.dart    # 异常基类
    ├── plugin_duplicate_exception.dart
    ├── plugin_dependency_exception.dart
    └── plugin_permission_exception.dart
```

## 附录 B: 与 fvp 的集成点

| 插件类型 | fvp 集成点 | 集成方式 |
|----------|------------|----------|
| DecoderPlugin | `Player.onEvent` codec 回调 | 拦截 + 降级 |
| RendererPlugin | `TextureRegistrar` | 帧后处理 hook |
| LifecycleHookPlugin | `PlaybackController` 状态变更 | 事件订阅 |
| FileHandlerPlugin | `file_operations.dart` | 路径拦截 |
| UiPlugin | `PlayerScreen` Stack | Widget 注入 |

## 附录 C: 参考资料

- Flutter Plugin Architecture: https://docs.flutter.dev/development/packages-and-plugins
- mpv Lua Scripting: https://mpv.io/manual/master/#lua-scripting
- VS Code Extension API: https://code.visualstudio.com/api
- Obsidian Plugin API: https://docs.obsidian.md/Plugins/Getting+started
- SemVer: https://semver.org/
