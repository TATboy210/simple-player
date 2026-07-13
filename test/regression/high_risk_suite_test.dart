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
/// 全屏测试待 Phase 4 使用 fullscreen_window 包重写。
library;

import 'package:flutter_test/flutter_test.dart';

// ─── 高风险测试 ───

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('High Risk Suite', () {
    // TODO: Phase 4 — rewrite fullscreen tests using fullscreen_window package
    // All scenarios (HR-001 ~ HR-006) depend on FullscreenDriver mock
    // which was deleted in Phase 1. WindowService no longer accepts driver parameter.
    // Fullscreen case in setMode is stubbed until Phase 2 wires fullscreen_window.
  });
}
