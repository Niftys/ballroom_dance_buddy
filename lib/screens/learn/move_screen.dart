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
    _loadFigureData();
  }

  Future<void> _loadFigureData() async {
    try {
      print("Move data received: ${widget.move}");
      print("Video URL type: ${widget.move['video_url']?.runtimeType}");

      var rawVideoUrl = widget.move['video_url'];
      String processedVideoUrl;

      if (rawVideoUrl is String) {
        processedVideoUrl = rawVideoUrl;
      } else if (rawVideoUrl is Map) {
        processedVideoUrl = rawVideoUrl.toString();
      } else {
        processedVideoUrl = '';
      }

      setState(() {
        videoUrl = processedVideoUrl;
        start = (widget.move['start'] ?? 0).toDouble();
        end = (widget.move['end'] ?? 0).toDouble();
      });

      if (videoUrl.isEmpty || start >= end) {
        setState(() => _videoError = true);
        return;
      }

      _initializePlayer();
    } catch (e) {
      print("Error in _loadFigureData: $e");
      setState(() => _videoError = true);
    }
  }

  Future<void> _initializePlayer() async {
    try {
      print("Using videoUrl: $videoUrl (${videoUrl.runtimeType})");

      String safeVideoId = videoUrl.toString();

      if (safeVideoId.isEmpty) {
        print("Error: Video ID is empty");
        setState(() => _videoError = true);
        return;
      }

      _controller = YoutubePlayerController(
        params: YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: false,
        ),
      );

      _controller!.loadVideoById(
        videoId: safeVideoId,
        startSeconds: start,
      );

      videoId = safeVideoId;

      _startLoopCheck();
    } catch (e) {
      print("Error initializing player: $e");
      setState(() => _videoError = true);
    }
  }

  void _startLoopCheck() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final currentTime = await _controller!.currentTime;
      if (currentTime >= end) {
        try {
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
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Move Details"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
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
        title: const Text("Move Details"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: YoutubePlayer(
        controller: _controller!,
        aspectRatio: 16 / 9,
      ),
    );
  }
}