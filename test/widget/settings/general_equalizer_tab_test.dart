import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/pending_settings.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/equalizer_tab.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/tabs/general_tab.dart';
import 'package:simple_player_flutter/ui/shared/focusable_setting_row.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';
import 'package:simple_player_flutter/ui/shared/settings_card.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

void main() {
  group('settings tab SettingRow consumers', () {
    testWidgets('GeneralTab renders its glass sections and headers', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        _wrap(GeneralTab(pending: PendingSettingsState())),
      );

      // Assert
      expect(find.byType(GlassContainer), findsNWidgets(2));
      final headers = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      expect(
        headers.map((header) => header.icon),
        containsAll(<IconData>[Icons.language, Icons.dark_mode]),
      );
    });

    testWidgets('EqualizerTab renders its glass section and header', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        _wrap(EqualizerTab(pending: PendingSettingsState())),
      );

      // Assert — Phase 33 重写：EqualizerTab 现有 3 个 GlassContainer 区段
      //（EQ 预设 / 空间与同步 / 音量标准化），3 个 SectionHeader。
      // EQ 预设区 header 仍用 Icons.equalizer（另两区为 tune / graphic_eq）。
      expect(find.byType(GlassContainer), findsNWidgets(3));
      final headers = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      expect(headers.map((h) => h.icon), contains(Icons.equalizer));
    });

    testWidgets('GeneralTab keeps each row on one non-InkWell focus route', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        _wrap(GeneralTab(pending: PendingSettingsState())),
      );

      // Assert — interactive controls keep their own semantics while InkWell
      // cannot introduce a second tab stop around the row.
      expect(find.byType(SettingRow), findsNWidgets(2));
      expect(find.byType(FocusableSettingRow), findsNWidgets(2));
      _expectRowsUseLockedDensity(tester);
    });

    testWidgets('EqualizerTab keeps its setting row geometry and focus route', (
      tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        _wrap(EqualizerTab(pending: PendingSettingsState())),
      );

      // Assert — Phase 33 重写：5 个 EQ 预设行 + 1 个标准化行 = 6 SettingRow，
      // 每个内含 1 个 FocusableSettingRow（_PendingSliderRow 不用 SettingRow）。
      // 锁定 40px 行高契约仍对全部 6 行生效。
      expect(find.byType(SettingRow), findsNWidgets(6));
      expect(find.byType(FocusableSettingRow), findsNWidgets(6));
      _expectRowsUseLockedDensity(tester);
    });

    testWidgets(
      'focused text value keeps the accent route without geometry shift',
      (tester) async {
        // Arrange
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          _wrap(
            SettingRow(
              focusNode: focusNode,
              title: 'Representative value',
              control: const Text('Enabled'),
              onTap: () {},
            ),
          ),
        );
        final beforeFocusHeight = tester
            .getSize(find.byType(SettingRow))
            .height;

        // Act
        focusNode.requestFocus();
        await tester.pump();

        // Assert
        final value = tester.widget<Text>(find.text('Enabled'));
        expect(value.style?.color, Tokens.accent);
        expect(
          tester.getSize(find.byType(SettingRow)).height,
          beforeFocusHeight,
        );
        expect(beforeFocusHeight, 40);
      },
    );
  });
}

/// Provides Material inherited widgets required by settings controls and ink.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Verifies focus borders remain paint-only while all consumer rows stay compact.
void _expectRowsUseLockedDensity(WidgetTester tester) {
  for (final row in tester.widgetList<SettingRow>(find.byType(SettingRow))) {
    final rowFinder = find.byWidget(row);
    final wrapperFinder = find.descendant(
      of: rowFinder,
      matching: find.byType(FocusableSettingRow),
    );
    expect(tester.getSize(wrapperFinder).height, 40);
  }
}
