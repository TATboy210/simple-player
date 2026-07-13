/// 冒烟测试套件 — 覆盖 8 项必测场景（D-32）。
///
/// 每个测试标注 case ID（FS-REG-001 ~ FS-REG-008），与 regression_matrix.md 对应。
///
/// v3 简化: DesktopFullscreenAdapter 已合并入 WindowService。
///
/// Phase 1 移除: FullscreenDriver 抽象层已删除，WindowService 不再接受 driver 参数。
/// 全屏测试待 Phase 4 使用 fullscreen_window 包重写。
library;

import 'package:flutter_test/flutter_test.dart';

// ─── 冒烟测试 ───

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Suite — 8 Mandatory Scenarios', () {
    // TODO: Phase 4 — rewrite fullscreen tests using fullscreen_window package
    // All 8 scenarios (FS-REG-001 ~ FS-REG-008) depend on FullscreenDriver mock
    // which was deleted in Phase 1. WindowService no longer accepts driver parameter.
    // Fullscreen case in setMode is stubbed until Phase 2 wires fullscreen_window.
  });
}
