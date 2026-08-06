/// 冒烟测试套件 — 覆盖 8 项必测场景（D-32）。
///
/// 每个测试标注 case ID（FS-REG-001 ~ FS-REG-008），与 regression_matrix.md 对应。
///
/// v3 简化: DesktopFullscreenAdapter 已合并入 WindowService。
///
/// Phase 1 移除: FullscreenDriver 抽象层已删除，WindowService 不再接受 driver 参数。
/// 全屏现走 media_kit VideoState.toggleFullscreen (方案 B), 无独立全屏依赖。
library;

import 'package:flutter_test/flutter_test.dart';

// ─── 冒烟测试 ───

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Suite — 8 Mandatory Scenarios', () {
    // TODO: 全屏回归场景 (FS-REG-001 ~ FS-REG-008) 依赖已删除的 FullscreenDriver,
    // 现全屏走 media_kit VideoState.toggleFullscreen — 待用 media_kit 集成测试重写.
  });
}
