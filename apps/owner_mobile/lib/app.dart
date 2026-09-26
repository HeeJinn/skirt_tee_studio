import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import 'core/theme/cupertino_theme.dart';
import 'presentation/screens/auth/not_configured_screen.dart';
import 'presentation/screens/auth/sign_in_screen.dart';
import 'presentation/shell/home_tabs.dart';
import 'presentation/viewmodels/today_view_model.dart';

/// The owner app: sign in with the shop's owner account, then the shop's
/// numbers in five tabs. iOS widgets only.
class OwnerApp extends StatelessWidget {
  const OwnerApp({super.key, required this.cloudSync, required this.today});

  final CloudSyncViewModel cloudSync;
  final TodayViewModel today;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cloudSync),
        ChangeNotifierProvider.value(value: today),
      ],
      child: CupertinoApp(
        title: 'Skirt & Tee',
        theme: cupertinoThemeFor(kShopPreset),
        debugShowCheckedModeBanner: false,
        home: Selector<CloudSyncViewModel, CloudStatus>(
          selector: (_, sync) => sync.state.status,
          builder: (_, status, _) => switch (status) {
            CloudStatus.notConfigured => const NotConfiguredScreen(),
            CloudStatus.signedOut => const SignInScreen(),
            _ => const HomeTabs(),
          },
        ),
      ),
    );
  }
}
