import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/di/injector.dart';
import 'package:shop_core/core/theme/app_theme.dart';
import 'presentation/screens/auth/sign_in_screen.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/viewmodels/session_view_model.dart';
import 'presentation/viewmodels/settings_view_model.dart';
import 'presentation/widgets/window_title_bar.dart';

class SkirtAndTeeApp extends StatelessWidget {
  const SkirtAndTeeApp({super.key, required this.injector});
  final Injector injector;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: injector.inventoryViewModel),
        ChangeNotifierProvider.value(value: injector.cartViewModel),
        ChangeNotifierProvider.value(value: injector.reservationViewModel),
        ChangeNotifierProvider.value(value: injector.salesViewModel),
        ChangeNotifierProvider.value(value: injector.settingsViewModel),
        ChangeNotifierProvider.value(value: injector.sessionViewModel),
        ChangeNotifierProvider.value(value: injector.moneyViewModel),
        ChangeNotifierProvider.value(value: injector.cloudSyncViewModel),
      ],
      // Only a theme choice rebuilds the app — not other settings changes.
      child: Selector<SettingsViewModel, (ThemePreset, ThemeMode)>(
        selector: (_, settings) => (settings.themePreset, settings.themeMode),
        builder: (_, appearance, _) => MaterialApp(
          title: 'The Skirt & Tee Studio',
          theme: AppTheme.fromPalette(appearance.$1.light),
          darkTheme: AppTheme.fromPalette(appearance.$1.dark),
          themeMode: appearance.$2,
          // Long enough to read as a deliberate crossfade between palettes,
          // short enough not to hold up the next tap.
          themeAnimationDuration: const Duration(milliseconds: 280),
          themeAnimationCurve: Curves.easeOutCubic,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _IosScrollBehavior(),
          builder: (_, child) => WindowFrame(child: child!),
          home: Selector<SessionViewModel, bool>(
            selector: (_, session) => session.current != null,
            builder: (_, signedIn, _) => signedIn ? const AppShell() : const SignInScreen(),
          ),
        ),
      ),
    );
  }
}

/// Lists and pages bounce at their ends, as they do on iPhone and iPad.
class _IosScrollBehavior extends MaterialScrollBehavior {
  const _IosScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());
}
