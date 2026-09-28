import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';

/// How a cloud backup state reads and looks, shared by the sidebar and the
/// Settings panel so they never disagree.
class CloudStatusLook {
  const CloudStatusLook({required this.icon, required this.label, required this.detail, required this.color});

  final IconData icon;
  final String label;
  final String detail;
  final Color color;

  factory CloudStatusLook.of(BuildContext context, CloudSyncState state, {DateTime? now}) {
    final tokens = context.tokens;
    final pending = state.pendingChanges;
    final changes = pending == 1 ? '1 change' : '$pending changes';

    return switch (state.status) {
      CloudStatus.upToDate => CloudStatusLook(
          icon: CupertinoIcons.checkmark_circle,
          label: 'Backed up',
          detail: state.lastSyncedAt == null ? 'Everything is in the cloud' : 'Last synced ${formatSyncTime(state.lastSyncedAt!, now: now)}',
          color: tokens.success,
        ),
      CloudStatus.syncing => CloudStatusLook(
          icon: CupertinoIcons.arrow_2_circlepath,
          label: 'Syncing',
          detail: pending > 0 ? 'Uploading $changes' : 'Checking the cloud for changes',
          color: tokens.mutedText,
        ),
      CloudStatus.offline => CloudStatusLook(
          icon: CupertinoIcons.wifi_slash,
          label: 'Offline',
          detail: pending > 0
              ? '$changes will upload when the internet is back'
              : 'Selling works as normal; changes upload when the internet is back',
          color: tokens.warning,
        ),
      CloudStatus.refused => CloudStatusLook(
          icon: CupertinoIcons.exclamationmark_shield,
          label: 'Cloud refused',
          detail: 'The internet is fine, but the cloud turned this computer away — its setup needs fixing. '
              'Changes wait on this computer.',
          color: tokens.danger,
        ),
      CloudStatus.paused => CloudStatusLook(
          icon: CupertinoIcons.exclamationmark_triangle,
          label: 'Sync paused',
          detail: 'The cloud refused a change, so uploads are waiting. Nothing is lost from this computer.',
          color: tokens.danger,
        ),
      CloudStatus.signedOut => CloudStatusLook(
          icon: CupertinoIcons.cloud,
          label: 'Not connected',
          detail: 'This computer isn\'t backing up to the cloud',
          color: tokens.mutedText,
        ),
      CloudStatus.notConfigured => CloudStatusLook(
          icon: CupertinoIcons.cloud,
          label: 'Not available',
          detail: 'Cloud backup isn\'t set up in this version of the app',
          color: tokens.mutedText,
        ),
    };
  }
}

/// "2:14 PM" today, "Sep 24, 2:14 PM" otherwise.
String formatSyncTime(DateTime at, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final local = at.toLocal();
  final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
  return (sameDay ? DateFormat.jm() : DateFormat('MMM d, ').add_jm()).format(local);
}
