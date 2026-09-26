enum CloudStatus {
  /// This build has no cloud settings; the app runs offline-only.
  notConfigured,

  /// Not connected to a cloud account yet (or disconnected).
  signedOut,

  /// Uploading this PC's changes or downloading the cloud's.
  syncing,

  /// Everything on this PC is in the cloud.
  upToDate,

  /// Can't reach the cloud. Changes wait on this PC and go up later.
  offline,

  /// The cloud refused a change. Uploads wait until it's fixed; nothing is
  /// lost from this PC meanwhile.
  paused,
}

class CloudSyncState {
  const CloudSyncState({
    required this.status,
    this.email,
    this.lastSyncedAt,
    this.pendingChanges = 0,
    this.error,
  });

  static const notConfigured = CloudSyncState(status: CloudStatus.notConfigured);
  static const signedOut = CloudSyncState(status: CloudStatus.signedOut);

  final CloudStatus status;

  /// The owner account this PC is connected with.
  final String? email;
  final DateTime? lastSyncedAt;

  /// Changes made on this PC that haven't reached the cloud yet.
  final int pendingChanges;

  /// Technical detail behind [CloudStatus.paused] or [CloudStatus.offline].
  final String? error;

  bool get isConnected => status != CloudStatus.notConfigured && status != CloudStatus.signedOut;
}

/// Sign-in failed; [message] is written for the person at the counter.
class CloudSignInException implements Exception {
  const CloudSignInException(this.message);
  final String message;

  @override
  String toString() => message;
}
