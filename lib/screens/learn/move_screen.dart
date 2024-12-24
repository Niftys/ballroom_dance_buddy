import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  bool _videoError = false;
  Timer? _loopTimer;

  late int start;
  late int end;

  @override
  void initState() {
    super.initState();
    final String videoUrl = widget.move['video_url'] ?? '';
    start = widget.move['start'] ?? 0;
    end = widget.move['end'] ?? 0;

    final String? videoId = YoutubePlayerController.convertUrlToId(videoUrl);

    if (videoId == null) {
      setState(() {
        _videoError = true;
      });
      return;
    }

    try {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
        ),
      );

      _controller.cueVideoById(
        videoId: videoId,
        startSeconds: start.toDouble(),
      );

      // Start looping check
      _startLoopCheck(videoId);
    } catch (e) {
      print("Error initializing video: $e");
      setState(() {
        _videoError = true;
      });
    }
  }

  // Periodic check for video loop
  void _startLoopCheck(String videoId) {
    _loopTimer = Timer.periodic(Duration(milliseconds: 300), (timer) async {
      final currentPosition = await _controller.currentTime;

      if (currentPosition >= end) {

        // Pause and reload video from start
        _controller.pauseVideo();
        await Future.delayed(Duration(milliseconds: 100));

        // Force reload from start time to avoid playback continuation
        _controller.loadVideoById(
          videoId: videoId,
          startSeconds: start.toDouble(),
        );
      }
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _controller.stopVideo();
    _controller.close();
    _controller = YoutubePlayerController(); // Reset controller to avoid lingering references
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoError) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.move['description'] ?? 'Move Details'),
        ),
        body: Center(
          child: Text(
            'Failed to load video.',
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
            child: YoutubePlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
            ),
          ),
        ],
      ),
    );
  }
}