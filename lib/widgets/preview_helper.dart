import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'preview_helper_stub.dart'
    if (dart.library.js_interop) 'preview_helper_web.dart';

String createBlobUrl(Uint8List bytes, String mimeType) {
  return createBlobUrlFromBytes(bytes, mimeType);
}

Widget getPlatformPdfViewer(String url) {
  return buildPlatformPdfViewer(url);
}
