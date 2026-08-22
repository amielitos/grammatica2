import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Generates a clean, unique random key filename for image uploads.
/// Format: img_timestamp_random6digits.ext
String generateUniqueImageKey(String originalFileName) {
  final cleanName = originalFileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final ext = cleanName.contains('.') && !cleanName.endsWith('.')
      ? cleanName.split('.').last.toLowerCase()
      : 'png';
  final randomToken = Random().nextInt(1000000).toString().padLeft(6, '0');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'img_${timestamp}_$randomToken.$ext';
}

/// Returns appropriate MIME content-type based on file extension.
String getMimeType(String fileName) {
  final ext = fileName.toLowerCase().split('.').last;
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'pdf':
      return 'application/pdf';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    default:
      return 'application/octet-stream';
  }
}

/// Compress image bytes if file size exceeds threshold (150KB).
/// Resizes high-resolution images down to max dimension 1200px while maintaining aspect ratio.
Future<Uint8List> compressImageBytes(Uint8List bytes, {int targetWidth = 1200}) async {
  // If image is already smaller than 150KB, return as-is
  if (bytes.lengthInBytes <= 150 * 1024) {
    return bytes;
  }

  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      final compressed = byteData.buffer.asUint8List();
      if (compressed.lengthInBytes < bytes.lengthInBytes) {
        return compressed;
      }
    }
  } catch (_) {
    // If decoding fails, return original bytes safely
  }

  return bytes;
}

