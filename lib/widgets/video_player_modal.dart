import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerModal extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerModal({
    super.key,
    required this.videoUrl,
    this.title = 'Video Preview',
  });

  @override
  State<VideoPlayerModal> createState() => _VideoPlayerModalState();
}

class _VideoPlayerModalState extends State<VideoPlayerModal> {
  late VideoPlayerController _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    setState(() {
      _isError = false;
    });
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((e) {
        if (!mounted) return;
        setState(() {
          _isError = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Video Area
            Flexible(
              child: AspectRatio(
                aspectRatio: _controller.value.isInitialized ? _controller.value.aspectRatio : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_controller.value.isInitialized)
                      VideoPlayer(_controller)
                    else if (_isError)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Failed to load video in-app', 
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This is likely due to browser security (CORS). You can still view it externally:',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: _initController,
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                  label: const Text('Retry', style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => launchUrl(Uri.parse(widget.videoUrl), mode: LaunchMode.externalApplication),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8CB31D),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open in Browser'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: Color(0xFF8CB31D)),
                    
                    // Overlay Play/Pause toggle
                    if (_controller.value.isInitialized)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                        child: Container(
                          color: Colors.transparent,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Controls
            if (_controller.value.isInitialized)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF8CB31D),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                            });
                          },
                        ),
                        Text(
                          '${_printDuration(_controller.value.position)} / ${_printDuration(_controller.value.duration)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _controller.value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
