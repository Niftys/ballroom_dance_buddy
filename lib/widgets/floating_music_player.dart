import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../themes/colors.dart';

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
        _tapTimes[i]
            .difference(_tapTimes[i - 1])
            .inMilliseconds / 1000.0,
      );
    }

    // Calculate average interval and BPM
    final averageInterval = intervals.reduce((a, b) => a + b) /
        intervals.length;
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
      _currentTempo = 1.0;
      _adjustTempo(1.0);
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final floatingPlayerColors = Theme.of(context).extension<FloatingMusicPlayerTheme>()!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
          widget.onExpandToggle(_isExpanded);
        },
        child: FractionallySizedBox(
          widthFactor: 0.9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: floatingPlayerColors.background,
              border: Border.all(color: floatingPlayerColors.border),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: floatingPlayerColors.border.withOpacity(0.3),
                  offset: const Offset(0, -2),
                  blurRadius: 4.0,
                ),
              ],
            ),
            height: _isExpanded ? 300 : 60,
            child: _isExpanded ? _buildExpandedPlayer(floatingPlayerColors) : _buildMinimizedPlayer(floatingPlayerColors),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedPlayer(FloatingMusicPlayerTheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0), // Add padding around the music note icon
          child: Icon(Icons.music_note, color: colors.icon),
        ),
        Expanded(
          child: Text(
            _currentSongName ?? "No Song Playing",
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0), // Add padding around the play/pause icon
          child: IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: colors.icon),
            onPressed: _togglePlayPause,
          ),
        ),
      ],
    );
  }


  Widget _buildExpandedPlayer(FloatingMusicPlayerTheme floatingPlayerColors) {
    final floatingPlayerColors = Theme.of(context).extension<FloatingMusicPlayerTheme>()!;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Song Name with Padding
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0), // Add padding
            child: Center(
              child: Text(
                _currentSongName ?? "No Song Playing",
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Song Progress Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: TextStyle(color: floatingPlayerColors.text.withOpacity(0.6)),
                ),
                Expanded(
                  child: Slider(
                    value: _currentPosition.inMilliseconds.clamp(0, _songDuration.inMilliseconds).toDouble(),
                    min: 0.0,
                    max: _songDuration.inMilliseconds.toDouble(),
                    activeColor: floatingPlayerColors.sliderActiveTrack,
                    inactiveColor: floatingPlayerColors.sliderInactiveTrack,
                    thumbColor: floatingPlayerColors.sliderThumb,
                    onChanged: (value) {
                      final newPosition = Duration(milliseconds: value.toInt());
                      _seekSong(newPosition);
                    },
                  ),
                ),
                Text(
                  _formatDuration(_songDuration),
                  style: TextStyle(color: floatingPlayerColors.text.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          // Tempo Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  "Tempo:",
                  style: TextStyle(color: floatingPlayerColors.text.withOpacity(0.6)),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      valueIndicatorTextStyle: TextStyle(
                        color: floatingPlayerColors.playPauseButtonIcon, // Text color for label
                        fontSize: 12,
                      ),
                      valueIndicatorColor: floatingPlayerColors.tapButtonBackground, // Background color for label
                    ),
                    child: Slider(
                      value: _currentTempo,
                      min: 0.75,
                      max: 1.25,
                      divisions: 50,
                      activeColor: floatingPlayerColors.sliderActiveTrack,
                      inactiveColor: floatingPlayerColors.sliderInactiveTrack,
                      thumbColor: floatingPlayerColors.sliderThumb,
                      label: "${_currentTempo.toStringAsFixed(2)}x",
                      onChanged: _adjustTempo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // BPM Display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              "BPM: $_adjustedBPM",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          // Buttons: Tap, Play/Pause, Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Tap Button
              ElevatedButton(
                onPressed: _recordTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: floatingPlayerColors.tapButtonBackground,
                  foregroundColor: floatingPlayerColors.tapButtonText,
                  side: BorderSide(color: floatingPlayerColors.tapButtonBorder, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size(
                    MediaQuery.of(context).size.width * 0.3,
                    MediaQuery.of(context).size.height * 0.08,
                  ),
                ),
                child: Text(
                  "Tap",
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.02,
                    color: floatingPlayerColors.tapButtonText,
                  ),
                ),
              ),
              // Play/Pause Button
              ElevatedButton(
                onPressed: _togglePlayPause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: floatingPlayerColors.playPauseButtonBackground,
                  foregroundColor: floatingPlayerColors.playPauseButtonIcon,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.02),
                  minimumSize: Size(
                    MediaQuery.of(context).size.height * 0.1,
                    MediaQuery.of(context).size.height * 0.08,
                  ),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: floatingPlayerColors.playPauseButtonIcon,
                  size: MediaQuery.of(context).size.height * 0.04,
                ),
              ),
              // Reset Button
              ElevatedButton(
                onPressed: _resetTapTempo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: floatingPlayerColors.resetButtonBackground,
                  foregroundColor: floatingPlayerColors.resetButtonText,
                  side: BorderSide(color: floatingPlayerColors.resetButtonBorder, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size(
                    MediaQuery.of(context).size.width * 0.3,
                    MediaQuery.of(context).size.height * 0.08,
                  ),
                ),
                child: Text(
                  "Reset",
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.height * 0.02,
                    color: floatingPlayerColors.resetButtonText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}