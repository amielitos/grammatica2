import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
    if (widget.isNetwork) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    }
    
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
    if (_isError) return const Center(child: Text("Error playing video", style: TextStyle(color: Colors.white)));
    if (!_controller.value.isInitialized) return const Center(child: CircularProgressIndicator(color: Colors.white));

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
              icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
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
  final bool isImage = ['jpg', 'jpeg', 'png'].contains(fileName.toLowerCase().split('.').last);
  final bool isVideo = ['mp4', 'mov', 'avi', 'webm', 'm4v'].contains(fileName.toLowerCase().split('.').last);
  final bool isPdf = fileName.toLowerCase().endsWith('.pdf');

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
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: isImage
                    ? Image.network(url, fit: BoxFit.contain)
                    : isVideo
                        ? LocalVideoPlayer(url: url, isNetwork: true)
                        : isPdf
                            ? WebPdfViewer(url: url)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 100, color: Colors.grey),
                                  const SizedBox(height: 20),
                                  Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 18)),
                                ],
                              ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
