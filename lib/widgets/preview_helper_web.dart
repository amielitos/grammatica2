import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

String createBlobUrlFromBytes(Uint8List bytes, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  return web.URL.createObjectURL(blob);
}

Widget buildPlatformPdfViewer(String url) {
  return _WebPdfViewer(url: url);
}

class _WebPdfViewer extends StatefulWidget {
  final String url;
  const _WebPdfViewer({required this.url});

  @override
  State<_WebPdfViewer> createState() => _WebPdfViewerState();
}

class _WebPdfViewerState extends State<_WebPdfViewer> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-viewer-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      String finalUrl = widget.url;
      if (finalUrl.startsWith('http')) {
        finalUrl = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(finalUrl)}&embedded=true';
      }

      final iframe = web.HTMLIFrameElement()
        ..src = finalUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
