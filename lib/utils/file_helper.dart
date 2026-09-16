import 'dart:typed_data';
import 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_io.dart';

class FileHelper {
  static Future<Uint8List?> readBytes(String? path, [Uint8List? fallbackBytes]) async {
    if (fallbackBytes != null) return fallbackBytes;
    if (path != null) return await readFileFromPath(path);
    return null;
  }

  static Uint8List? readBytesSync(String? path, [Uint8List? fallbackBytes]) {
    if (fallbackBytes != null) return fallbackBytes;
    if (path != null) return readFileSyncFromPath(path);
    return null;
  }

  static Future<int> getFileSize(String? path, [int? fallbackSize]) async {
    if (fallbackSize != null && fallbackSize > 0) return fallbackSize;
    if (path != null) return await getFileSizeFromPath(path);
    return 0;
  }
}
