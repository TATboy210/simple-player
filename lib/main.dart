import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'kernel/persistence/settings_store.dart';
import 'kernel/utils/platform_decoders.dart';
import 'window/bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final decoders = getOptimalDecoders();
  if (decoders != null) {
    fvp.registerWith(options: {'video.decoders': decoders, 'log': 'warning'});
  } else {
    fvp.registerWith(options: {'log': 'warning'});
  }

  final prefs = await SharedPreferences.getInstance();
  SettingsStore.prewarm(prefs);

  await WindowBootstrap.init(prefs);

  runApp(App(sharedPreferences: prefs));
}
