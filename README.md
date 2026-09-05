<p align="center">
  <img src="docs/readme-icon.png" width="160" alt="Simple Player" />
</p>

<h1 align="center">Simple Player</h1>

<p align="center">
  基于 Flutter 与 media_kit (libmpv) 的桌面媒体播放器<br/>
  <sub>A Flutter + media_kit (libmpv) desktop media player</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11-02569B?logo=flutter&logoColor=white" alt="Flutter 3.11" />
  <img src="https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white" alt="Dart 3" />
  <img src="https://img.shields.io/badge/engine-media__kit_(libmpv)-00B4D8" alt="media_kit" />
  <img src="https://img.shields.io/badge/platform-Windows_10%2F11-0078D6?logo=windows&logoColor=white" alt="Windows" />
  <img src="https://img.shields.io/badge/version-0.0.1-orange" alt="version" />
  <img src="https://img.shields.io/badge/license-Apache_2.0-blue.svg" alt="Apache 2.0" />
</p>

---

## 概述 / Overview

**中文：** Simple Player 是一款使用 Flutter 构建的桌面媒体播放器，播放后端基于 [media_kit](https://pub.dev/packages/media_kit)（封装 libmpv / FFmpeg），支持主流视频与音频格式。项目采用 `ValueNotifier` + `ValueListenableBuilder` 响应式状态管理（无 Provider / Riverpod / Bloc），单一 Midnight 毛玻璃设计系统，全部视觉值经 `Tokens.*` 语义化访问。

**English:** Simple Player is a desktop media player built with Flutter, powered by [media_kit](https://pub.dev/packages/media_kit) (libmpv / FFmpeg) for playback of all common video and audio formats. It uses `ValueNotifier` + `ValueListenableBuilder` for reactive state (no Provider / Riverpod / Bloc), a single Midnight glassmorphism design system, and semantic design tokens (`Tokens.*`).

## 功能特性 / Features

- **全格式播放** — libmpv / FFmpeg 后端，支持 MP4 / MKV / AVI / MOV / FLAC / MP3 等主流格式
- **多音轨与字幕** — 音轨切换、外挂字幕加载与轨道切换、字幕延迟微调
- **文件拖放** — 拖拽文件直接加入播放列表
- **窗口自适应** — 视频原始分辨率 1:1 映射，resize 防抖与几何持久化
- **无缝全屏** — 基于 `WindowMode` 单一数据源，进出全屏无边缘缝隙 / 图标错位
- **20+ 键盘快捷键** — 含媒体键
- **国际化** — 中英双语（ARB + 生成代码）
- **毛玻璃设计系统** — 单一 Midnight 主题，编译时常量，零运行时开销

## 快捷键 / Keyboard Shortcuts

| 按键 / Key | 功能 / Action |
|------------|---------------|
| `Space` | 播放 / 暂停 · Play / Pause |
| `←` / `→` | 后退 / 前进 5 秒 · Seek ±5s |
| `↑` / `↓` | 音量 +5% / -5% · Volume ±5% |
| `F` | 全屏切换 · Toggle fullscreen |
| `M` | 静音切换 · Toggle mute |
| `N` | 上一首 · Previous track |
| `P` | 下一首 · Next track |
| `O` | 打开文件 · Open file |
| `S` | 字幕开关 · Toggle subtitle |
| `[` / `]` | 字幕延迟 ±500ms · Subtitle delay ±500ms |
| `F1` / `?` | 快捷键帮助 · Show shortcuts help |
| `ESC` | 退出全屏 / 关闭播放列表 · Exit fullscreen / Close playlist |
| 媒体键 / Media keys | 播放暂停、上一首、下一首 · Play/Pause, Next, Previous |

## 架构 / Architecture

```
lib/
├── main.dart                    # 入口（media_kit 初始化 + 窗口配置）
├── app.dart                     # MaterialApp 外壳
├── kernel/                      # 核心逻辑（无 UI 依赖）
│   ├── engine/                  # media_kit (libmpv) 引擎 — ISP 多接口
│   ├── window_bridge/           # 窗口控制抽象与实现
│   ├── models/                  # 数据类（播放列表项 / 媒体状态 / 播放模式 / 媒体信息）
│   ├── persistence/             # 播放列表与设置存储
│   ├── playlist/                # 播放列表模型 + 播放模式逻辑
│   ├── scanner/                 # 目录视频文件扫描
│   ├── services/                # 播放编排 / 缩略图 / 视频处理 / 文件操作
│   └── utils/                   # 时间与路径工具
├── ui/
│   ├── theme/                   # 设计 Tokens
│   ├── player/                  # 播放器界面（Stack 分层合成）
│   ├── playlist/                # 浮动播放列表
│   ├── shared/                  # 复用组件（毛玻璃容器 / 空状态）
│   ├── widgets/                 # OSD 浮层
│   └── dialogs/                 # 设置 / 媒体信息对话框
└── l10n/                        # 国际化（ARB + 生成代码）
```

### 状态管理 / State Management

**`ValueNotifier` + `ValueListenableBuilder`** — 无 Provider / Riverpod / Bloc。

- `MediaEngine` 通过 `ValueNotifier` 暴露播放状态（位置、音量、静音等）
- `PlaybackController` 编排播放列表与引擎状态
- Widget 通过 `ValueListenableBuilder` 响应式重建

### 设计系统 / Design System

- 单一主题：Midnight（编译时常量）
- 设计 Tokens 位于 `ui/theme/tokens.dart` — `Tokens.*` 静态常量
- 毛玻璃：`BackdropFilter` + `bgGlass` + `borderHighlight`
- 全部视觉值经 `Tokens.*` 访问，无硬编码

## 构建与运行 / Build & Run

### 环境要求 / Prerequisites

- Flutter SDK 3.11+
- Windows 10/11（目标平台）
- Visual Studio Build Tools（C++ 桌面开发）

### 运行 / Run

```bash
flutter pub get
flutter run -d windows
```

### 构建发布 / Release build

```bash
flutter build windows
```

## 测试 / Testing

```bash
flutter test          # 单元与组件测试
flutter analyze       # 静态分析（strict-casts / inference / raw-types 全开）
```

86 个测试文件覆盖核心逻辑。

## 依赖 / Dependencies

| 包 / Package | 用途 / Purpose |
|--------------|-----------------|
| [media_kit](https://pub.dev/packages/media_kit) | libmpv / FFmpeg 播放引擎 + 桌面控件 |
| [window_manager](https://pub.dev/packages/window_manager) | 窗口尺寸 / 全屏 / 置顶 |
| [file_picker](https://pub.dev/packages/file_picker) | 文件选择对话框 |
| [desktop_drop](https://pub.dev/packages/desktop_drop) | 拖放文件 |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 设置持久化 |
| [path_provider](https://pub.dev/packages/path_provider) | 应用数据目录 |

完整依赖见 [`pubspec.yaml`](pubspec.yaml)。

## 协议 / License

本项目源代码基于 **[Apache License 2.0](LICENSE)** 授权。

> **第三方 LGPL 组件声明 / Third-party LGPL components:** 本应用动态链接并分发由 [media_kit](https://github.com/media-kit/media-kit) 打包的 **libmpv** 与 **FFmpeg** 二进制，二者以 **LGPLv2.1+** 授权。依据 LGPL 条款：
> - libmpv / FFmpeg 源码可从上游项目获取（[FFmpeg](https://ffmpeg.org)、[mpv](https://mpv.io)、[media_kit libs builds](https://github.com/media-kit/libmpv-win32-video-build)）
> - 用户可替换随应用分发的 libmpv 二进制（动态链接）
> - 相关源码获取与重链接信息见 [`NOTICE`](NOTICE)

## 贡献 / Contributing

欢迎提交 Issue 与 Pull Request。提交前请确保：

- `dart format .` 通过
- `flutter analyze` 零 error
- `flutter test` 通过
- 遵循 Conventional Commits（`feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`）

---

<sub>Built with Flutter · Powered by media_kit (libmpv)</sub>
