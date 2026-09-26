import '../entities/cloud_sync.dart';

abstract class CloudSyncRepository {
  CloudSyncState get current;
  Stream<CloudSyncState> get states;

  /// Fires after the cloud has sent this PC new data, so screens can reload.
  Stream<void> get remoteChanges;

  /// Reconnects with the saved sign-in, if there is one. Works offline: the
  /// connection is made whenever the internet comes back.
  Future<void> start();

  /// Throws [CloudSignInException].
  Future<void> signIn(String email, String password);

  /// Stops syncing. Everything stays on this PC.
  Future<void> signOut();
}
