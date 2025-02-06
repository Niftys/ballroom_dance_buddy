import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class MoveScreen extends StatefulWidget {
  final Map<String, dynamic> move;

  const MoveScreen({super.key, required this.move});

  @override
  _MoveScreenState createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  YoutubePlayerController? _controller;
  Timer? _loopTimer;
  bool _videoError = false;
  String? videoId;

  late double start;
  late double end;
  String videoUrl = '';

  @override
  void initState() {
    super.initState();
    _loadFigureData(); // Load video and figure data
  }

  Future<void> _loadFigureData() async {
    setState(() {
      videoUrl = widget.move['video_url'] ?? '';
      start = widget.move['start']?.toDouble() ?? 0;
      end = widget.move['end']?.toDouble() ?? 0;
    });

    if (videoUrl.isEmpty || start >= end) {
      setState(() => _videoError = true);
      return;
    }

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      videoId = videoUrl.trim();
      if (videoId!.isEmpty) {
        print("Error: Video ID is empty");
        setState(() => _videoError = true);
        return;
      }

      // Create the YoutubePlayerController instance
      _controller = YoutubePlayerController(
        params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: false,
        ),
      );

      // Load the video by ID and start at the specified time
      _controller!.loadVideoById(
        videoId: videoId!,
        startSeconds: start,
      );

      _startLoopCheck(); // Set up the loop check for video playback
    } catch (e) {
      print("Error initializing player: $e");
      setState(() => _videoError = true);
    }
  }

  void _startLoopCheck() {
    _loopTimer?.cancel(); // Cancel any existing timer
    _loopTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Get the current time
      final currentTime = await _controller!.currentTime;

      // Check if the video needs to loop
      if (currentTime >= end) {
        try {
          // Reload the video at the start time
          _controller!.loadVideoById(
            videoId: videoId!,
            startSeconds: start,
          );
        } catch (e) {
          if (kDebugMode) {
            print("Error reloading video: $e");
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _controller!.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoError) {
      return Scaffold(
        body: const Center(
          child: Text(
            'Error loading video. Please check the URL and try again.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: YoutubePlayer(
          controller: _controller!,
          aspectRatio: 16 / 9,
        ),
      ),
    );
  }
}