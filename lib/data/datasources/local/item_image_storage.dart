import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies picked item photos into the app's own storage, so the DB only
/// ever stores a path this app controls — never a path on the user's
/// filesystem, which they could later move, rename, or delete out from
/// under it.
class ItemImageStorage {
  ItemImageStorage._();
  static final ItemImageStorage instance = ItemImageStorage._();

  static const _uuid = Uuid();

  Future<Directory> _imageDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'item_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies [source] in and returns the new local path.
  Future<String> save(XFile source) async {
    final dir = await _imageDir();
    final ext = p.extension(source.name);
    final destPath = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(source.path).copy(destPath);
    return destPath;
  }

  /// No-op if the file is already gone — callers don't need to check first.
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
