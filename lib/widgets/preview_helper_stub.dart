import 'dart:typed_data';
import 'package:flutter/material.dart';

String createBlobUrlFromBytes(Uint8List bytes, String mimeType) {
  return '';
}

Widget buildPlatformPdfViewer(String url) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
        const SizedBox(height: 16),
        const Text(
          'PDF Document',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          url.startsWith('http') ? 'Document uploaded and ready' : 'Local file selected',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
      ],
    ),
  );
}
