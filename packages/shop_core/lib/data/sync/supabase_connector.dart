import 'dart:math';

import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hands PowerSync the signed-in owner's token, and uploads this PC's
/// changes through the `apply_changes` database function
/// (supabase/migrations), one local transaction at a time.
///
/// A refused upload is never dropped: PowerSync replaces local rows with the
/// cloud's copy after each sync, so dropping it would make a sale vanish
/// from this PC. Instead the error is thrown, PowerSync retries it, and the
/// Settings screen shows sync as paused until it's fixed.
class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector(this._client, this._powerSyncUrl);

  final SupabaseClient _client;
  final String _powerSyncUrl;

  /// Big transactions (the one-time import of an existing shop) go up in
  /// slices. Every op is idempotent, so a retry after a partial upload just
  /// applies the early slices again.
  static const maxOpsPerCall = 500;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    var session = _client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      session = (await _client.auth.refreshSession()).session;
      if (session == null) return null;
    }
    return PowerSyncCredentials(
      endpoint: _powerSyncUrl,
      token: session.accessToken,
      userId: session.user.id,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    final ops = transaction.crud.map(opToJson).toList();
    for (var start = 0; start < ops.length; start += maxOpsPerCall) {
      final slice = ops.sublist(start, min(start + maxOpsPerCall, ops.length));
      await _client.rpc('apply_changes', params: {'ops': slice});
    }
    await transaction.complete();
  }

  /// The shape apply_changes reads.
  static Map<String, Object?> opToJson(CrudEntry entry) => {
        'op': entry.op.toJson(),
        'type': entry.table,
        'id': entry.id,
        'data': entry.opData,
      };
}
