# 紧急回退指南 (Emergency Rollback Guide)

**Phase:** 21 — 测试与迁移验证 + 适配层收拢
**Last updated:** 2026-07-20

## 触发条件 (D17)

当用户遇到以下**可感知的播放故障**时，立即触发回退：

- 无法播放（open 后无画面/无声音）
- 应用崩溃（闪退、未响应）
- 音画不同步
- 视频渲染异常（花屏、绿屏、黑屏）
- 播放状态卡死（无法暂停/恢复/seek）
- 其他与引擎迁移直接相关的回归

## 回退范围 (D18)

**涉及组件：**
- 播放引擎 (`DelegationPolicy` 翻回 `all-legacy`)
- 诊断组件 (`KernelLogger` / `MemoryMonitor` 回退到 noop)

**不涉及：**
- UI 层（播放列表、设置面板、控制栏等）
- 设置存储 (`SettingsStore`)
- 播放列表 (`Playlist` / `PlaylistStore`)
- 窗口桥接 (`WindowBridge`)

## 回退步骤

### 1. 执行回退脚本

```bash
# 预览变更（不修改文件）
bash tool/audit/rollback.sh --dry-run

# 执行回退
bash tool/audit/rollback.sh
```

脚本会将 `lib/kernel/player_services.dart` 中的 `DelegationPolicy` 翻回 `DelegationPolicy.all(KernelMode.legacy)`。

### 2. 验证回退

```bash
flutter test
```

确认所有测试通过。

### 3. 提交变更

```bash
git add lib/kernel/player_services.dart
git commit -m "fix: emergency rollback — DelegationPolicy to all-legacy

Rollback triggered due to [描述具体问题].
All playback now routes through legacy FvpEngine."
```

### 4. 通知团队

- 在 issue tracker 创建回退 issue
- 记录触发回退的具体症状
- 附上回退前后的 diff

## 恢复步骤

当问题修复后，重新启用迁移：

1. 在 `lib/kernel/player_services.dart` 中将 `DelegationPolicy` 改回迁移状态
2. 运行 `bash tool/audit/phase21_gates.sh` 确认 4 项闸门全部通过
3. 运行 `flutter test` 确认全绿
4. 提交并创建 PR

## 技术细节

### 回退原理

`KernelAdapter` 是 Strangler Fig 临时路由层，`DelegationPolicy` 控制每个方法的路由目标：
- `KernelMode.legacy` → 路由到旧引擎 (`FvpEngine`)
- `KernelMode.migrated` → 路由到新引擎

将所有字段翻回 `legacy` 后，100% 流量走旧引擎，新引擎完全旁路。

### 回退脚本位置

```
tool/audit/rollback.sh     # 回退脚本
tool/audit/phase21_gates.sh # 闸门检查脚本（回退后可用此验证状态）
```
