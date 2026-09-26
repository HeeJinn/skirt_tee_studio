import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart';
import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/data/datasources/local/item_image_storage.dart';

/// Opens a fresh, independent database with the app's schema in its own temp
/// folder, removed after the test. Also points item images at that folder,
/// since reading an item with a photo resolves its path there.
Future<PowerSyncDatabase> openTestDatabase() async {
  final dir = await Directory.systemTemp.createTemp('skirt_tee_test');
  ItemImageStorage.instance.useDirectory(p.join(dir.path, 'item_images'));
  final db = await DatabaseService.openAt(p.join(dir.path, 'test.db'));
  addTearDown(() async {
    await db.close();
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows can hold the file a moment after close; temp is fine to leave.
    }
  });
  return db;
}
