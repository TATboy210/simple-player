import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/startup/startup_coordinator.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers/fake_window_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('App launches', (WidgetTester tester) async {
    final coordinator = StartupCoordinator();
    final windowService = FakeWindowService();
    await tester.pumpWidget(
      App(coordinator: coordinator, windowService: windowService),
    );
    expect(find.byType(App), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.brightness, Brightness.dark);
    expect(materialApp.darkTheme?.brightness, Brightness.dark);
  });
}
