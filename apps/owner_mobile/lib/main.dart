import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Testing happens on Android and Windows until the iOS build exists:
  // there, debug builds act like an iPhone (text selection, haptics,
  // adaptive widgets) so what's checked is what the owners get. Ignored in
  // release builds.
  if (kDebugMode && !kIsWeb && !Platform.isIOS) debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  // Inter ships with the app for non-Apple devices; its license travels
  // with it.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Inter'], await rootBundle.loadString('assets/fonts/Inter-OFL.txt'));
  });

  final injector = await Injector.create();
  runApp(OwnerApp(
    cloudSync: injector.cloudSyncViewModel,
    today: injector.todayViewModel,
    sales: injector.salesViewModel,
    stock: injector.stockViewModel,
    money: injector.moneyViewModel,
  ));
}
