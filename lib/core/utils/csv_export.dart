import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../presentation/widgets/app_snackbar.dart';

/// Prompts for a save location, writes [csv] there, and reports success or
/// failure via a snackbar. Shared by every "EXPORT" action so the
/// file-picker/write/feedback plumbing lives in one place.
Future<void> exportCsv(BuildContext context, {required String suggestedName, required String csv}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'CSV', extensions: ['csv']),
    ],
  );
  if (location == null || !context.mounted) return;

  try {
    await File(location.path).writeAsString(csv);
    if (!context.mounted) return;
    showAppSnackBar(context, 'Export saved');
  } catch (_) {
    if (!context.mounted) return;
    showAppSnackBar(context, 'Export failed — try again', isError: true);
  }
}
