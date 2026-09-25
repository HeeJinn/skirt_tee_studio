// Only exercises ItemImageStorage.delete(), which takes a raw path and has
// no path_provider dependency. save() resolves the app-support directory
// via path_provider, which isn't mocked in this project's test setup (no
// existing test does), so it's covered by the full Windows build instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/data/datasources/local/item_image_storage.dart';

void main() {
  test('delete removes an existing file', () async {
    final tempDir = await Directory.systemTemp.createTemp('item_image_storage_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File('${tempDir.path}/photo.png')..writeAsBytesSync([1, 2, 3]);

    await ItemImageStorage.instance.delete(file.path);

    expect(await file.exists(), isFalse);
  });

  test('delete is a no-op when the file does not already exist', () async {
    final tempDir = await Directory.systemTemp.createTemp('item_image_storage_test');
    addTearDown(() => tempDir.delete(recursive: true));

    await ItemImageStorage.instance.delete('${tempDir.path}/never-existed.png');
    // No throw = pass.
  });
}
