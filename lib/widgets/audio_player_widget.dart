import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String? url;
  final Uint8List? bytes;
  final String? path;
  final Color activeColor;

  const AudioPlayerWidget({
    super.key,
    this.url,
    this.bytes,
    this.path,
    this.activeColor = Colors.blue,
  }) : assert(
         url != null || bytes != null || path != null,
         'Must provide url, bytes, or path',
       );

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initStreams();
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.bytes != oldWidget.bytes ||
        widget.path != oldWidget.path) {
      _stop();
    }
  }

  void _initStreams() {
    _durationSubscription = _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _positionSubscription = _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _playerCompleteSubscription = _player.onPlayerComplete.listen((event) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    });

    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      setState(() => _playerState = state);
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    Source source;
    if (widget.url != null) {
      source = UrlSource(widget.url!);
    } else if (widget.bytes != null) {
      source = BytesSource(widget.bytes!);
    } else {
      source = DeviceFileSource(widget.path!);
    }
    await _player.play(source);
  }

  Future<void> _pause() async {
    await _player.pause();
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.activeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.activeColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(
            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: _isPlaying ? _pause : _play,
            size: 32,
          ),
          const SizedBox(width: 4),
          _buildControlButton(
            icon: Icons.replay,
            onPressed: _playerState == PlayerState.stopped ? null : _stop,
            size: 32,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _formatDuration(
                _position == Duration.zero ? _duration : _position,
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.activeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
    double size = 40,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.activeColor.withOpacity(onPressed == null ? 0.05 : 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: widget.activeColor.withOpacity(onPressed == null ? 0.3 : 1.0),
          size: size * 0.6,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(minWidth: size, minHeight: size),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
