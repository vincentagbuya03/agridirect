import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../shared/services/communication/call_service.dart';
import '../../../shared/widgets/image_widgets.dart';

class InAppCallScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final String callId;
  final String channelName;
  final bool isVideo;
  final bool isIncoming;

  /// Set to true when accepting from a background/killed CallKit notification.
  final bool isAlreadyAccepted;

  /// When true, renders as a Scaffold (for web route navigation).
  /// When false (default), renders as Dialog.fullscreen (for mobile dialog).
  final bool isRoute;

  /// Callback triggered when the call has ended, allowing the parent to rebuild
  /// and transition away from the standalone call MaterialApp when launched via CallKit.
  final VoidCallback? onCallEnded;

  const InAppCallScreen({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.callId,
    required this.channelName,
    required this.isVideo,
    required this.isIncoming,
    this.isAlreadyAccepted = false,
    this.isRoute = false,
    this.onCallEnded,
  });

  @override
  State<InAppCallScreen> createState() => _InAppCallScreenState();
}

class _InAppCallScreenState extends State<InAppCallScreen>
    with TickerProviderStateMixin {
  final _callService = CallService();
  bool _isMuted = false;
  bool _isSpeaker = !kIsWeb;
  bool _isCameraOff = false;
  bool _isRemoteCameraOff = false;
  bool _isEndingCall = false;

  String _status = 'Connecting...';
  int? _remoteUid;
  bool _joinedChannel = false;
  StreamSubscription? _callSubscription;

  Timer? _durationTimer;
  int _durationSeconds = 0;
  String _durationString = '00:00';

  // Polling fallback — runs every 2s while caller is waiting for connection,
  // and every 5s after connected to catch remote 'ended' events.
  Timer? _pollTimer;
  Timer? _connectedPollTimer;

  // True once the remote Agora peer has joined — prevents premature 'Connected' on caller.
  bool _remotePeerJoined = false;

  // Pulse animation for avatar ring while connecting/calling
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    if (widget.isAlreadyAccepted) {
      _status = 'Connecting...';
    } else {
      _status = widget.isIncoming ? 'Ringing...' : 'Calling...';
      if (widget.isIncoming) {
        try {
          FlutterRingtonePlayer().playRingtone(looping: true);
        } catch (e) {
          debugPrint('Error playing ringtone: $e');
        }
      }
    }
    _initCallSession();
  }

  // ─────────────────────────────────────────────────────── call session ──

  Future<void> _initCallSession() async {
    final hasPermissions = await _callService.requestPermissions(
      requireCamera: widget.isVideo,
    );
    if (!hasPermissions) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isVideo
                  ? 'Camera & Microphone permissions are required.'
                  : 'Microphone permission is required.',
            ),
          ),
        );
        _endCall();
      }
      return;
    }

    final localUid = _callService.currentAgoraUid;
    await _callService.fetchAgoraToken(
      channelName: widget.channelName,
      uid: localUid,
    );
    await _callService.initAgora(enableVideo: widget.isVideo);

    _callService.engine?.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
          debugPrint('Agora error: code=${err.value()} name=$err msg=$msg');
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('Agora: joined channel uid=${connection.localUid}');
          if (mounted) setState(() => _joinedChannel = true);
          if (!kIsWeb) {
            Future.delayed(const Duration(milliseconds: 500), () async {
              try {
                await _callService.engine?.setEnableSpeakerphone(true);
                if (mounted) setState(() => _isSpeaker = true);
              } catch (e) {
                debugPrint('Agora speakerphone init error: $e');
              }
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('Agora: remote user joined uid=$remoteUid');
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
              _remotePeerJoined = true;
              _status = 'Connected';
            });
            _startDurationTimer();
            _pollTimer?.cancel();
            _startConnectedHeartbeat(); // Watch for remote 'ended' even if Realtime misses
          }
        },
        onRemoteAudioStateChanged:
            (
              RtcConnection connection,
              int remoteUid,
              RemoteAudioState state,
              RemoteAudioStateReason reason,
              int elapsed,
            ) {
              debugPrint(
                'Agora: remote audio uid=$remoteUid state=$state reason=$reason',
              );
            },
        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int speakerNumber,
              int totalVolume,
            ) {
              // Volume indicator — kept for debug purposes
            },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint(
                'Agora: remote user offline uid=$remoteUid reason=$reason',
              );
              _endCall();
            },
        onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
          debugPrint('Agora: remote user video muted=$muted');
          if (mounted) {
            setState(() {
              _isRemoteCameraOff = muted;
            });
          }
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('Agora: left channel');
        },
      ),
    );

    if (widget.isIncoming) {
      if (widget.isAlreadyAccepted) {
        debugPrint('📞 Already accepted via CallKit, joining channel directly');
        await _joinAgoraChannel();
        await _callService.updateCallStatus(widget.callId, 'connected');
        if (mounted) setState(() => _status = 'Connected');
        _listenToCallStatus();
        _startDurationTimer();
      } else {
        _listenToCallStatus();
      }
      return;
    }

    // Outgoing call: join channel immediately, then watch status
    await _joinAgoraChannel();
    _listenToCallStatus();
    // Start polling as belt-and-suspenders for unreliable Realtime on web
    _startStatusPolling();
  }

  Future<void> _joinAgoraChannel() async {
    try {
      if (widget.isVideo) {
        await _callService.engine?.enableVideo();
        await _callService.engine?.startPreview();
      } else {
        await _callService.engine?.disableVideo();
      }

      final localUid = _callService.currentAgoraUid;
      final token = await _callService.fetchAgoraToken(
        channelName: widget.channelName,
        uid: localUid,
      );

      await _callService.engine?.enableAudio();

      await _callService.engine?.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: localUid,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.isVideo,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideo,
        ),
      );
      debugPrint(
        'Agora: joinChannel called for ${widget.channelName} '
        '(token=${token.isEmpty ? "none" : "ok"})',
      );
    } catch (e) {
      debugPrint('Agora join channel failed: $e');
    }
  }

  // ───────────────────────────────────────────────── accept / end / mute ──

  /// Called when the receiver presses the green Accept button
  Future<void> _acceptCall() async {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    if (mounted) setState(() => _status = 'Connecting...');
    if (!kIsWeb) {
      await FlutterCallkitIncoming.setCallConnected(widget.callId);
    }
    // Join Agora FIRST so the DB update accurately reflects actual connection
    await _joinAgoraChannel();
    await _callService.updateCallStatus(widget.callId, 'connected');
    // Start polling as fallback after accepting
    _startStatusPolling();
  }

  void _listenToCallStatus() {
    _callSubscription = _callService.listenToCall(widget.callId).listen((
      callData,
    ) {
      final status = callData['status']?.toString();
      if (status == 'declined' || status == 'ended' || status == 'missed') {
        _endCall(updateDb: false);
      } else if (status == 'connected' && _status != 'Connected') {
        // IMPORTANT: Must wrap in try-catch — FlutterRingtonePlayer.stop()
        // throws on web (caller side), silently killing this callback.
        try {
          FlutterRingtonePlayer().stop();
        } catch (_) {}
        // Only fully transition to 'Connected' once Agora also confirms the
        // remote peer joined. On web the Agora onUserJoined event can be
        // delayed; show 'Connecting...' until both signals arrive.
        if (mounted) {
          if (_remotePeerJoined || !widget.isIncoming) {
            // Caller side: treat DB 'connected' as the signal since Agora web
            // SDK may not fire onUserJoined reliably. Set a 5-s grace timer.
            setState(() => _status = _remotePeerJoined ? 'Connected' : 'Connecting...');
            if (!_remotePeerJoined) {
              // Grace timer: if Agora doesn't fire within 5s, accept DB state.
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted && _status != 'Connected') {
                  setState(() {
                    _remotePeerJoined = true;
                    _status = 'Connected';
                  });
                  _startDurationTimer();
                  _startConnectedHeartbeat();
                }
              });
            } else {
              _startDurationTimer();
              _startConnectedHeartbeat();
            }
          } else {
            setState(() => _status = 'Connecting...');
          }
          _pollTimer?.cancel();
        }
      }
    });
  }

  /// Pre-connect polling: checks DB every 2s while waiting for the other side
  /// to accept/connect (covers Realtime and Agora SDK gaps).
  void _startStatusPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_status == 'Connected' || _isEndingCall || !mounted) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final data = await _callService.getCallStatus(widget.callId);
        if (data == null || !mounted) return;
        final status = data['status']?.toString();
        if (status == 'connected' && _status != 'Connected') {
          try {
            FlutterRingtonePlayer().stop();
          } catch (_) {}
          if (mounted) {
            setState(() => _status = 'Connected');
            _startDurationTimer();
            _startConnectedHeartbeat();
          }
          _pollTimer?.cancel();
        } else if (status == 'declined' ||
            status == 'ended' ||
            status == 'missed') {
          _endCall(updateDb: false);
        }
      } catch (_) {}
    });
  }

  /// Heartbeat poll after connected: every 5s watches for remote 'ended'
  /// in case the Supabase Realtime stream on either side misses the event.
  void _startConnectedHeartbeat() {
    _connectedPollTimer?.cancel();
    _connectedPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isEndingCall || !mounted) {
        _connectedPollTimer?.cancel();
        return;
      }
      try {
        final data = await _callService.getCallStatus(widget.callId);
        if (data == null || !mounted) return;
        final status = data['status']?.toString();
        if (status == 'ended' || status == 'declined' || status == 'missed') {
          _connectedPollTimer?.cancel();
          _endCall(updateDb: false);
        }
      } catch (_) {}
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _durationSeconds++;
          final m = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
          final s = (_durationSeconds % 60).toString().padLeft(2, '0');
          _durationString = '$m:$s';
        });
      }
    });
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    try {
      await _callService.engine?.muteLocalAudioStream(_isMuted);
    } catch (e) {
      debugPrint('Agora muteLocalAudioStream error: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_isSpeaker;
    setState(() => _isSpeaker = next);
    if (kIsWeb) return;
    try {
      await _callService.engine?.setEnableSpeakerphone(next);
    } catch (e) {
      debugPrint('Agora setEnableSpeakerphone error: $e');
    }
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    try {
      await _callService.engine?.muteLocalVideoStream(_isCameraOff);
      await _callService.engine?.enableLocalVideo(!_isCameraOff);
    } catch (e) {
      debugPrint('Agora enableLocalVideo/muteLocalVideoStream error: $e');
    }
  }

  Future<void> _declineCall() async {
    await _callService.updateCallStatus(widget.callId, 'declined');
    _endCall(updateDb: false);
  }

  Future<void> _endCall({bool updateDb = true}) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    _durationTimer?.cancel();
    _pollTimer?.cancel();
    _connectedPollTimer?.cancel();
    _callSubscription?.cancel();

    // ── Step 1: Update DB FIRST so remote side gets the 'ended' event ──────
    if (updateDb) {
      try {
        await _callService.updateCallStatus(widget.callId, 'ended');
      } catch (e) {
        debugPrint('Call status update error: $e');
      }
    }

    // ── Step 2: End CallKit notification on mobile ──────────────────────────
    if (!kIsWeb) {
      try {
        await FlutterCallkitIncoming.endCall(widget.callId);
      } catch (e) {
        debugPrint('CallKit endCall error: $e');
        try {
          await FlutterCallkitIncoming.endAllCalls();
        } catch (_) {}
      }
    }

    // ── Step 3: Dismiss the screen ──────────────────────────────────────────
    if (mounted) {
      if (widget.onCallEnded != null) {
        widget.onCallEnded!();
      } else if (widget.isRoute) {
        context.pop();
      } else {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        }
      }
    }

    // ── Step 4: Release Agora engine last ───────────────────────────────────
    try {
      await _callService.releaseAgora();
    } catch (e) {
      debugPrint('Agora release error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    _durationTimer?.cancel();
    _pollTimer?.cancel();
    _connectedPollTimer?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────── build ──

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 600;

    final body = Stack(
      children: [
        // ── Video Rendering Layer ──────────────────────────────────────────
        if (widget.isVideo && _joinedChannel) ...[
          if (_remoteUid != null) ...[
            if (!_isRemoteCameraOff)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _callService.engine!,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SafeCircleAvatar(
                          imageUrl: widget.avatarUrl,
                          radius: 50,
                          defaultBucket: 'uploads',
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: Text(
                            widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${widget.name} turned off camera',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_isCameraOff)
              Positioned(
                top: 80,
                right: 20,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.black,
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _callService.engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),
          ] else ...[
            if (!_isCameraOff)
              Positioned.fill(
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _callService.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                ),
              ),
          ],
        ],

        if (!widget.isVideo)
          Positioned.fill(child: Container(color: const Color(0xFF0F172A))),

        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(
              alpha: widget.isVideo && _remoteUid != null ? 0.35 : 0.0,
            ),
          ),
        ),

        // ── Control Interface Layer ────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 40,
              horizontal: isWide ? 80 : 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(),
                if (!widget.isVideo || _remoteUid == null)
                  _buildAvatarSection(isWide)
                else
                  _buildSmallOverlayInfo(),
                _buildBottomControls(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isRoute) {
      return Scaffold(backgroundColor: const Color(0xFF0F172A), body: body);
    }
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: body,
    );
  }

  // ──────────────────────────────────────────────────── widget helpers ──

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              widget.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              widget.isVideo
                  ? 'AgriDirect Video Call'
                  : 'AgriDirect Voice Call',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 12),
              SizedBox(width: 4),
              Text(
                'End-to-End Encrypted',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection(bool isWide) {
    final isConnected = _status == 'Connected';
    final size = isWide ? 150.0 : 120.0;

    return Column(
      children: [
        SizedBox(
          width: size + 100,
          height: size + 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Animated pulse rings ──
              if (!isConnected)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Stack(
                    alignment: Alignment.center,
                    children: List.generate(3, (i) {
                      final progress = (_pulseController.value + i / 3) % 1.0;
                      return Opacity(
                        opacity: (1.0 - progress).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1.0 + progress * 1.3,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              // ── Avatar ──
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isConnected ? Colors.greenAccent : Colors.green,
                    width: isConnected ? 3 : 2,
                  ),
                  boxShadow: isConnected
                      ? [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: ClipOval(
                  child: SafeCircleAvatar(
                    imageUrl: widget.avatarUrl,
                    radius: size / 2,
                    child: Icon(
                      Icons.person,
                      size: size * 0.5,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.name,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: isWide ? 34 : 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _buildStatusLabel(),
      ],
    );
  }

  Widget _buildStatusLabel() {
    if (_status == 'Connected') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _durationString,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ],
      );
    }
    return Text(
      _status,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSmallOverlayInfo() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.name,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _durationString,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      children: [
        // ── Control buttons (mute, camera, speaker) ──
        if (_status == 'Connected') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlBtn(
                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: 'Mute',
                isActive: _isMuted,
                onTap: _toggleMute,
              ),
              if (widget.isVideo)
                _controlBtn(
                  icon: _isCameraOff
                      ? Icons.videocam_off_rounded
                      : Icons.videocam_rounded,
                  label: 'Camera',
                  isActive: _isCameraOff,
                  onTap: _toggleCamera,
                ),
              _controlBtn(
                icon: _isSpeaker
                    ? Icons.volume_up_rounded
                    : Icons.volume_down_rounded,
                label: 'Speaker',
                isActive: _isSpeaker,
                onTap: _toggleSpeaker,
              ),
            ],
          ),
          const SizedBox(height: 36),
        ],

        // ── Accept / Decline / End ──
        if (widget.isIncoming && _status == 'Ringing...')
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionBtn(
                icon: Icons.call_end_rounded,
                color: Colors.red,
                label: 'Decline',
                onTap: _declineCall,
              ),
              _actionBtn(
                icon: Icons.call_rounded,
                color: Colors.green,
                label: 'Accept',
                onTap: _acceptCall,
              ),
            ],
          )
        else
          Center(
            child: _actionBtn(
              icon: Icons.call_end_rounded,
              color: Colors.red,
              label: '',
              onTap: _endCall,
              showLabel: false,
            ),
          ),
      ],
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 14,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF0F172A) : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool showLabel = true,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        if (showLabel && label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
