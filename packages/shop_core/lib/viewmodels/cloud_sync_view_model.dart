import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities/cloud_sync.dart';
import '../domain/repositories/cloud_sync_repository.dart';

/// Cloud backup status for Settings and the sidebar, plus connect and
/// disconnect. [onRemoteChanges] reloads the other screens' data when the
/// cloud sends rows — e.g. restoring the shop onto a new PC.
class CloudSyncViewModel extends ChangeNotifier {
  CloudSyncViewModel(this._repository, {required this.onRemoteChanges});

  final CloudSyncRepository _repository;
  final Future<void> Function() onRemoteChanges;

  final _subscriptions = <StreamSubscription<void>>[];

  CloudSyncState get state => _repository.current;

  bool _busy = false;

  /// True while connecting or disconnecting.
  bool get busy => _busy;

  Future<void> load() async {
    _subscriptions
      ..add(_repository.states.listen((_) => notifyListeners()))
      ..add(_repository.remoteChanges.listen((_) => onRemoteChanges()));
    await _repository.start();
  }

  /// Returns an error message to show, or null once connected.
  Future<String?> signIn(String email, String password) async {
    _setBusy(true);
    try {
      await _repository.signIn(email, password);
      return null;
    } on CloudSignInException catch (e) {
      return e.message;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _setBusy(true);
    try {
      await _repository.signOut();
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
