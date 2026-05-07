import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/platform/windows_platform_service.dart';
import 'kernel/services/platform_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();

  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  PlatformService.init(WindowsPlatformService());

  runApp(App(sharedPreferences: prefs));
}
