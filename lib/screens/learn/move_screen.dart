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
  late int end; // End time in seconds

  @override
  void initState() {
    super.initState();

    final String videoUrl = widget.move['video_url'] ?? '';
    start = widget.move['start'] ?? 0;
    end = widget.move['end'] ?? 0;

    // Extract the video ID from the URL
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
      );

      // Add listener to enforce seamless loop
      _controller.addListener(_videoListener);
    }
  }

  void _videoListener() {
    if (_controller.value.position.inSeconds >= end) {
      // Immediately loop back to the start time
      _controller.seekTo(Duration(seconds: start));
    }
  }

  void _toggleFullscreen(bool isEntering) {
    setState(() => _isFullScreen = isEntering);

    if (isEntering) {
      widget.onFullscreenChange?.call(true);
      // Hide system UI for fullscreen mode
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      widget.onFullscreenChange?.call(false);
      // Restore system UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _skipAhead() {
    final currentPosition = _controller.value.position.inSeconds;
    final newPosition = (currentPosition + 1).clamp(start, end);
    _controller.seekTo(Duration(seconds: newPosition));
  }

  void _rewind() {
    final currentPosition = _controller.value.position.inSeconds;
    final newPosition = (currentPosition - 1).clamp(start, end);
    _controller.seekTo(Duration(seconds: newPosition));
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
                onReady: () => _controller.play(),
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
          // Rewind and Skip Buttons
          if (!_isFullScreen) // Show only when not in fullscreen mode
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_outlined, size: 40),
                    onPressed: _rewind,
                    tooltip: "Rewind 1 second",
                  ),
                  SizedBox(width: 10), // Space between the left arrow and text
                  Text(
                    "1 sec.",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 10), // Space between the text and right arrow
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios_outlined, size: 40),
                    onPressed: _skipAhead,
                    tooltip: "Skip ahead 1 second",
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}