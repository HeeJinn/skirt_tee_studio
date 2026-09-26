import 'package:flutter/cupertino.dart';

/// A tab whose screen isn't built yet: the large title it will have, and a
/// line saying what will go there.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({super.key, required this.title, required this.icon, required this.message});

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(largeTitle: Text(title)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 40, color: secondary),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: secondary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
