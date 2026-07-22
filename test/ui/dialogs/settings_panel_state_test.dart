// SettingsPanelState 单元测试 — 覆盖 PANEL-01。
//
// 验证三个 ValueNotifier 的初始值与 dispose 行为，不依赖真实 MediaEngine
// 或 WidgetTester（纯 Dart 类，可在 `flutter test` 的 VM 环境直接运行）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_panel_state.dart';

void main() {
  group('SettingsPanelState', () {
    test('initializes with isOpen=false, selectedTab=0, dragOffset=Offset.zero', () {
      // Arrange & Act
      final state = SettingsPanelState();

      // Assert
      expect(state.isOpen.value, isFalse);
      expect(state.selectedTab.value, 0);
      expect(state.dragOffset.value, Offset.zero);

      state.dispose();
    });

    test('dispose() disposes exactly the three notifiers', () {
      // Arrange
      final state = SettingsPanelState();

      // Act
      state.dispose();

      // Assert — a disposed ValueNotifier throws on further listener attach.
      expect(
        () => state.isOpen.addListener(() {}),
        throwsA(isA<FlutterError>()),
      );
      expect(
        () => state.selectedTab.addListener(() {}),
        throwsA(isA<FlutterError>()),
      );
      expect(
        () => state.dragOffset.addListener(() {}),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}
