import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'preview_helper.dart';

class LocalVideoPlayer extends StatefulWidget {
  final String url;
  final bool isNetwork;
  const LocalVideoPlayer({super.key, required this.url, this.isNetwork = false});

  @override
  State<LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<LocalVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.play();
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _isError = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text("Unable to play video directly in viewer", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(widget.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Video in Browser'),
            ),
          ],
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          VideoProgressIndicator(_controller, allowScrubbing: true),
          Positioned(
            bottom: 20,
            child: IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WebPdfViewer extends StatelessWidget {
  final String url;
  const WebPdfViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return getPlatformPdfViewer(url);
  }
}

void showFilePreviewModal(BuildContext context, String url, String fileName) {
  final lowerUrl = url.toLowerCase();
  final lowerName = fileName.toLowerCase();

  final bool isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].any(
    (ext) => lowerName.endsWith('.$ext') || lowerUrl.contains('.$ext?') || lowerUrl.contains('/image') || lowerUrl.contains('format=$ext'),
  );

  final bool isVideo = ['mp4', 'mov', 'avi', 'webm', 'm4v', 'mkv', 'ogv'].any(
    (ext) => lowerName.endsWith('.$ext') || lowerUrl.contains('.$ext?') || lowerUrl.contains('/video'),
  );

  Widget body;
  if (isImage) {
    body = Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, stack) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_rounded, size: 80, color: Colors.white38),
          const SizedBox(height: 16),
          Text("Failed to load image: $fileName", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  } else if (isVideo) {
    body = LocalVideoPlayer(url: url, isNetwork: true);
  } else {
    // Default to PDF / Document viewer (Google Docs Viewer embed on web)
    body = WebPdfViewer(url: url);
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open in new tab / Download',
                    icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 22),
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: body,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

