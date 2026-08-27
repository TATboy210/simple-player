import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/diagnostics/kernel_logger.dart';
import 'package:simple_player_flutter/kernel/diagnostics/startup_timeline.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fake_kernel_logger.dart';
import '../test/helpers/fake_window_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('App launches', (WidgetTester tester) async {
    // 假窗口服务避免真窗口依赖；假 logger 避免全局 init 序列。
    await tester.pumpWidget(
      App(
        startupTimeline: StartupTimeline(
          logger: KernelLoggerImpl(RecordingLogSink()),
        ),
        windowService: FakeWindowService(),
      ),
    );
    expect(find.byType(App), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.brightness, Brightness.dark);
    expect(materialApp.darkTheme?.brightness, Brightness.dark);
  });
}
