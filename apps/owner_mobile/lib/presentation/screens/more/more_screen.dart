import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/shop_ui.dart';
import '../../widgets/shop_wordmark.dart';
import '../../widgets/ui/badges.dart';
import '../../widgets/ui/section.dart';

/// Account and sync status for now; Reservations, Customers, Reports,
/// Staff activity, and Settings join this list as they're built.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Sign Out?'),
        message: const Text(
          "The shop's data and photos are removed from this phone. They stay safe in the cloud and on the shop computer.",
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CloudSyncViewModel>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncViewModel>();
    final state = sync.state;
    final colors = ShopColors.of(context);
    final syncColor = switch (state.status) {
      CloudStatus.upToDate => colors.success,
      CloudStatus.offline || CloudStatus.paused || CloudStatus.refused => colors.warning,
      _ => colors.secondaryInk,
    };

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('More'), border: null),
          SliverList.list(
            children: [
              GroupedSection(
                gap: Space.sm,
                children: [_Account(email: state.email)],
              ),
              GroupedSection(
                footer: 'This phone shows the shop computer\'s data. Changes are made on the shop computer.',
                children: [
                  ValueRow(
                    leading: IconBadge(icon: CupertinoIcons.arrow_2_circlepath, color: syncColor, solid: true),
                    label: 'Sync',
                    value: syncLabel(state),
                    tone: ValueTone.muted,
                  ),
                ],
              ),
              GroupedSection(
                children: [
                  Semantics(
                    button: true,
                    enabled: !sync.busy,
                    child: Pressable(
                      onTap: sync.busy ? () {} : () => _confirmSignOut(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Center(
                          child: Text('Sign Out', style: ShopType.body(context).copyWith(color: colors.danger)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xxl),
              Opacity(opacity: 0.55, child: const ShopWordmark(scale: 0.8)),
              const SizedBox(height: Space.xs),
              Text('Owner app', textAlign: TextAlign.center, style: ShopType.caption(context)),
              const BottomInset(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Who's signed in, the way iOS Settings leads with the Apple Account: a
/// large round monogram, then the account.
class _Account extends StatelessWidget {
  const _Account({required this.email});
  final String? email;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    final initial = (email == null || email!.isEmpty) ? 'S' : email![0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.hero, shape: BoxShape.circle),
            child: Text(
              initial,
              style: TextStyle(fontFamily: ShopType.serif, fontSize: 28, fontWeight: FontWeight.w700, color: colors.ink),
            ),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email ?? 'Owner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ShopType.body(context).copyWith(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: Space.xxs),
                Text('Owner account', style: ShopType.subhead(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One short line for a list row: "Up to date · 2:46 PM", "Offline", …
String syncLabel(CloudSyncState state, {DateTime? now}) {
  switch (state.status) {
    case CloudStatus.upToDate:
      final at = state.lastSyncedAt;
      if (at == null) return 'Up to date';
      final today = now ?? DateTime.now();
      final local = at.toLocal();
      final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
      return 'Up to date · ${(sameDay ? DateFormat.jm() : DateFormat('MMM d')).format(local)}';
    case CloudStatus.syncing:
      return 'Syncing…';
    case CloudStatus.offline:
      return 'Offline';
    case CloudStatus.paused:
      return 'Paused';
    case CloudStatus.refused:
      return 'Cloud refused';
    case CloudStatus.signedOut:
      return 'Signed out';
    case CloudStatus.notConfigured:
      return 'Not set up';
  }
}
