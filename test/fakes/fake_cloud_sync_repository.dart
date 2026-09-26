import 'dart:async';

import 'package:skirt_tee_studio/domain/entities/cloud_sync.dart';
import 'package:skirt_tee_studio/domain/repositories/cloud_sync_repository.dart';

class FakeCloudSyncRepository implements CloudSyncRepository {
  FakeCloudSyncRepository({CloudSyncState initial = CloudSyncState.signedOut}) : _current = initial;

  CloudSyncState _current;
  final _states = StreamController<CloudSyncState>.broadcast();
  final _remoteChanges = StreamController<void>.broadcast();

  /// The password signIn accepts; anything else is refused.
  static const goodPassword = 'right-password';

  @override
  CloudSyncState get current => _current;

  @override
  Stream<CloudSyncState> get states => _states.stream;

  @override
  Stream<void> get remoteChanges => _remoteChanges.stream;

  void emit(CloudSyncState state) {
    _current = state;
    _states.add(state);
  }

  void sendRemoteChanges() => _remoteChanges.add(null);

  @override
  Future<void> start() async {}

  @override
  Future<void> signIn(String email, String password) async {
    if (password != goodPassword) throw const CloudSignInException('That email and password don\'t match.');
    emit(CloudSyncState(status: CloudStatus.upToDate, email: email, lastSyncedAt: DateTime(2026, 9, 26, 14, 14)));
  }

  @override
  Future<void> signOut() async => emit(CloudSyncState.signedOut);
}
