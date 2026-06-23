# Flutter Window-Only 重构计划

## 核心原则

**Flutter 只负责 3 件事：**
1. **窗口功能** — Win32 窗口管理（MethodChannel + C++ runner）
2. **Widget Tree** — UI 组件树（控件、布局、动画）
3. **功能控件** — 用户可交互的播放控制（播放/暂停/进度条/音量等）

**其他所有逻辑下沉或删除。**

---

## 当前架构问题

| 问题 | 现状 | 目标 |
|------|------|------|
| Flutter 承担业务逻辑 | kernel/ 5,612 行（引擎配置、播放列表、设置持久化、缩略图等） | kernel/ → 只保留窗口桥接 + 引擎接口 |
| features/ 层冗余 | 960 行协调器（PlaybackController、StateMonitor 等） | 删除或合并到 ui/ |
| 引擎配置过度封装 | 7 个 Configurator 类（D3D11、网络、字幕、音量等） | 合并为 1 个 EngineConfig |
| 设置持久化过度 | SettingsStore 439 行（25+ save 方法） | 简化为 key-value 通用模式 |
| 缩略图服务跨平台 | 4 个 ThumbnailProvider（Windows/Linux/macOS/Noop） | 删除非 Windows 实现 |

---

## 目标架构（2 层）

```
lib/
├── main.dart                      # 入口（fvp init + 窗口启动）
├── app.dart                       # MaterialApp 壳
├── window/                        # 窗口功能层
│   ├── window_service.dart        # Win32 窗口控制（合并 bootstrap + service）
│   ├── display_config.dart        # 显示配置
│   └── custom_title_bar.dart      # 自定义标题栏（从 ui/ 移入）
├── engine/                        # 引擎接口层（极薄）
│   ├── fvp_engine.dart            # fvp 引擎封装（精简版）
│   └── engine_config.dart         # 合并所有 Configurator
├── player/                        # 播放器 UI（widget tree + 功能控件）
│   ├── player_screen.dart         # 主屏幕
│   ├── control_bar.dart           # 控制栏
│   ├── progress_bar.dart          # 进度条
│   ├── volume_controls.dart       # 音量控件
│   ├── speed_button.dart          # 倍速控件
│   ├── center_controls.dart       # 中央播放按钮
│   ├── controls_overlay.dart      # 控件覆盖层
│   ├── video_surface.dart         # 视频渲染表面
│   ├── keyboard_handler.dart      # 键盘快捷键
│   ├── drop_handler.dart          # 拖放处理
│   └── auto_hide_controller.dart  # 自动隐藏
├── playlist/                      # 播放列表 UI
│   ├── playlist_panel.dart        # 播放列表面板
│   ├── folder_tab.dart            # 文件夹标签
│   ├── history_tab.dart           # 历史标签
│   └── thumbnail_tile.dart        # 缩略图瓦片
├── dialogs/                       # 对话框
│   ├── settings_panel.dart        # 设置面板
│   └── media_info_dialog.dart     # 媒体信息
├── shared/                        # 共享组件
│   ├── glass_container.dart       # 毛玻璃容器
│   ├── glass_chip.dart            # 毛玻璃标签
│   ├── aurora_background.dart     # 极光背景
│   ├── empty_state.dart           # 空状态
│   ├── osd_overlay.dart           # OSD 浮窗
│   └── tokens.dart                # 设计令牌
├── l10n/                          # 国际化（保留）
└── utils/                         # 工具函数（极简）
    ├── time_utils.dart            # 时间格式化
    └── path_utils.dart            # 路径工具
```

**文件数：95 → ~35（减少 63%）**
**代码行数：14,924 → ~6,000（减少 60%）**

---

## 删除/合并清单

### 第 1 阶段：删除冗余层（-2,500 行）

| 操作 | 文件 | 行数 | 原因 |
|------|------|------|------|
| **删除** | `features/player/` 整个目录 | 960 | 协调器冗余，UI 直接调用 engine |
| **删除** | `kernel/persistence/playlist_store.dart` | 218 | 播放列表不需要持久化（文件系统即真相） |
| **删除** | `kernel/playlist/playlist.dart` | 283 | 播放列表逻辑内联到 UI 层 |
| **删除** | `kernel/scanner/folder_scanner.dart` | 72 | 内联到播放列表 UI |
| **删除** | `kernel/startup/` 目录 | 166 | 启动协调过度，main.dart 直接初始化 |
| **删除** | `kernel/utils/perf_monitor.dart` | 160 | 性能监控非核心 |
| **删除** | `kernel/utils/memory_monitor.dart` | 57 | 内存监控非核心 |
| **删除** | `kernel/utils/log.dart` | 284 | 日志过度，用 debugPrint 即可 |
| **删除** | `kernel/services/path_validator.dart` | 115 | 路径验证内联 |
| **删除** | `kernel/services/thumbnail_service.dart` + providers | 164 | 缩略图由引擎或 OS 处理 |
| **删除** | `kernel/models/player_error.dart` | 61 | 错误类型过度定义 |
| **删除** | `kernel/models/validation_error.dart` | 41 | 验证错误过度定义 |

### 第 2 阶段：合并引擎层（-1,500 行）

| 操作 | 文件 | 行数 | 说明 |
|------|------|------|------|
| **合并** | 7 个 Configurator → `engine_config.dart` | ~80 | D3D11、网络、字幕、音量、视频效果合并 |
| **精简** | `fvp_engine.dart` | 486 → ~200 | 删除 delegated 方法，直接暴露 mdk.Player |
| **删除** | `media_opener.dart` | 166 | open 逻辑内联到 fvp_engine |
| **删除** | `position_poller.dart` | 119 | 用 mdk.Player 回调替代轮询 |
| **删除** | `track_manager.dart` | 70 | 轨道管理内联 |
| **删除** | `fvp_callback_handler.dart` | 99 | 回调处理内联 |
| **删除** | `engine_prewarm.dart` | 71 | 预热过度，延迟初始化即可 |
| **删除** | `open_result.dart` | 22 | 返回类型过度定义 |

### 第 3 阶段：精简设置持久化（-800 行）

| 操作 | 文件 | 行数 | 说明 |
|------|------|------|------|
| **重写** | `settings_store.dart` | 439 → ~100 | 通用 key-value 模式，删除 25+ 专用方法 |
| **删除** | `app_settings.dart` | 167 | 设置模型过度，直接用 Map |
| **合并** | `theme_service.dart` + `locale_service.dart` | 84 → 0 | 设置直接读写，不需要 Service |

### 第 4 阶段：精简 UI 层（-500 行）

| 操作 | 文件 | 行数 | 说明 |
|------|------|------|------|
| **合并** | `controls_overlay.dart` + `center_controls.dart` | 337 → ~150 | 控件层扁平化 |
| **删除** | `error_banner.dart` | 102 | 错误处理简化为 SnackBar |
| **删除** | `splash_screen.dart` + `progress_splash_screen.dart` | 144 | 启动画面过度 |
| **删除** | `settings_card.dart` + `settings_expander_card.dart` + `settings_action_card.dart` | 515 | 设置卡片重复，合并为 1 个 |
| **删除** | `setting_action_row.dart` + `setting_slider_row.dart` | 252 | 设置行组件重复，合并为 1 个 |
| **删除** | `value_listenable_builder2.dart` + `merged_listenable.dart` | 53 | 自定义 ValueListenable 工具，用 Flutter 内置 |

---

## 保留的核心文件（~35 个）

### 窗口功能（4 个）
- `window/window_service.dart` — Win32 窗口控制
- `window/display_config.dart` — 显示配置
- `window/custom_title_bar.dart` — 自定义标题栏
- `main.dart` — 入口

### 引擎接口（2 个）
- `engine/fvp_engine.dart` — fvp 引擎封装（精简版）
- `engine/engine_config.dart` — 引擎配置（合并版）

### 播放器 UI（11 个）
- `player/player_screen.dart`
- `player/control_bar.dart`
- `player/progress_bar.dart`
- `player/volume_controls.dart`
- `player/speed_button.dart`
- `player/center_controls.dart`
- `player/controls_overlay.dart`
- `player/video_surface.dart`
- `player/keyboard_handler.dart`
- `player/drop_handler.dart`
- `player/auto_hide_controller.dart`

### 播放列表 UI（4 个）
- `playlist/playlist_panel.dart`
- `playlist/folder_tab.dart`
- `playlist/history_tab.dart`
- `playlist/thumbnail_tile.dart`

### 对话框（2 个）
- `dialogs/settings_panel.dart`
- `dialogs/media_info_dialog.dart`

### 共享组件（8 个）
- `shared/glass_container.dart`
- `shared/glass_chip.dart`
- `shared/aurora_background.dart`
- `shared/empty_state.dart`
- `shared/osd_overlay.dart`
- `shared/tokens.dart`
- `shared/app_dialog.dart`
- `shared/context_menu_row.dart`

### 工具（4 个）
- `utils/time_utils.dart`
- `utils/path_utils.dart`
- `l10n/`（3 个文件，保留）

---

## 实施步骤

### Phase 1：删除冗余层（1 天）
1. 删除 `features/` 整个目录
2. 删除 `kernel/persistence/playlist_store.dart`
3. 删除 `kernel/playlist/playlist.dart`
4. 删除 `kernel/scanner/folder_scanner.dart`
5. 删除 `kernel/startup/` 目录
6. 删除 `kernel/utils/` 中的非核心文件
7. 更新所有 import 路径
8. 运行测试，修复编译错误

### Phase 2：合并引擎层（1 天）
1. 创建 `engine/engine_config.dart`（合并 7 个 Configurator）
2. 精简 `fvp_engine.dart`（删除 delegated 方法）
3. 删除 `media_opener.dart`、`position_poller.dart`、`track_manager.dart` 等
4. 更新 UI 层调用
5. 运行测试

### Phase 3：精简设置持久化（0.5 天）
1. 重写 `settings_store.dart`（通用 key-value 模式）
2. 删除 `app_settings.dart`
3. 删除 `theme_service.dart`、`locale_service.dart`
4. 更新 UI 层调用
5. 运行测试

### Phase 4：精简 UI 层（0.5 天）
1. 合并重复的设置组件
2. 删除错误横幅、启动画面
3. 合并控件覆盖层
4. 运行测试

### Phase 5：目录重组（0.5 天）
1. 按新结构移动文件
2. 更新所有 import
3. 运行全量测试
4. 提交

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 删除功能导致回归 | 高 | 每个 Phase 后运行全量测试 |
| import 路径大量变更 | 中 | 使用 IDE 批量重构 |
| 引擎接口变更影响 UI | 高 | 先写接口，再改实现 |
| 设置持久化丢失 | 高 | 迁移旧数据到新格式 |

---

## 成功指标

- [ ] 文件数：95 → ≤40
- [ ] 代码行数：14,924 → ≤7,000
- [ ] Flutter 层只包含：窗口功能 + widget tree + 功能控件
- [ ] 所有业务逻辑下沉到引擎层或删除
- [ ] 648 测试全过（或合理精简测试）
- [ ] 编译时间减少 30%+

---

## 不做的事

- ❌ 不迁移状态管理（保持 ValueNotifier）
- ❌ 不重写引擎（保持 fvp/MDK）
- ❌ 不添加新功能
- ❌ 不改变 UI 外观
- ❌ 不做跨平台适配（保持 Windows only）

---

*创建时间：2026-06-21*
*状态：待用户审批*
