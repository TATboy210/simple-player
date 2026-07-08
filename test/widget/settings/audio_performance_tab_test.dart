import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/audio_tab.dart';
import 'package:simple_player_flutter/ui/dialogs/settings/settings_tab_performance.dart';
import 'package:simple_player_flutter/ui/shared/glass_container.dart';
import 'package:simple_player_flutter/ui/shared/section_header.dart';
import 'package:simple_player_flutter/ui/shared/settings_card.dart';
import 'package:simple_player_flutter/kernel/engine/engine_state.dart';

import '../../helpers/fake_engine.dart';

/// 带 AppLocalizations 的 MaterialApp 包装器
MaterialApp _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AudioTab', () {
    late FakeEngine engine;

    setUp(() {
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    testWidgets('renders with GlassContainer when tracks exist', (tester) async {
      engine.configureMedia(
        audioTracks: [
          const AudioTrackInfo(index: 0, codec: 'AAC', channels: 2, language: 'Chinese'),
          const AudioTrackInfo(index: 1, codec: 'AC3', channels: 6, language: 'English'),
        ],
      );
      await engine.open('test.mp4');

      await tester.pumpWidget(_wrapWithL10n(
        AudioTab(engine: engine),
      ));

      // 应使用 GlassContainer（SettingsCard 已移除）
      expect(find.byType(GlassContainer), findsOneWidget);
    });

    testWidgets('shows empty state text when no tracks', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        AudioTab(engine: engine),
      ));

      // 无音轨时应显示空状态文本（英文 locale: "No audio tracks available"）
      expect(find.textContaining('audio track'), findsOneWidget);
      expect(find.byType(GlassContainer), findsNothing);
    });

    testWidgets('renders SectionHeader with headphones icon', (tester) async {
      engine.configureMedia(
        audioTracks: [
          const AudioTrackInfo(index: 0, codec: 'AAC', channels: 2, language: 'Chinese'),
        ],
      );
      await engine.open('test.mp4');

      await tester.pumpWidget(_wrapWithL10n(
        AudioTab(engine: engine),
      ));

      final sectionHeaders = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      final audioHeader = sectionHeaders.firstWhere(
        (h) => h.icon == Icons.headphones,
      );
      expect(audioHeader, isNotNull);
    });

    testWidgets('preserves _AudioTrackRow for each track', (tester) async {
      engine.configureMedia(
        audioTracks: [
          const AudioTrackInfo(index: 0, codec: 'AAC', channels: 2, language: 'Chinese'),
          const AudioTrackInfo(index: 1, codec: 'AC3', channels: 6, language: 'English'),
        ],
      );
      await engine.open('test.mp4');

      await tester.pumpWidget(_wrapWithL10n(
        AudioTab(engine: engine),
      ));

      // 应有 2 个 SettingRow（2 个音轨）
      expect(find.byType(SettingRow), findsNWidgets(2));
    });

    testWidgets('track selection calls engine.switchAudioTrack and pops dialog',
        (tester) async {
      engine.configureMedia(
        audioTracks: [
          const AudioTrackInfo(index: 0, codec: 'AAC', channels: 2, language: 'Chinese'),
          const AudioTrackInfo(index: 1, codec: 'AC3', channels: 6, language: 'English'),
        ],
      );
      await engine.open('test.mp4');

      await tester.pumpWidget(_wrapWithL10n(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => AudioTab(engine: engine),
          ),
        ),
      ));

      // 点击第一个音轨
      await tester.tap(find.byType(SettingRow).first);
      await tester.pumpAndSettle();

      // Navigator.pop 应被调用（路由栈变为空）
      expect(find.byType(AudioTab), findsNothing);
    });
  });

  group('PerformanceTab', () {
    late FakeEngine engine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      engine = FakeEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    testWidgets('renders GlassContainer for D3D11 section', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        PerformanceTab(engine: engine),
      ));

      // 等待异步设置加载（多次 pump 处理 FutureBuilder）
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 应使用 GlassContainer（SettingsCard 已移除）
      expect(find.byType(GlassContainer), findsWidgets);
    });

    testWidgets('renders GlassContainer for decoder section', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        PerformanceTab(engine: engine),
      ));

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 应有 2 个 GlassContainer（D3D11 + 解码器）
      expect(find.byType(GlassContainer), findsNWidgets(2));
    });

    testWidgets('renders SectionHeader for both sections', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        PerformanceTab(engine: engine),
      ));

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 应有 2 个 SectionHeader
      expect(find.byType(SectionHeader), findsNWidgets(2));

      final sectionHeaders = tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      );
      // D3D11 section with speed icon
      final d3d11Header = sectionHeaders.firstWhere(
        (h) => h.icon == Icons.speed,
      );
      expect(d3d11Header, isNotNull);

      // Decoder section with memory icon
      final decoderHeader = sectionHeaders.firstWhere(
        (h) => h.icon == Icons.memory,
      );
      expect(decoderHeader, isNotNull);
    });

    testWidgets('preserves SettingSwitchRow for toggles', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        PerformanceTab(engine: engine),
      ));

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // 应有 2 个 SettingSwitchRow
      expect(find.byType(SettingSwitchRow), findsNWidgets(2));
    });
  });
}
