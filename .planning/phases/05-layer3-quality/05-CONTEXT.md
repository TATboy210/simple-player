# Phase 5: LAYER 3 代码质量治理

## 背景

LAYER 3 (Features) 是 UI 和 Kernel 之间的编排层，10 文件 / 1100 行。经过全面审计发现 6 个可修复问题，按风险分 3 个 Wave 执行。

## 目标文件

| 文件 | 修改类型 | Wave |
|------|---------|------|
| `lib/features/player/services/video_processing_service.dart` | diff 逐属性 | W1 |
| `lib/features/player/services/state_monitor.dart` | catchError→try-catch + _rt重命名 | W1 |
| `lib/features/player/services/playback_navigator.dart` | _rt重命名 + 字幕异步化 | W1+W3 |
| `lib/features/player/services/file_operations.dart` | _rt重命名 | W1 |
| `lib/features/player/player_feature.dart` | l10n + build拆分 | W2 |
| `lib/l10n/app_en.arb` | 添加 playerInitFailed key | W2 |
| `lib/l10n/app_zh.arb` | 添加 playerInitFailed key | W2 |

## 暂缓项

- #4 late final → nullable（等 Phase 3 EngineState mixin 拆分完成）
- #9 _openFile 提取到 FileOperations（需确认分层约束）
- #10 加载指示器（Splash 时序已正确）
- #11 批量 IO（需改 SettingsStore 接口）
- #12 路径规范化去重（Windows 路径规则复杂）

## 约束

- 不改 Kernel 层接口
- 不改 UI 层调用方式
- 保留 debugDumpApp() 调试语句
- 每个 Wave 完成后 `flutter analyze` + `flutter test` 必须通过
