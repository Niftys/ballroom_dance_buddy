import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class FloatingMusicPlayer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final ValueChanged<bool> onExpandToggle;

  FloatingMusicPlayer({required this.audioPlayer, required this.onExpandToggle});

  @override
  _FloatingMusicPlayerState createState() => _FloatingMusicPlayerState();
}

class _FloatingMusicPlayerState extends State<FloatingMusicPlayer> {
  bool _isExpanded = false;
  String? _currentSongName;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;
  double _currentTempo = 1.0;
  bool _isPlaying = false;

  // Tempo estimation variables
  final _tapTimes = [];
  int _baseBPM = 0; // Original tapped BPM
  int _adjustedBPM = 0; // BPM adjusted by tempo multiplier

  @override
  void initState() {
    super.initState();

    widget.audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    widget.audioPlayer.durationStream.listen((duration) {
      setState(() {
        _songDuration = duration ?? Duration.zero;
      });
    });

    widget.audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState?.currentSource != null) {
        final songName = sequenceState?.currentSource?.tag as String?;
        setState(() {
          _currentSongName = songName ?? "No Song Playing";
        });
      }
    });

    widget.audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.audioPlayer.pause();
    } else {
      widget.audioPlayer.play();
    }
  }

  void _adjustTempo(double tempo) {
    widget.audioPlayer.setSpeed(tempo);
    setState(() {
      _currentTempo = tempo;
      if (_baseBPM > 0) {
        _adjustedBPM = (_baseBPM * tempo).round();
      }
    });
  }

  void _recordTap() {
    final now = DateTime.now();
    setState(() {
      _tapTimes.add(now);

      // Keep the last 6 taps for more stable BPM calculations
      if (_tapTimes.length > 12) {
        _tapTimes.removeAt(0);
      }

      _calculateBPM();
    });
  }

  void _calculateBPM() {
    if (_tapTimes.length < 2) return; // Not enough taps for BPM calculation

    // Calculate intervals between taps in seconds
    List<double> intervals = [];
    for (int i = 1; i < _tapTimes.length; i++) {
      intervals.add(
        _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds / 1000.0,
      );
    }

    // Calculate average interval and BPM
    final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final newBPM = (60.0 / averageInterval).round();

    // Update base BPM and adjust based on current tempo
    setState(() {
      _baseBPM = newBPM;
      _adjustedBPM = (_baseBPM * _currentTempo).round();
    });
  }

  void _seekSong(Duration position) {
    widget.audioPlayer.seek(position);
    setState(() {
      _currentPosition = position;
    });
  }

  void _resetTapTempo() {
    setState(() {
      _tapTimes.clear();
      _baseBPM = 0;
      _adjustedBPM = 0;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
          widget.onExpandToggle(_isExpanded);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, -2),
                blurRadius: 4.0,
              ),
            ],
          ),
          height: _isExpanded ? 290 : 60, // Adjusted height for tap tempo
          width: MediaQuery.of(context).size.width,
          child: _isExpanded ? _buildExpandedPlayer() : _buildMinimizedPlayer(),
        ),
      ),
    );
  }

  Widget _buildMinimizedPlayer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(Icons.music_note, color: Colors.deepPurple),
        Expanded(
          child: Center(
            child: Text(
              _currentSongName ?? "No Song Playing",
              style: TextStyle(fontSize: 16, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.deepPurple,
          ),
          onPressed: _togglePlayPause,
        ),
      ],
    );
  }

  Widget _buildExpandedPlayer() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Center(
            child: Text(
              _currentSongName ?? "No Song Playing",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: TextStyle(color: Colors.grey),
                ),
                Expanded(
                  child: Slider(
                    value: _currentPosition.inMilliseconds
                        .clamp(0, _songDuration.inMilliseconds)
                        .toDouble(),
                    min: 0.0,
                    max: _songDuration.inMilliseconds.toDouble(),
                    activeColor: Colors.deepPurple,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (value) {
                      final newPosition = Duration(milliseconds: value.toInt());
                      _seekSong(newPosition);
                    },
                  ),
                ),
                Text(
                  _formatDuration(_songDuration),
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text("Tempo:", style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _currentTempo,
                    min: 0.5,
                    max: 1.5,
                    divisions: 100,
                    activeColor: Colors.deepPurple,
                    inactiveColor: Colors.grey.shade300,
                    label: "${_currentTempo.toStringAsFixed(2)}x",
                    onChanged: _adjustTempo,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              "BPM: $_adjustedBPM",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _recordTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade50,
                  foregroundColor: Colors.deepPurple,
                  side: BorderSide(color: Colors.deepPurple, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size(
                    MediaQuery.of(context).size.width * 0.3, // Width expands linearly with height
                    MediaQuery.of(context).size.height * 0.08, // Height is fixed relative to screen height
                  ),
                ),
                child: Text(
                  "Tap",
                  style: TextStyle(fontSize: MediaQuery.of(context).size.height * 0.02), // Adjust text size
                ),
              ),
              ElevatedButton(
                onPressed: _togglePlayPause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying
                      ? Colors.purple.shade100
                      : Colors.purple.shade50,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.height * 0.02, // Adjust padding for circular button
                  ),
                  minimumSize: Size(
                    MediaQuery.of(context).size.height * 0.1, // Width expands linearly with height
                    MediaQuery.of(context).size.height * 0.08, // Ensure a circular size
                  ),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.deepPurple,
                  size: MediaQuery.of(context).size.height * 0.04, // Icon scales with height
                ),
              ),
              ElevatedButton(
                onPressed: _resetTapTempo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size(
                    MediaQuery.of(context).size.width * 0.3, // Width expands linearly with height
                    MediaQuery.of(context).size.height * 0.08, // Height is fixed relative to screen height
                  ),
                ),
                child: Text(
                  "Reset",
                  style: TextStyle(fontSize: MediaQuery.of(context).size.height * 0.02), // Adjust text size
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}