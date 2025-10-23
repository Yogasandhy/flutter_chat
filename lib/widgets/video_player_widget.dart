import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    required this.color,
    required this.viewOnly,
  });

  final String videoUrl;
  final Color color;
  final bool viewOnly;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late CachedVideoPlayerPlus _cachedPlayer;
  bool isPlaying = false;
  bool isLoading = true;

  @override
  void initState() {
    _cachedPlayer = CachedVideoPlayerPlus.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _cachedPlayer
        .initialize()
        .then((_) {
          _cachedPlayer.controller.setVolume(1);
          setState(() {
            isLoading = false;
          });
        });
    super.initState();
  }

  @override
  void dispose() {
    _cachedPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : VideoPlayer(_cachedPlayer.controller),
          Center(
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.color,
              ),
              onPressed: widget.viewOnly
                  ? null
                  : () {
                      setState(() {
                        isPlaying = !isPlaying;
                        isPlaying
                            ? _cachedPlayer.controller.play()
                            : _cachedPlayer.controller.pause();
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }
}
