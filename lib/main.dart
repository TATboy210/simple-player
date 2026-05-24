import 'package:flutter/widgets.dart';

import 'app.dart';
import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  final prefs = await AppBootstrap.run();
  runApp(App(sharedPreferences: prefs));
}
