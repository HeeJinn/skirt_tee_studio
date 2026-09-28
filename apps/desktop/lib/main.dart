import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/di/injector.dart';
import 'presentation/widgets/window_title_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inter ships with the app as San Francisco's stand-in; its license
  // travels with it.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Inter'], await rootBundle.loadString('assets/fonts/Inter-OFL.txt'));
  });
  await setUpWindow();
  final injector = await Injector.create();
  runApp(SkirtAndTeeApp(injector: injector));
}
