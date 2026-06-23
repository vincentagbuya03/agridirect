import 'package:flutter/material.dart';
import 'package:agridirect/shared/services/core/supabase_config.dart';
import 'package:video_player/video_player.dart';

class ForumVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const ForumVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
  });

  @override
  State<ForumVideoPlayer> createState() => _ForumVideoPlayerState();
}

class _ForumVideoPlayerState extends State<ForumVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final safeUrl = widget.videoUrl.startsWith('http') && widget.videoUrl.contains('supabase.co')
          ? await SupabaseDatabase.getSafeUrl(widget.videoUrl, defaultBucket: 'uploads')
          : widget.videoUrl;

      _controller = VideoPlayerController.networkUrl(Uri.parse(safeUrl));
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = widget.autoPlay;
        });
        if (widget.autoPlay) {
          _controller.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }

    _controller.addListener(() {
      if (mounted) {
        final playing = _controller.value.isPlaying;
        if (playing != _isPlaying) {
          setState(() {
            _isPlaying = playing;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        color: const Color(0xFFF1F5F9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text(
                'Failed to load video',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        color: const Color(0xFFF8FAFC),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        if (_isInitialized && !_controller.value.isPlaying) {
          _controller.play();
        }
      },
      onExit: (_) {
        if (_isInitialized && _controller.value.isPlaying) {
          _controller.pause();
        }
      },
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: VideoPlayer(_controller),
            ),
            // Gradient Overlay for Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _togglePlay,
                    ),
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _toggleMute,
                    ),
                  ],
                ),
              ),
            ),
            // Progress Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.green,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
