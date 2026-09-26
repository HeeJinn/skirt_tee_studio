// PowerSync's attachment queue is marked experimental; it's pinned by
// pubspec.lock, so an API change shows up as a compile error on upgrade.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:powersync/attachments/attachments.dart';
import 'package:powersync/attachments/io.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps item photos in the cloud's `item-images` bucket, under a folder per
/// shop (`<shop id>/<image key>`), using PowerSync's attachment queue.
///
/// The queue assumes a photo it hasn't seen came *from* the cloud and
/// downloads it. Photos taken on this PC (and every photo from before the
/// cloud move) exist only here, so before the queue looks at the items, any
/// photo with a local file and no queue record is queued for upload instead.
/// A photo picked in a cancelled dialog is never on an item, so never goes up.
///
/// Replaced or removed photos stay in the bucket for now.
class ItemPhotoSync {
  ItemPhotoSync(this._db, this._remoteStorage, this._imagesDirectory);

  final PowerSyncDatabase _db;
  final RemoteStorage _remoteStorage;
  final String _imagesDirectory;

  AttachmentQueue? _queue;

  static const _queueTable = AttachmentsQueueTable.defaultTableName;

  Future<void> start() async {
    final queue = _queue ??= AttachmentQueue(
      db: _db,
      remoteStorage: _remoteStorage,
      localStorage: IOLocalStorage(Directory(_imagesDirectory)),
      watchAttachments: _watchPhotos,
    );
    await queue.startSync();
  }

  Future<void> stop() async => _queue?.stopSyncing();

  Stream<List<WatchedAttachmentItem>> _watchPhotos() => _db
      .watch('SELECT DISTINCT imageKey FROM items WHERE imageKey IS NOT NULL', triggerOnTables: const ['items'])
      .asyncMap((rows) async {
        final keys = [for (final row in rows) row['imageKey'] as String];
        await _queueLocalOnlyPhotos(keys);
        // The key is the file name, so it doubles as the attachment id.
        return [for (final key in keys) WatchedAttachmentItem(id: key, filename: key)];
      });

  Future<void> _queueLocalOnlyPhotos(List<String> keys) async {
    for (final key in keys) {
      final file = File(p.join(_imagesDirectory, key));
      if (!await file.exists()) continue;
      await _db.writeTransaction((tx) async {
        if (await tx.getOptional('SELECT 1 FROM $_queueTable WHERE id = ?', [key]) != null) return;
        await tx.execute(
          'INSERT INTO $_queueTable (id, filename, local_uri, timestamp, size, media_type, state, has_synced) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, 0)',
          [
            key,
            key,
            key,
            DateTime.now().millisecondsSinceEpoch,
            await file.length(),
            mediaTypeFor(key),
            AttachmentState.queuedUpload.index,
          ],
        );
      });
    }
  }

  static String mediaTypeFor(String fileName) => switch (p.extension(fileName).toLowerCase()) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        '.bmp' => 'image/bmp',
        '.heic' => 'image/heic',
        _ => 'application/octet-stream',
      };
}

/// The `item-images` bucket. Storage policies only let a shop member touch
/// their own shop's folder.
class SupabasePhotoStorage implements RemoteStorage {
  SupabasePhotoStorage(this._client);

  final SupabaseClient _client;
  String? _shopId;

  static const bucket = 'item-images';

  StorageFileApi get _bucket => _client.storage.from(bucket);

  Future<String> _path(Attachment attachment) async {
    _shopId ??= (await _client.from('shop_members').select('shop_id').limit(1).single())['shop_id'] as String;
    return '$_shopId/${attachment.filename}';
  }

  @override
  Future<void> uploadFile(Stream<Uint8List> fileData, Attachment attachment) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in fileData) {
      bytes.add(chunk);
    }
    await _bucket.uploadBinary(
      await _path(attachment),
      bytes.takeBytes(),
      fileOptions: FileOptions(
        upsert: true,
        contentType: attachment.mediaType ?? ItemPhotoSync.mediaTypeFor(attachment.filename),
      ),
    );
  }

  @override
  Future<Stream<List<int>>> downloadFile(Attachment attachment) async =>
      Stream.value(await _bucket.download(await _path(attachment)));

  @override
  Future<void> deleteFile(Attachment attachment) async {
    await _bucket.remove([await _path(attachment)]);
  }
}
