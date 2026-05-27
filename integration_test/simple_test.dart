import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/app.dart';
import 'package:simple_player_flutter/kernel/startup/startup_coordinator.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('App launches', (WidgetTester tester) async {
    final coordinator = StartupCoordinator();
    await tester.pumpWidget(App(coordinator: coordinator));
    expect(find.byType(App), findsOneWidget);
  });
}
