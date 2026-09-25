import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Height of the invisible caption strip along the top of the window.
/// Screens keep their interactive content below this line.
const kTitleBarHeight = 32.0;

bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Hides the native title bar so the app's own surfaces run to the top edge,
/// like Chrome or VS Code. Call before [runApp].
Future<void> setUpWindow() async {
  if (!_isDesktop) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(title: 'The Skirt & Tee Studio', titleBarStyle: TitleBarStyle.hidden),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

/// Wraps the whole app: a transparent drag strip across the top plus
/// minimize / maximize / close buttons in the top-right corner.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: kTitleBarHeight,
          child: Row(
            children: [
              const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
              // macOS keeps its own traffic-light buttons.
              if (!Platform.isMacOS) _CaptionButtons(brightness: Theme.of(context).brightness),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaptionButtons extends StatefulWidget {
  const _CaptionButtons({required this.brightness});
  final Brightness brightness;

  @override
  State<_CaptionButtons> createState() => _CaptionButtonsState();
}

class _CaptionButtonsState extends State<_CaptionButtons> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final b = widget.brightness;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WindowCaptionButton.minimize(brightness: b, onPressed: windowManager.minimize),
        _maximized
            ? WindowCaptionButton.unmaximize(brightness: b, onPressed: windowManager.unmaximize)
            : WindowCaptionButton.maximize(brightness: b, onPressed: windowManager.maximize),
        WindowCaptionButton.close(brightness: b, onPressed: windowManager.close),
      ],
    );
  }
}
