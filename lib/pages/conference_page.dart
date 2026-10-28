// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/agora_service.dart';

/// Full in-app video conference + live chat powered by Agora.
///
/// Pass [channelName] (generated from the session doc ID) and [sessionId]
/// to allow both participants to join the same call. The [isHost] flag
/// controls whether this user is the educator (host) or the learner.
class ConferencePage extends StatefulWidget {
  final String channelName;
  final String sessionId;
  final String sessionTitle;
  final String otherParticipantName;
  final bool isHost;
  final User currentUser;

  const ConferencePage({
    super.key,
    required this.channelName,
    required this.sessionId,
    required this.sessionTitle,
    required this.otherParticipantName,
    required this.isHost,
    required this.currentUser,
  });

  @override
  State<ConferencePage> createState() => _ConferencePageState();
}

class _ConferencePageState extends State<ConferencePage>
    with TickerProviderStateMixin {
  // ── Agora RTC ──────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _localVideoReady = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isScreenSharing = false;
  bool _hasRetriedWithoutToken = false;
  VideoViewController? _localVideoController;
  VideoViewController? _remoteVideoController;

  // ── In-Call Chat ───────────────────────────────────────────────────────────
  final List<_ChatMsg> _messages = [];
  final _chatController = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  bool _showChat = false;
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _chatSub;

  String get _chatRoomId =>
      widget.sessionId.isNotEmpty ? widget.sessionId : widget.channelName;

  // ── UI Misc ────────────────────────────────────────────────────────────────
  bool _showControls = true;
  Timer? _hideControlsTimer;
  late AnimationController _fadeCtrl;
  bool _callEnded = false;
  String? _initError; // non-null = init failed, show error overlay

  final _agoraService = AgoraService.instance;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _initChatListener();
    _initAgora();
  }

  // ── Agora Init ─────────────────────────────────────────────────────────────

  Future<void> _initAgora() async {
    try {
      // 1. Request runtime permissions on Android / iOS
      if (!kIsWeb) {
        final statuses = await [Permission.camera, Permission.microphone].request();
        debugPrint('[Agora] Permissions: camera=${statuses[Permission.camera]}, mic=${statuses[Permission.microphone]}');
      }

      if (!_agoraService.isConfigured) {
        _showConfigError();
        return;
      }

      // 2. Clean up previous engine instance if lingering
      if (_engine != null) {
        try {
          await _engine!.leaveChannel();
          await _engine!.release();
        } catch (_) {}
        _engine = null;
        _localVideoController = null;
        _remoteVideoController = null;
      }

      // 3. Create RTC engine with Communication profile (standard for 1-to-1 video calls)
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _agoraService.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // 4. Register event handlers BEFORE joining channel
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[Agora] Joined channel: ${connection.channelId}, localUid: ${connection.localUid}');
          if (mounted) {
            setState(() {
              _localVideoReady = true;
              _localVideoController ??= VideoViewController(
                rtcEngine: _engine!,
                canvas: const VideoCanvas(uid: 0),
              );
            });
          }
        },
        onConnectionStateChanged: (connection, state, reason) async {
          debugPrint('[Agora] Connection state: $state, reason: $reason');
          if (state == ConnectionStateType.connectionStateConnected) {
            if (mounted) {
              setState(() {
                _localVideoReady = true;
                _localVideoController ??= VideoViewController(
                  rtcEngine: _engine!,
                  canvas: const VideoCanvas(uid: 0),
                );
              });
            }
          } else if (state == ConnectionStateType.connectionStateFailed) {
            debugPrint('[Agora] Connection failed with reason: $reason');
            if (reason == ConnectionChangedReasonType.connectionChangedInvalidToken ||
                reason == ConnectionChangedReasonType.connectionChangedTokenExpired) {
              // If token failed, attempt joining with empty token in case project uses App ID only
              if (!_hasRetriedWithoutToken) {
                _hasRetriedWithoutToken = true;
                debugPrint('[Agora] Retrying connection with empty token...');
                try {
                  await _engine?.leaveChannel();
                  await _engine?.joinChannel(
                    token: '',
                    channelId: widget.channelName,
                    uid: 0,
                    options: const ChannelMediaOptions(
                      channelProfile: ChannelProfileType.channelProfileCommunication,
                      clientRoleType: ClientRoleType.clientRoleBroadcaster,
                      autoSubscribeAudio: true,
                      autoSubscribeVideo: true,
                      publishCameraTrack: true,
                      publishMicrophoneTrack: true,
                    ),
                  );
                  return;
                } catch (retryErr) {
                  debugPrint('[Agora] Retry with empty token failed: $retryErr');
                }
              }
              if (mounted) {
                setState(() {
                  _initError =
                      'Agora Token Authentication Failed.\n\n'
                      'Please verify your Agora project security settings in console.agora.io '
                      'and ensure your App ID and App Certificate match.';
                });
              }
            }
          }
        },
        onUserJoined: (connection, uid, elapsed) {
          debugPrint('[Agora] Remote user joined: $uid');
          if (mounted) {
            setState(() {
              _remoteUid = uid;
              _remoteVideoController = VideoViewController.remote(
                rtcEngine: _engine!,
                canvas: VideoCanvas(uid: uid, renderMode: RenderModeType.renderModeFit),
                connection: RtcConnection(channelId: widget.channelName),
              );
            });
          }
        },
        onUserOffline: (connection, uid, reason) {
          debugPrint('[Agora] Remote user left: $uid, reason: $reason');
          if (mounted && _remoteUid == uid) {
            setState(() {
              _remoteUid = null;
              _remoteVideoController = null;
            });
          }
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          debugPrint('[Agora] Remote video state changed: uid=$remoteUid, state=$state, reason=$reason');
          if (mounted &&
              (state == RemoteVideoState.remoteVideoStateStarting ||
                  state == RemoteVideoState.remoteVideoStateDecoding)) {
            if (_remoteUid != remoteUid || _remoteVideoController == null) {
              setState(() {
                _remoteUid = remoteUid;
                _remoteVideoController = VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: remoteUid, renderMode: RenderModeType.renderModeFit),
                  connection: RtcConnection(channelId: widget.channelName),
                );
              });
            }
          }
        },
        onError: (err, msg) {
          debugPrint('[Agora] RTC error: $err — $msg');
          if (err == ErrorCodeType.errTokenExpired ||
              err == ErrorCodeType.errInvalidToken) {
            if (mounted) {
              setState(() {
                _initError =
                    'Agora Token Rejected / Expired.\n\n'
                    'Please verify your Agora project security settings in console.agora.io '
                    'or set a valid AGORA_TEMP_TOKEN in your .env file.';
              });
            }
          }
        },
      ));

      // 5. Enable BOTH video and audio explicitly
      await _engine!.enableVideo();
      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // 6. On mobile, default to speakerphone for video calls
      if (!kIsWeb) {
        try {
          await _engine!.setDefaultAudioRouteToSpeakerphone(true);
          await _engine!.setEnableSpeakerphone(true);
        } catch (e) {
          debugPrint('[Agora] Speakerphone setup note: $e');
        }
      }

      // 7. Start local preview immediately so camera renders in PiP
      try {
        await _engine!.startPreview();
      } catch (e) {
        debugPrint('[Agora] startPreview note: $e');
      }

      if (mounted) {
        setState(() {
          _localVideoReady = true;
          _localVideoController = VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0, renderMode: RenderModeType.renderModeFit),
          );
        });
      }

      // 8. Fetch token and join channel
      final token = await _agoraService.fetchToken(
        channelName: widget.channelName,
        uid: 0,
      );

      await _engine!.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: 0, // 0 = Agora assigns automatically
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );

      _resetHideTimer();
    } catch (e, stack) {
      debugPrint('[Agora] Init failed: $e\n$stack');
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  void _initChatListener() {
    try {
      _chatSub = FirebaseFirestore.instance
          .collection('conference_chats')
          .doc(_chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(
        (snapshot) {
          if (!mounted) return;
          final List<_ChatMsg> loaded = [];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final senderUid = data['senderUid'] as String? ?? '';
            final senderName = data['senderName'] as String? ?? 'User';
            final text = data['text'] as String? ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final time = ts?.toDate() ?? DateTime.now();
            loaded.add(_ChatMsg(
              sender: senderName,
              text: text,
              isMe: senderUid == widget.currentUser.uid,
              time: time,
            ));
          }

          if (!_showChat && loaded.length > _messages.length) {
            _unreadCount += (loaded.length - _messages.length);
          }

          setState(() {
            _messages.clear();
            _messages.addAll(loaded);
          });
          _scrollChatToBottom();
        },
        onError: (e) {
          debugPrint('[ConferenceChat] Firestore listener error: $e');
        },
      );
    } catch (e) {
      debugPrint('[ConferenceChat] Init listener error: $e');
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  void _toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.muteLocalAudioStream(_isMuted);
    await _engine?.enableLocalAudio(!_isMuted);
    setState(() {});
  }

  void _toggleCamera() async {
    _isCameraOff = !_isCameraOff;
    await _engine?.muteLocalVideoStream(_isCameraOff);
    await _engine?.enableLocalVideo(!_isCameraOff);
    setState(() {});
  }

  void _toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    // setEnableSpeakerphone is mobile-only
    if (!kIsWeb) {
      await _engine?.setEnableSpeakerphone(_isSpeakerOn);
    }
    setState(() {});
  }

  void _switchCamera() async {
    if (!kIsWeb) {
      await _engine?.switchCamera();
    }
  }

  Future<void> _toggleScreenShare() async {
    if (_engine == null) return;
    try {
      if (!_isScreenSharing) {
        // Start screen sharing
        await _engine!.startScreenCapture(const ScreenCaptureParameters2(
          captureAudio: true,
          captureVideo: true,
        ));
        await _engine!.updateChannelMediaOptions(const ChannelMediaOptions(
          publishCameraTrack: false,
          publishScreenTrack: true,
          publishScreenCaptureAudio: true,
          publishScreenCaptureVideo: true,
        ));
        setState(() => _isScreenSharing = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screen sharing started'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF81B655),
            ),
          );
        }
      } else {
        // Stop screen sharing
        await _engine!.stopScreenCapture();
        await _engine!.updateChannelMediaOptions(ChannelMediaOptions(
          publishCameraTrack: !_isCameraOff,
          publishScreenTrack: false,
          publishScreenCaptureAudio: false,
          publishScreenCaptureVideo: false,
        ));
        setState(() => _isScreenSharing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screen sharing stopped'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Agora] Screen share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screen share note: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _endCall() async {
    setState(() => _callEnded = true);
    if (_isScreenSharing) {
      try {
        await _engine?.stopScreenCapture();
      } catch (_) {}
      _isScreenSharing = false;
    }
    _localVideoController = null;
    _remoteVideoController = null;
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (mounted) Navigator.of(context).pop();
  }

  // ── HUD auto-hide ──────────────────────────────────────────────────────────

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
      _fadeCtrl.forward();
    }
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_showChat) {
        setState(() => _showControls = false);
        _fadeCtrl.reverse();
      }
    });
  }

  // ── Chat helpers ───────────────────────────────────────────────────────────

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
      if (_showChat) _unreadCount = 0;
    });
    if (_showChat) {
      _hideControlsTimer?.cancel();
      _scrollChatToBottom();
    } else {
      _resetHideTimer();
    }
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    final senderName = widget.currentUser.displayName ??
        widget.currentUser.email?.split('@').first ??
        'User';

    try {
      await FirebaseFirestore.instance
          .collection('conference_chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderUid': widget.currentUser.uid,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ConferenceChat] Send message error: $e');
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            sender: senderName,
            text: text,
            isMe: true,
            time: DateTime.now(),
          ));
        });
        _scrollChatToBottom();
      }
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showConfigError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            'Agora Not Configured',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Please add your AGORA_APP_ID to the .env file.\n\n'
            '1. Visit console.agora.io\n'
            '2. Create a project\n'
            '3. Copy App ID → paste into .env as AGORA_APP_ID',
            style: GoogleFonts.inter(color: Colors.white70, height: 1.6),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF81B655),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child:
                  Text('Go Back', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Init error overlay ─────────────────────────────────────────────────
    if (_initError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 56),
                const SizedBox(height: 20),
                Text(
                  'Could not start conference',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _initError!,
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontSize: 12, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text('Go Back',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81B655),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => _resetHideTimer(),
        child: Stack(
          children: [
            // ── Remote video (full screen) ────────────────────────────────
            _buildRemoteVideo(),

            // ── Local video (PiP) ─────────────────────────────────────────
            _buildLocalPiP(),

            // ── Top HUD ───────────────────────────────────────────────────
            _buildTopHUD(),

            // ── Bottom Controls ───────────────────────────────────────────
            _buildBottomControls(),

            // ── Chat Panel ────────────────────────────────────────────────
            if (_showChat) _buildChatPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (_remoteUid != null && _remoteVideoController != null) {
      final isPhone = MediaQuery.of(context).size.width < 600 ||
          MediaQuery.of(context).size.shortestSide < 600;
      if (isPhone) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: AgoraVideoView(
              controller: _remoteVideoController!,
            ),
          ),
        );
      }
      return SizedBox.expand(
        child: AgoraVideoView(
          controller: _remoteVideoController!,
        ),
      );
    }

    // Waiting for remote
    return Container(
      color: const Color(0xFF0D1117),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white54, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for ${widget.otherParticipantName}…',
              style: GoogleFonts.outfit(
                color: Colors.white60,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF81B655),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPiP() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 70,
      width: 110,
      height: 156,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: _isCameraOff || !_localVideoReady || _localVideoController == null || _engine == null
              ? Container(
                  color: const Color(0xFF1E293B),
                  child: const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white38,
                    size: 32,
                  ),
                )
              : AgoraVideoView(
                  controller: _localVideoController!,
                ),
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            bottom: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              // Session info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.sessionTitle,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'with ${widget.otherParticipantName}',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Live indicator & Camera switch
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _switchCamera,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 520;
    final isVerySmall = screenWidth < 380;

    final btnSize = isVerySmall ? 40.0 : (isSmall ? 46.0 : 52.0);
    final iconSize = isVerySmall ? 18.0 : (isSmall ? 20.0 : 22.0);
    final endCallSize = isVerySmall ? 48.0 : (isSmall ? 54.0 : 64.0);
    final endCallIconSize = isVerySmall ? 22.0 : (isSmall ? 26.0 : 30.0);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + (isSmall ? 14 : 24),
            top: isSmall ? 16 : 24,
            left: isSmall ? 8 : 28,
            right: isSmall ? 8 : 28,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.88), Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlBtn(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: isSmall
                    ? (_isMuted ? 'Muted' : 'Mic')
                    : (_isMuted ? 'Unmute' : 'Mute'),
                active: _isMuted,
                activeColor: Colors.redAccent,
                onTap: _toggleMute,
                size: btnSize,
                iconSize: iconSize,
              ),
              _buildControlBtn(
                icon: _isCameraOff
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                label: isSmall
                    ? (_isCameraOff ? 'Cam Off' : 'Cam')
                    : (_isCameraOff ? 'Start Cam' : 'Stop Cam'),
                active: _isCameraOff,
                activeColor: Colors.redAccent,
                onTap: _toggleCamera,
                size: btnSize,
                iconSize: iconSize,
              ),
              _buildControlBtn(
                icon: _isScreenSharing
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                label: isSmall
                    ? (_isScreenSharing ? 'Stop' : 'Share')
                    : (_isScreenSharing ? 'Stop Share' : 'Share Screen'),
                active: _isScreenSharing,
                activeColor: const Color(0xFF3B82F6),
                onTap: _toggleScreenShare,
                size: btnSize,
                iconSize: iconSize,
              ),
              // End call button (larger, red)
              GestureDetector(
                onTap: _endCall,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: endCallSize,
                      height: endCallSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEF4444),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: endCallIconSize,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Leave',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: isSmall ? 9.5 : 10.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildControlBtn(
                icon: _isSpeakerOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                label: isSmall
                    ? (_isSpeakerOn ? 'Speaker' : 'Ear')
                    : (_isSpeakerOn ? 'Speaker' : 'Earpiece'),
                active: false,
                onTap: _toggleSpeaker,
                size: btnSize,
                iconSize: iconSize,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildControlBtn(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    active: _showChat,
                    activeColor: const Color(0xFF81B655),
                    onTap: _toggleChat,
                    size: btnSize,
                    iconSize: iconSize,
                  ),
                  if (_unreadCount > 0 && !_showChat)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required bool active,
    Color activeColor = Colors.white24,
    required VoidCallback onTap,
    double size = 52,
    double iconSize = 22,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? activeColor : Colors.white.withOpacity(0.15),
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: size + 10,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: size < 48 ? 9.5 : 10.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width < 600
          ? MediaQuery.of(context).size.width
          : 360,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(left: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          children: [
            // Chat Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 8,
                bottom: 12,
              ),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded,
                      color: Color(0xFF81B655), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In-Call Chat',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleChat,
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              color: Colors.white24, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet.\nSay hi!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _chatScrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        return _buildChatBubble(msg);
                      },
                    ),
            ),

            // Input
            Container(
              color: const Color(0xFF1E293B),
              padding: EdgeInsets.only(
                left: 12,
                right: 8,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF81B655),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(_ChatMsg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment:
            msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: msg.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!msg.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  msg.sender,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF81B655),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isMe
                    ? const Color(0xFF81B655)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
                  bottomRight: Radius.circular(msg.isMe ? 4 : 16),
                ),
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.inter(
                  color: msg.isMe
                      ? Colors.white
                      : Colors.white.withAlpha(224),
                  fontSize: 13,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                '${msg.time.hour}:${msg.time.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  color: Colors.white24,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _fadeCtrl.dispose();
    _chatController.dispose();
    _chatScrollCtrl.dispose();
    _chatSub?.cancel();
    _localVideoController = null;
    _remoteVideoController = null;
    if (!_callEnded) {
      _engine?.leaveChannel();
      _engine?.release();
    }
    super.dispose();
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

class _ChatMsg {
  final String sender;
  final String text;
  final bool isMe;
  final DateTime time;

  const _ChatMsg({
    required this.sender,
    required this.text,
    required this.isMe,
    required this.time,
  });
}
