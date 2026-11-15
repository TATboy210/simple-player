import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/error_capture_snapshot.dart';
import 'package:simple_player_flutter/ui/player/error_card.dart';
import 'package:simple_player_flutter/ui/player/error_card_host.dart';
import 'package:simple_player_flutter/ui/theme/tokens.dart';

/// 错误卡片布局期尺寸上界 — 高度上界 = 窗口高 × [Tokens.errorCardMaxHeightRatio]，
/// 由 CustomSingleChildLayout 代理在布局期计算，resize 后无需重建即跟随.
void main() {
  setUpAll(() {
    KernelLoggerImpl.resetForTesting();
    KernelLoggerImpl.init();
  });

  setUp(() async {
    await ErrorReporterImpl.resetForTesting();
    ErrorCaptureSnapshot.I.resetForTesting();
    ErrorReporterImpl.init(effects: [ErrorCaptureSnapshot.I.record]);
  });

  Widget harness() => const MaterialApp(
    locale: Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SizedBox.shrink(),
    builder: buildErrorCardMount,
  );

  /// 长调用栈报告 — 展开后内容远超高度上界，逼出滚动收口路径.
  void reportLongStack() {
    final longStack = List.generate(
      60,
      (i) => '#$i      frame_$i (package:simple_player_flutter/a.dart:$i:7)',
    ).join('\n');
    ErrorReporterImpl.I.reportBootstrapSafely(
      StateError('上界检查'),
      StackTrace.fromString(longStack),
    );
  }

  testWidgets('expanded card height follows window height after resize', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    await tester.pump();
    reportLongStack();
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.text('Bad state: 上界检查')));
    await tester.pump();
    await tester.pump();

    final before = tester.getSize(find.byType(ErrorCard)).height;
    expect(before, lessThanOrEqualTo(700 * Tokens.errorCardMaxHeightRatio));

    // Act：窗口缩矮 — 无需任何 widget 重建，布局代理按新约束收口.
    tester.view.physicalSize = const Size(900, 400);
    await tester.pump();
    await tester.pump();

    final after = tester.getSize(find.byType(ErrorCard)).height;
    expect(after, lessThanOrEqualTo(400 * Tokens.errorCardMaxHeightRatio));
    expect(after, lessThan(before));
    expect(find.byType(ErrorCardHost), findsOneWidget);
  });

  testWidgets('card width never exceeds the expanded max width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    await tester.pump();
    reportLongStack();
    await tester.pump();

    expect(
      tester.getSize(find.byType(ErrorCard)).width,
      lessThanOrEqualTo(Tokens.errorCardExpandedMaxWidth),
    );
  });
}
