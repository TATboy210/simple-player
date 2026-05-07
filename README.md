# Simple Player

基于 Flutter + fvp (MDK/FFmpeg) 的桌面媒体播放器。

## 功能

- 视频/音频播放（支持主流格式：MP4/MKV/AVI/FLAC/MP3 等）
- 播放列表管理（4 种模式：顺序/全部循环/单曲循环/随机）
- AB 循环（设 A 点 → 设 B 点 → 清除）
- 多音轨切换 + 均衡器（10 频段预设）
- 外挂字幕加载与轨道切换
- 缩略图预览（进度条悬停显示关键帧）
- 播放历史记录（MRU，最多 50 条）
- 文件拖放添加
- 4 套内置主题（午夜蓝/暗夜紫/极光绿/日落橙）
- 窗口自适应（视频原始分辨率 1:1 映射）

## 快捷键

| 按键 | 功能 |
|------|------|
| `Space` | 播放 / 暂停 |
| `←` / `→` | 前进 / 后退 5 秒 |
| `↑` / `↓` | 音量 +5% / -5% |
| `F` | 全屏切换 |
| `M` | 静音切换 |
| `N` | 上一首 |
| `P` | 下一首 |
| `O` | 打开文件 |
| `A` | AB 循环 — 设 A 点 |
| `B` | AB 循环 — 设 B 点 |
| `S` | 字幕开关 |
| `ESC` | 退出全屏 |

## 构建

### 环境要求

- Flutter SDK 3.11+
- Windows 10/11（目标平台）
- Visual Studio Build Tools（C++ 桌面开发）

### 运行

```bash
flutter pub get
flutter run -d windows
```

### 测试

```bash
flutter test
```

### 分析

```bash
flutter analyze
```

## 架构

```
lib/
├── main.dart                    # 入口（fvp 初始化 + 窗口配置）
├── app.dart                     # MaterialApp
├── core/                        # 业务逻辑（无 UI 依赖）
│   ├── player_adapter.dart      # fvp 封装层，13 个 ValueNotifier
│   ├── player_state.dart        # 9 状态枚举
│   ├── playlist.dart            # 播放列表模型，4 种播放模式
│   └── thumbnail_service.dart   # 缩略图提取（独立 Player + LRU 缓存）
├── models/
│   └── playlist_item.dart       # 数据类（路径 + 名称）
├── persistence/                 # 持久化层
│   ├── history_storage.dart     # MRU 播放历史
│   ├── settings_storage.dart    # 窗口/音量/静音偏好
│   └── playlist_storage.dart    # 播放列表存档
├── ui/
│   ├── screens/
│   │   ├── player_screen.dart   # 主界面（Stack 分层合成）
│   │   └── playback_orchestrator.dart  # 播放业务编排
│   ├── shortcuts/
│   │   └── keyboard_handler.dart # 14 键快捷键处理
│   ├── theme/                   # 设计系统
│   │   ├── theme_config.dart    # 50 Token（编译时常量）
│   │   ├── design_tokens.dart   # 静态访问层
│   │   ├── app_theme.dart       # ThemeData 桥接
│   │   └── ambient_background.dart # 星河粒子动画
│   └── widgets/                 # UI 组件
│       ├── control_bar.dart     # 底部毛玻璃控制栏
│       ├── progress_bar.dart    # 3 层进度条 + 缩略图
│       ├── playlist_panel.dart  # 右侧播放列表面板
│       ├── history_dialog.dart  # 播放历史对话框
│       └── ...                  # 其他组件
└── utils/
    └── time_utils.dart          # formatMs() 共享工具
```

### 状态管理

**ValueNotifier + ValueListenableBuilder** — 无外部依赖。

`PlayerAdapter` 暴露 13 个 ValueNotifier，Widget 通过 `ValueListenableBuilder` 响应式重建。

### 设计系统

- 单一主题：Midnight（编译时常量，零运行时开销）
- 50 个语义 Token（颜色/字体/间距/圆角/动画时长）
- 毛玻璃效果：`BackdropFilter` + `bgGlass` + `borderHighlight`
- 所有视觉值通过 `DesignTokens.*` 访问

## 测试

89 个单元测试覆盖核心逻辑：

| 测试文件 | 数量 | 覆盖 |
|---------|------|------|
| `playlist_test.dart` | 35 | 4 种模式、removeAt、序列化 |
| `time_utils_test.dart` | 12 | formatMs 边界/负数/大值 |
| `settings_storage_test.dart` | 8 | SharedPreferences mock |
| `playlist_item_test.dart` | 8 | 路径名/JSON/相等性 |
| `history_item_test.dart` | 5 | 数据类 + num timestamp |
| `playlist_serialization_test.dart` | 4 | toJson/fromJson 往返 |

## 依赖

| 包 | 用途 |
|----|------|
| [fvp](https://pub.dev/packages/fvp) | MDK/FFmpeg 视频播放引擎 |
| [window_manager](https://pub.dev/packages/window_manager) | 窗口大小/全屏/置顶控制 |
| [file_picker](https://pub.dev/packages/file_picker) | 文件选择对话框 |
| [desktop_drop](https://pub.dev/packages/desktop_drop) | 拖放文件支持 |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 设置持久化 |
| [path_provider](https://pub.dev/packages/path_provider) | 应用数据目录 |

## 许可证

[Apache License 2.0](LICENSE)
