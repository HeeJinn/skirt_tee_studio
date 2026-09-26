import 'package:flutter/cupertino.dart';

import '../../widgets/shop_wordmark.dart';

/// Shown by a build made without the cloud settings (cloud.json), which
/// has nowhere to sign in to. A developer-facing message: owners never see
/// a build like this.
class NotConfiguredScreen extends StatelessWidget {
  const NotConfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShopWordmark(),
                const SizedBox(height: 32),
                const Text(
                  'This build has no cloud settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run it with --dart-define-from-file=../../cloud.json.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
