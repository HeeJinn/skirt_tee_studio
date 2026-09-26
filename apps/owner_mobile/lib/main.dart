import 'package:flutter/cupertino.dart';

import 'app.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final injector = await Injector.create();
  runApp(OwnerApp(
    cloudSync: injector.cloudSyncViewModel,
    today: injector.todayViewModel,
    sales: injector.salesViewModel,
    stock: injector.stockViewModel,
  ));
}
