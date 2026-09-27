import 'dart:async';

import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/cloud_config.dart';
import '../../domain/entities/cloud_sync.dart';
import '../../domain/repositories/cloud_sync_repository.dart';
import '../datasources/local/item_image_storage.dart';
import 'item_photo_sync.dart';
import 'supabase_connector.dart';

class CloudSyncRepositoryImpl implements CloudSyncRepository {
  CloudSyncRepositoryImpl(
    this._db,
    this._config, {
    this.createShopIfMissing = true,
    this.clearLocalDataOnSignOut = false,
  });

  final PowerSyncDatabase _db;
  final CloudConfig _config;

  /// The shop computer creates the shop on its first connect. The owner app
  /// only joins one: an account without a shop is refused rather than given
  /// a new, empty shop.
  final bool createShopIfMissing;

  /// The shop computer keeps its data when disconnected — it's the shop's
  /// working copy. A phone can be lost, so signing out removes the shop's
  /// data and photos from it.
  final bool clearLocalDataOnSignOut;

  static const shopName = 'The Skirt & Tee Studio';

  SupabaseClient? _client;
  ItemPhotoSync? _photos;
  final _states = StreamController<CloudSyncState>.broadcast();
  final _remoteChanges = StreamController<void>.broadcast();
  CloudSyncState _current = CloudSyncState.notConfigured;

  SyncStatus? _syncStatus;
  int _pending = 0;
  bool _wasDownloading = false;

  @override
  CloudSyncState get current => _current;

  @override
  Stream<CloudSyncState> get states => _states.stream;

  @override
  Stream<void> get remoteChanges => _remoteChanges.stream;

  @override
  Future<void> start() async {
    if (!_config.isComplete) return _publish();

    await Supabase.initialize(url: _config.supabaseUrl, publishableKey: _config.supabasePublishableKey);
    _client = Supabase.instance.client;
    _photos = ItemPhotoSync(_db, SupabasePhotoStorage(_client!), ItemImageStorage.instance.directory);

    _db.statusStream.listen(_onSyncStatus);
    _db.watch('SELECT COUNT(*) AS n FROM ps_crud', triggerOnTables: const ['ps_crud']).listen((rows) {
      _pending = rows.first['n'] as int;
      _publish();
    });

    if (_client!.auth.currentSession != null) await _connect();
    _publish();
  }

  @override
  Future<void> signIn(String email, String password) async {
    final client = _client;
    if (client == null) throw const CloudSignInException('Cloud backup isn\'t set up in this version of the app.');
    try {
      await client.auth.signInWithPassword(email: email.trim(), password: password);
      if (createShopIfMissing) {
        // First connect creates the shop in the cloud; later ones find it.
        await client.rpc('ensure_shop', params: {'shop_name': shopName});
      } else {
        final membership = await client.from('shop_members').select('shop_id').limit(1);
        if (membership.isEmpty) {
          await client.auth.signOut();
          throw const CloudSignInException(
            "This account isn't linked to the shop yet. Connect the shop computer with it first.",
          );
        }
      }
    } on AuthRetryableFetchException {
      throw const CloudSignInException('Can\'t reach the cloud. Check the internet connection and try again.');
    } on AuthException catch (e) {
      throw CloudSignInException(
        e.code == 'invalid_credentials' ? 'That email and password don\'t match.' : 'Sign-in failed: ${e.message}',
      );
    } on PostgrestException catch (e) {
      await client.auth.signOut();
      throw CloudSignInException('Signed in, but the shop couldn\'t be set up: ${e.message}');
    }
    await _connect();
    _publish();
  }

  @override
  Future<void> signOut() async {
    await _photos?.stop();
    if (clearLocalDataOnSignOut) {
      await _photos?.clear();
      await _db.disconnectAndClear();
    } else {
      await _db.disconnect();
    }
    await _client?.auth.signOut();
    _publish();
  }

  Future<void> _connect() async {
    await _db.connect(connector: SupabaseConnector(_client!, _config.powerSyncUrl));
    await _photos!.start();
  }

  void _onSyncStatus(SyncStatus status) {
    _syncStatus = status;
    // A finished download means the cloud sent rows, so screens reload.
    if (_wasDownloading && !status.downloading && status.downloadError == null) {
      _remoteChanges.add(null);
    }
    _wasDownloading = status.downloading;
    _publish();
  }

  void _publish() {
    _current = _buildState();
    _states.add(_current);
  }

  CloudSyncState _buildState() {
    final client = _client;
    if (!_config.isComplete || client == null) return CloudSyncState.notConfigured;
    final session = client.auth.currentSession;
    if (session == null) return CloudSyncState.signedOut;

    final status = _syncStatus;
    final email = session.user.email;
    final lastSyncedAt = status?.lastSyncedAt;

    CloudSyncState state(CloudStatus s, [Object? error]) => CloudSyncState(
          status: s,
          email: email,
          lastSyncedAt: lastSyncedAt,
          pendingChanges: _pending,
          error: error?.toString(),
        );

    if (status == null || status.connecting) return state(CloudStatus.syncing);
    if (!status.connected) {
      // An HTTP error means the service answered, so the internet is fine.
      final error = status.downloadError;
      return state(error is SyncResponseException ? CloudStatus.refused : CloudStatus.offline, error);
    }
    if (status.uploadError != null) return state(CloudStatus.paused, status.uploadError);
    if (status.uploading || status.downloading || _pending > 0) return state(CloudStatus.syncing);
    return state(CloudStatus.upToDate);
  }
}
