import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/shop_ui.dart';
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
        title: const Text('Sign out?'),
        message: const Text(
          "The shop's data and photos are removed from this phone. They stay safe in the cloud and on the shop computer.",
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('Sign out'),
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
      CloudStatus.offline || CloudStatus.paused => colors.warning,
      _ => colors.secondaryInk,
    };

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('More')),
          SliverList.list(
            children: [
              GroupedSection(
                title: 'Account',
                footer: 'This phone shows the shop computer\'s data. Changes are made on the shop computer.',
                children: [
                  ValueRow(
                    leading: IconBadge(icon: CupertinoIcons.person_fill, color: colors.accent),
                    label: 'Signed in as',
                    detail: state.email ?? 'Owner',
                  ),
                  ValueRow(
                    leading: IconBadge(icon: CupertinoIcons.arrow_2_circlepath, color: syncColor),
                    label: 'Sync',
                    detail: syncLabel(state),
                  ),
                ],
              ),
              GroupedSection(
                children: [
                  ValueRow(
                    label: 'Sign out',
                    destructive: true,
                    onTap: sync.busy ? null : () => _confirmSignOut(context),
                  ),
                ],
              ),
              const BottomInset(),
            ],
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
    case CloudStatus.signedOut:
      return 'Signed out';
    case CloudStatus.notConfigured:
      return 'Not set up';
  }
}
