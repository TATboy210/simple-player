/// 高风险回归测试套件 — 覆盖 D-35 高风险场景。
///
/// 测试目标:
/// - 快速连按 F 10/20 次不出现状态错位
/// - fullscreen -> exit 恢复正确状态
/// - enter 失败后重试可恢复
/// - fast path 直接确认行为
/// - per-window 隔离（独立 WindowService 互不污染）
///
/// v3 简化: DesktopFullscreenAdapter 已合并入 WindowService。
///
/// Phase 1 移除: FullscreenDriver 抽象层已删除，WindowService 不再接受 driver 参数。
/// 全屏现走 media_kit VideoState.toggleFullscreen (方案 B), 无独立全屏依赖。
library;

import 'package:flutter_test/flutter_test.dart';

// ─── 高风险测试 ───

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('High Risk Suite', () {
    // TODO: 全屏回归场景 (HR-001 ~ HR-006) 依赖已删除的 FullscreenDriver,
    // 现全屏走 media_kit VideoState.toggleFullscreen — 待用 media_kit 集成测试重写.
  });
}
