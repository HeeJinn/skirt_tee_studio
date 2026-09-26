// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/attachments/attachments.dart';
import 'package:powersync/powersync.dart';
import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/sync/item_photo_sync.dart';

/// An in-memory bucket, keyed by file name.
class _FakeBucket implements RemoteStorage {
  final files = <String, List<int>>{};

  @override
  Future<void> uploadFile(Stream<Uint8List> fileData, Attachment attachment) async {
    files[attachment.filename] = [await for (final chunk in fileData) ...chunk];
  }

  @override
  Future<Stream<List<int>>> downloadFile(Attachment attachment) async {
    final bytes = files[attachment.filename];
    if (bytes == null) throw StateError('not in the bucket: ${attachment.filename}');
    return Stream.value(bytes);
  }

  @override
  Future<void> deleteFile(Attachment attachment) async => files.remove(attachment.filename);
}

void main() {
  late Directory dir;
  late String images;
  late PowerSyncDatabase db;
  late _FakeBucket bucket;
  late ItemPhotoSync photos;

  Future<void> addItem(String id, String? imageKey) => db.execute(
        'INSERT INTO items (id, name, category, unitPrice, qtyOnHand, isBargain, imageKey) VALUES (?, ?, ?, 1, 1, 0, ?)',
        [id, id, 'Skirt', imageKey],
      );

  Future<void> eventually(bool Function() check, String what) async {
    for (var i = 0; i < 100 && !check(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(check(), isTrue, reason: what);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('skirt_tee_photos_test');
    images = p.join(dir.path, 'item_images');
    await Directory(images).create();
    db = await DatabaseService.openAt(p.join(dir.path, 'test.db'));
    bucket = _FakeBucket();
    photos = ItemPhotoSync(db, bucket, images);
  });

  tearDown(() async {
    await photos.stop();
    await db.close();
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows can hold the file a moment after close.
    }
  });

  test('uploads a photo that only exists on this PC, and keeps the local file', () async {
    await File(p.join(images, 'tee.png')).writeAsBytes([1, 2, 3]);
    await addItem('tee', 'tee.png');

    await photos.start();

    await eventually(() => bucket.files.containsKey('tee.png'), 'photo uploaded');
    expect(bucket.files['tee.png'], [1, 2, 3]);
    expect(await File(p.join(images, 'tee.png')).readAsBytes(), [1, 2, 3]);
  });

  test('downloads a photo this PC is missing, e.g. after restoring on a new PC', () async {
    bucket.files['skirt.jpg'] = [9, 8, 7];
    await addItem('skirt', 'skirt.jpg');

    await photos.start();

    final file = File(p.join(images, 'skirt.jpg'));
    await eventually(() => file.existsSync() && file.lengthSync() == 3, 'photo downloaded');
    expect(await file.readAsBytes(), [9, 8, 7]);
  });

  test('uploads a photo added to an item after syncing started', () async {
    await photos.start();

    await File(p.join(images, 'new.png')).writeAsBytes([4, 5]);
    await addItem('new', 'new.png');

    await eventually(() => bucket.files.containsKey('new.png'), 'new photo uploaded');
  });

  test('never uploads a photo no item uses, like one picked in a cancelled dialog', () async {
    await File(p.join(images, 'cancelled.png')).writeAsBytes([1]);
    await File(p.join(images, 'kept.png')).writeAsBytes([2]);
    await addItem('kept', 'kept.png');

    await photos.start();

    await eventually(() => bucket.files.containsKey('kept.png'), 'the used photo uploaded');
    expect(bucket.files.containsKey('cancelled.png'), isFalse);
  });
}
