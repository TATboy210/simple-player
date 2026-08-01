# 文件选择器单开与 Attention 机制调研

## 背景与目标

播放器的“打开文件”可在原生文件选择器尚未关闭时被再次触发。若每个入口都直接调用 `file_picker`，会产生多个系统对话框，导致窗口遮挡、焦点混乱，以及多个媒体打开请求争用同一个播放器实例。

本方案的目标是：

1. 在一个 `PlayerFeature` 生命周期内，任意时刻最多创建一个系统 picker 会话。
2. 重复触发不创建第二个 picker，改为向现有 picker 发出 best-effort attention 请求。
3. 按 picker 返回顺序串行打开媒体，避免并发打开。
4. 取消、空结果、可恢复异常和组件销毁都不能让会话 guard 永久占用。
5. 原生 attention 失败只能降级，不能影响已有会话或回退为创建第二个 picker。

## 最终采用的分层方案

采用“Dart 层会话协调器 + 原生平台 attention 通道”：

- `FilePickerCoordinator` 是唯一的会话仲裁点，负责单开、顺序播放、错误收尾与销毁隔离。
- `FilePickerMediaGateway` 只适配 `file_picker` 静态 API，并将选中项转换为路径列表。
- `MethodChannelFilePickerAttention` 只请求原生平台向已有 picker 提供 attention。
- Windows、macOS、Linux runner 注册相同 MethodChannel：`com.simple_player/file_picker_attention`。
- 原生层的聚焦与提示音只是辅助反馈；单开正确性完全由 Dart 协调器保证。

这样将可跨平台测试的并发控制放在 Dart 层，而将各窗口系统的焦点能力局限在对应 runner。

## 端到端调用链

### UI 入口与 Dart 调用链

所有“打开文件”入口最终复用 `PlayerFeature._openFile()`，共享同一 `FilePickerCoordinator`，而不各自直接调用 `FilePicker.pickFiles()`。

```text
空状态页按钮 / 控制栏文件夹按钮 / 错误恢复入口 / 键盘 O
        │
        ▼
PlayerFeature._openFile()
        │
        ▼
FilePickerCoordinator.open()
        ├─ 空闲：FilePickerGateway.pickMediaPaths()
        │          │
        │          ▼
        │   FilePickerMediaGateway
        │          │
        │          ▼
        │   FilePicker.pickFiles(...)
        │
        └─ 已有会话：FilePickerAttention.requestAttention()
                    │
                    ▼
             MethodChannelFilePickerAttention
                    │
                    ▼
       com.simple_player/file_picker_attention
                 focusExistingPicker
```

首次 `open()` 会先把 `_isPicking` 置为 `true`，再等待 picker 结果。若返回有效路径，则以 `await` 串行调用 `openAndPlay(path)`；`PlayerFeature` 注入的回调实际调用 `_services.controller.openAndPlay(path)`。

播放链路为：

```text
FilePickerCoordinator
  → PlayerFeature 注入的 openAndPlay
  → PlaybackController.openAndPlay(path)
  → FileOperations.openAndPlay(path)
  → PathValidator.validate(path)
  → 播放列表更新与播放器打开
```

`FilePickerMediaGateway` 使用 `PathValidator.supportedExtensions` 做选择器 UI 层过滤。真实路径校验仍在播放链路的 `PathValidator.validate(path)` 中完成，因此 UI 过滤不替代系统边界校验。

### 选择器适配层

`FilePickerMediaGateway.pickMediaPaths()` 调用：

```dart
FilePicker.pickFiles(
  type: FileType.custom,
  allowedExtensions: PathValidator.supportedExtensions,
  lockParentWindow: true,
)
```

其行为如下：

- 使用媒体扩展名白名单过滤文件对话框内容；
- `lockParentWindow: true` 维持 Windows 父窗口的模态关系；
- 取消选择返回 `null`；
- `PlatformFile.path == null` 的项会被过滤；
- 路径列表保持 picker 返回顺序，并由协调器串行消费。

### 原生 MethodChannel 调用链

Dart 端固定使用：

```dart
const MethodChannel('com.simple_player/file_picker_attention')
    .invokeMethod<void>('focusExistingPicker');
```

各平台对应的处理位置：

| 平台 | 原生文件 | `focusExistingPicker` 行为 |
|---|---|---|
| Windows | `windows/runner/flutter_window.cpp` | 定位本进程拥有的 Common Dialog，尝试前置并响铃。 |
| macOS | `macos/Runner/MainFlutterWindow.swift` | 定位 attached `NSOpenPanel` sheet，尝试前置并响铃。 |
| Linux | `linux/runner/my_application.cc` | 仅触发 GTK system bell，不尝试跨进程聚焦 picker。 |

## 会话状态、生命周期与错误语义

协调器使用两个布尔状态表达关键语义：

| 状态 | 含义 |
|---|---|
| `_isPicking == false` | 不存在未完成的 picker 会话；允许新建会话。 |
| `_isPicking == true` | 正在等待 picker 返回或串行打开所选路径；重复触发只能请求 attention。 |
| `_isDisposed == false` | `PlayerFeature` 仍有效，结果可继续交给播放服务。 |
| `_isDisposed == true` | 组件已销毁；迟到 picker 结果及剩余路径必须忽略。 |

```text
Idle
  │ open()
  ▼
Picking
  ├─ open() again → AttentionRequested → Picking
  ├─ cancel / empty result → Idle
  ├─ picker exception → Idle
  ├─ paths returned → PlayingSelectedPaths
  └─ dispose() → Disposed

PlayingSelectedPaths
  ├─ 全部路径打开完成 → Idle
  ├─ openAndPlay 抛出 Exception → Idle
  └─ dispose() → Disposed

Disposed
  └─ open() / 迟到 picker 结果 → ignored
```

### 结果和异常处理

| 情形 | 当前行为 | 后续可再次打开 |
|---|---|---|
| 用户取消 | 返回 `null`，不播放。 | 可以；`finally` 释放 guard。 |
| 空路径列表 | 不播放。 | 可以；`finally` 释放 guard。 |
| 多个路径 | 按返回顺序逐个 `await openAndPlay(path)`。 | 当前批次结束后可以。 |
| picker 抛出 `Exception` | 记录会话失败日志。 | 可以；`finally` 释放 guard。 |
| 某一路径播放抛出 `Exception` | 记录日志，停止当前批次，不播放后续路径。 | 可以；`finally` 释放 guard。 |
| attention 抛出 `Exception` | 记录 attention 不可用日志。 | 保持进行中的 guard；绝不新建第二个 picker。 |
| picker 返回前组件销毁 | 忽略其全部结果。 | 不适用。 |
| 多文件播放中组件销毁 | 当前 await 自行结束；下一路径前检测销毁状态，不启动剩余路径。 | 不适用。 |

协调器仅处理可恢复的 `Exception`，不捕获 Dart `Error` 子类；编程错误不能被当作可恢复 picker 故障吞掉。

## 平台实现与能力边界

### Windows

Windows handler 会枚举顶层窗口，并将候选窗口限制为：

1. 当前 Flutter 进程；
2. 可见；
3. owner 为当前 Flutter 主窗口；
4. Common Dialog class 为 `#32770`。

找到后调用 `SetForegroundWindow()`，无论该请求是否被 Windows foreground policy 拒绝，都会调用 `MessageBeep(MB_OK)`。因此不会按标题或全局枚举结果误激活其他应用窗口。

**边界：** `SetForegroundWindow()` 可能被系统的前台策略拒绝。返回值只说明本次激活调用是否成功，不保证用户一定看见 picker。提示音是这一情形下的明确降级反馈，不会触发第二个 picker。

### macOS

macOS handler 检查主窗口的 `attachedSheet` 是否为 `NSOpenPanel`；存在时调用 `makeKeyAndOrderFront(nil)`，随后调用 `NSBeep()`。它不会创建新的 panel。

**边界：** 只识别附着于当前主窗口的 `NSOpenPanel`，不会扫描或操作其他应用、其他窗口或非 sheet 面板。`makeKeyAndOrderFront` 是前置请求，不能表述为无条件抢占焦点。没有找到 panel 时仍响铃，表示 attention 请求已被触发，而非定位成功。

### Linux

Linux handler 取得当前 GTK 活动窗口并调用 `gtk_widget_error_bell()`；它刻意不调用 `gtk_window_present()`，也不尝试定位选择器。

**边界：** XDG Desktop Portal 或 Wayland chooser 往往由外部进程托管，应用无法安全、可靠地取得和激活其窗口。Linux 的 attention 含义仅是 GTK 系统提示音；不会把播放器错误置顶，也不承诺将外部 picker 带到前台。

## 自动化测试与验收矩阵

`test/features/player/file_picker_coordinator_test.dart` 以 fake gateway、attention 和播放器验证 Dart 层语义，不启动真实原生对话框。

| 场景 | 自动化状态 | 验证内容 |
|---|---|---|
| 重复触发 | 已覆盖 | picker 只调用一次；attention 调用一次。 |
| 多文件 | 已覆盖 | 顺序播放；最大并发播放数为 1。 |
| 取消与空列表 | 已覆盖 | guard 释放，可再次打开。 |
| picker 异常 | 已覆盖 | guard 释放，可再次打开。 |
| 首项播放失败 | 已覆盖 | 当前批次停止，后续路径不播放，能重试。 |
| picker 返回前销毁 | 已覆盖 | 迟到结果不访问播放服务。 |
| 多文件播放中销毁 | 已覆盖 | 不启动剩余路径。 |
| attention 异常 | 已覆盖 | 不创建第二个 picker，进行中的 guard 不释放。 |
| Windows Common Dialog 前置与响铃 | Windows 人工验收完成 | 用户确认实际行为正确。 |
| macOS attached `NSOpenPanel` | 未验收 | 需要 macOS 主机人工测试。 |
| Linux portal / Wayland bell 降级 | 未验收 | 需要 Linux 主机人工测试。 |

已执行的自动化验证：

```bash
flutter test test/features/player/file_picker_coordinator_test.dart \
  test/widget/player/auto_hide_controller_test.dart \
  test/widget/player/control_bar_test.dart \
  test/widget/player/volume_controls_test.dart
flutter analyze
flutter build windows --debug
```

相关测试共 92 项通过，`flutter analyze` 无问题，Windows Debug 构建成功。Linux 与 macOS 由于当前环境限制，尚未构建或手工验收。

## 不采用的方案

### 每个 UI 入口直接调用 `FilePicker.pickFiles`

不采用。不同入口无法建立统一互斥语义，重复点击会产生多个原生对话框，也无法集中处理销毁、异常和顺序播放。

### 仅在 UI 层禁用按钮或做防抖

不采用。入口还包括快捷键和错误恢复；局部 UI 禁用不能覆盖组合根会话状态、异步异常或组件销毁，且无法给重复触发提供 attention 反馈。

### Dart 层保存句柄并强制关闭或跨平台聚焦 picker

不采用。`file_picker` 不提供统一可靠的原生句柄与取消协议；Windows Common Dialog、macOS sheet 和 Linux portal 的所有权与生命周期不同。强制关闭还可能丢失用户进行中的选择。

### attention 失败后创建第二个 picker

不采用。前置失败可能只是系统焦点策略限制，不代表原 picker 不存在。创建新 picker 会直接破坏单开保证；Linux 本身就是 bell-only 降级场景。

## 结论

`FilePickerCoordinator` 在 Dart 层保证“至多一个未完成 picker 会话”、串行播放、异常恢复与销毁隔离。MethodChannel 将 attention 的平台差异封装在各桌面 runner 中。

该设计保证应用不会重复创建 picker，并在重复触发时提供平台能力允许范围内的前置请求或提示音；它不承诺绕过操作系统焦点策略，也不把 Linux Portal/Wayland 的外部 chooser 错误描述为可被应用强制激活。
