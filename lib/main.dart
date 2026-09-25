import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injector.dart';
import 'presentation/widgets/window_title_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpWindow();
  final injector = await Injector.create();
  runApp(SkirtAndTeeApp(injector: injector));
}
