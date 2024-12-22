import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MoveScreen extends StatefulWidget {
  final Map<String, dynamic> move;
  final void Function(bool)? onFullscreenChange;

  MoveScreen({required this.move, this.onFullscreenChange});

  @override
  _MoveScreenState createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;

  late int start; // Start time in seconds
  late int end;   // End time in seconds

  @override
  void initState() {
    super.initState();
    final String videoUrl = widget.move['video_url'] ?? '';
    start = widget.move['start'] ?? 0;
    end = widget.move['end'] ?? 0;

    final String? videoId = YoutubePlayer.convertUrlToId(videoUrl);

    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          startAt: start,
          enableCaption: false,
        ),
      )..addListener(_videoListener);  // Attach listener
    }
  }

  // Video loop and restrict seek logic
  void _videoListener() {
    final currentPosition = _controller.value.position.inSeconds;

    if (currentPosition >= end) {
      _controller.seekTo(Duration(seconds: start));
    } else if (currentPosition < start) {
      _controller.seekTo(Duration(seconds: start));
    }
  }

  // Fullscreen toggle handling
  void _toggleFullscreen(bool isEntering) {
    setState(() => _isFullScreen = isEntering);
    if (isEntering) {
      widget.onFullscreenChange?.call(true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      widget.onFullscreenChange?.call(false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String videoUrl = widget.move['video_url'] ?? '';
    final String? videoId = YoutubePlayer.convertUrlToId(videoUrl);

    if (videoId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.move['description'] ?? 'Move Details'),
        ),
        body: Center(
          child: Text(
            'No video available for this move.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
        title: Text(widget.move['description'] ?? 'Move Details'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: YoutubePlayerBuilder(
              onEnterFullScreen: () => _toggleFullscreen(true),
              onExitFullScreen: () => _toggleFullscreen(false),
              player: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                onReady: () {
                  _controller.play();
                  _controller.seekTo(Duration(seconds: start));
                },
              ),
              builder: (context, player) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: player,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}