import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readFileFromPath(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}

Uint8List? readFileSyncFromPath(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
  } catch (_) {}
  return null;
}

Future<int> getFileSizeFromPath(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
  } catch (_) {}
  return 0;
}
