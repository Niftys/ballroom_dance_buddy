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
    final RegExp regExp = RegExp(
      r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([^&\n?#]+)',
    );
    final match = regExp.firstMatch(videoUrl);
    videoId = match?.group(1);

    print(videoId);

    if (videoId == null) {
      print("Error: Unable to extract video ID from URL: $videoUrl");
      setState(() => _videoError = true);
      return;
    }

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId!,
      params: YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: false,
      ),
      startSeconds: start,
    );

    _startLoopCheck();
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
        appBar: AppBar(
          title: Text(widget.move['description'] ?? 'Move Details'),
        ),
        body: const Center(
          child: Text(
            'Error loading video. Please check the URL and try again.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.move['description'] ?? 'Move Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
      ),
    );
  }
}