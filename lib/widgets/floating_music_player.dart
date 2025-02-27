import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../screens/music/music_screen.dart';
import '../themes/colors.dart';

class FloatingMusicPlayer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final ValueChanged<bool> onExpandToggle;
  final GlobalKey<MusicScreenState> musicScreenKey;
  final ValueChanged<String> onSongTitleChanged;

  const FloatingMusicPlayer({
    super.key,
    required this.audioPlayer,
    required this.onExpandToggle,
    required this.musicScreenKey,
    required this.onSongTitleChanged,
  });

  @override
  State<FloatingMusicPlayer> createState() => _FloatingMusicPlayerState();
}

class _FloatingMusicPlayerState extends State<FloatingMusicPlayer> {
  static const _minTempo = 0.75;
  static const _maxTempo = 1.25;
  static const _tempoDivisions = 50;
  static const _maxTapSamples = 12;

  // Stream subscriptions
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<SequenceState?>? _sequenceSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<PlayerState>? _playbackCompleteSubscription;

  bool _isExpanded = false;
  String? _currentSongName;
  Duration _currentPosition = Duration.zero;
  Duration _songDuration = Duration.zero;
  double _currentTempo = 1.0;
  bool _isPlaying = false;
  final List<DateTime> _tapTimes = [];
  int _baseBPM = 0;
  int _adjustedBPM = 0;

  @override
  void initState() {
    super.initState();
    _initializeAudioListeners();
    _setupPlaybackCompletion();
  }

  void _initializeAudioListeners() {
    _positionSubscription = widget.audioPlayer.positionStream.listen(_handlePositionUpdate);
    _durationSubscription = widget.audioPlayer.durationStream.listen(_handleDurationUpdate);
    _sequenceSubscription = widget.audioPlayer.sequenceStateStream.listen(_handleSequenceUpdate);
    _playerStateSubscription = widget.audioPlayer.playerStateStream.listen(_handlePlayerStateUpdate);
  }

  bool _isAutoplaying = false;

  void _setupPlaybackCompletion() {
    _playbackCompleteSubscription = widget.audioPlayer.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (_isAutoplaying) {
          return;
        }

        _isAutoplaying = true;

        final musicScreenState = widget.musicScreenKey.currentState;
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

        if (musicScreenState != null && themeProvider.autoplayEnabled) {
          await Future.delayed(Duration(milliseconds: 500));
          musicScreenState.playNextSong();
        }

        _isAutoplaying = false;
      }
    });
  }

  void _handlePositionUpdate(Duration position) {
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      if (_currentPosition > _songDuration) {
        _currentPosition = _songDuration;
      }
    });
  }

  void _handleDurationUpdate(Duration? duration) {
    if (!mounted) return;
    setState(() => _songDuration = duration ?? Duration.zero);
  }

  void updateSongTitle(String newTitle) {
    if (!mounted) return;
    setState(() {
      _currentSongName = newTitle;
    });
  }

  void _handleSequenceUpdate(SequenceState? state) {
    if (!mounted) return;
    final songTitle = state?.currentSource?.tag as String?;

    if (songTitle != null) {
      widget.onSongTitleChanged(songTitle);
      setState(() => _currentSongName = songTitle);
    } else {
      setState(() => _currentSongName = "No Song Playing");
    }
  }

  void _handlePlayerStateUpdate(PlayerState state) {
    if (!mounted) return;
    setState(() => _isPlaying = state.playing);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _sequenceSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playbackCompleteSubscription?.cancel();
    super.dispose();
  }

  void _togglePlayPause() => _isPlaying ? widget.audioPlayer.pause() : widget.audioPlayer.play();

  void _adjustTempo(double tempo) {
    widget.audioPlayer.setSpeed(tempo);
    if (!mounted) return;
    setState(() {
      _currentTempo = tempo;
      _adjustedBPM = _baseBPM > 0 ? (_baseBPM * tempo).round() : 0;
    });
  }

  void _recordTap() {
    if (!mounted) return;
    setState(() {
      _tapTimes.add(DateTime.now());
      if (_tapTimes.length > _maxTapSamples) _tapTimes.removeAt(0);
      if (_tapTimes.length > 1) _calculateBPM();
    });
  }

  void _calculateBPM() {
    final intervals = List<double>.generate(
      _tapTimes.length - 1,
          (i) => _tapTimes[i + 1].difference(_tapTimes[i]).inMilliseconds / 1000,
    );

    final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    if (!mounted) return;
    setState(() {
      _baseBPM = (60 / averageInterval).round();
      _adjustedBPM = (_baseBPM * _currentTempo).round();
    });
  }

  void _seekSong(Duration position) => widget.audioPlayer.seek(position);

  void _resetTapTempo() {
    if (!mounted) return;
    setState(() {
      _tapTimes.clear();
      _baseBPM = _adjustedBPM = 0;
      _currentTempo = 1.0;
    });
    widget.audioPlayer.setSpeed(1.0);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<FloatingMusicPlayerTheme>()!;

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () => setState(() {
          _isExpanded = !_isExpanded;
          widget.onExpandToggle(_isExpanded);
        }),
        child: FractionallySizedBox(
          widthFactor: 0.9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: colors.border.withAlpha(75),
                  offset: const Offset(0, -2),
                  blurRadius: 4.0,
                ),
              ],
            ),
            height: _isExpanded ? 320 : 60,
            curve: Curves.easeInOut,
            child: _isExpanded
                ? _ExpandedView(
              colors: colors,
              songName: _currentSongName,
              currentPosition: _currentPosition,
              songDuration: _songDuration,
              currentTempo: _currentTempo,
              adjustedBPM: _adjustedBPM,
              isPlaying: _isPlaying,
              onTempoChanged: _adjustTempo,
              onSeek: _seekSong,
              onTap: _recordTap,
              onReset: _resetTapTempo,
              onPlayPause: _togglePlayPause,
              formatDuration: _formatDuration,
            )
                : _MinimizedView(
              colors: colors,
              songName: _currentSongName,
              isPlaying: _isPlaying,
              onPlayPause: _togglePlayPause,
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimizedView extends StatelessWidget {
  final FloatingMusicPlayerTheme colors;
  final String? songName;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _MinimizedView({
    required this.colors,
    required this.songName,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.music_note, size: 24),
          Expanded(
            child: Text(
              songName ?? "No Song Playing",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            color: colors.icon,
            onPressed: onPlayPause,
          ),
        ],
      ),
    );
  }
}

class _ExpandedView extends StatelessWidget {
  final FloatingMusicPlayerTheme colors;
  final String? songName;
  final Duration currentPosition;
  final Duration songDuration;
  final double currentTempo;
  final int adjustedBPM;
  final bool isPlaying;
  final ValueChanged<double> onTempoChanged;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final VoidCallback onPlayPause;
  final String Function(Duration) formatDuration;

  const _ExpandedView({
    required this.colors,
    required this.songName,
    required this.currentPosition,
    required this.songDuration,
    required this.currentTempo,
    required this.adjustedBPM,
    required this.isPlaying,
    required this.onTempoChanged,
    required this.onSeek,
    required this.onTap,
    required this.onReset,
    required this.onPlayPause,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 60),
              child: _SongTitle(songName: songName),
            ),
            const SizedBox(height: 6),

            _ProgressSlider(
              currentPosition: currentPosition,
              songDuration: songDuration,
              colors: colors,
              onSeek: onSeek,
              formatDuration: formatDuration,
            ),

            _TempoControl(
              currentTempo: currentTempo,
              colors: colors,
              onTempoChanged: onTempoChanged,
            ),
            const SizedBox(height: 6),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 40),
              child: _BpmDisplay(adjustedBPM: adjustedBPM),
            ),
            const SizedBox(height: 10),

            _ControlButtons(
              colors: colors,
              onTap: onTap,
              onReset: onReset,
              onPlayPause: onPlayPause,
              isPlaying: isPlaying,
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTitle extends StatelessWidget {
  final String? songName;

  const _SongTitle({required this.songName});

  @override
  Widget build(BuildContext context) {
    return Text(
      songName ?? "No Song Playing",
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ProgressSlider extends StatelessWidget {
  final Duration currentPosition;
  final Duration songDuration;
  final FloatingMusicPlayerTheme colors;
  final ValueChanged<Duration> onSeek;
  final String Function(Duration) formatDuration;

  const _ProgressSlider({
    required this.currentPosition,
    required this.songDuration,
    required this.colors,
    required this.onSeek,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: currentPosition.inMilliseconds.toDouble(),
            min: 0,
            max: songDuration.inMilliseconds.toDouble(),
            onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
            activeColor: colors.sliderActiveTrack,
            inactiveColor: colors.sliderInactiveTrack,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(currentPosition), style: TextStyle(color: colors.text)),
            Text(formatDuration(songDuration), style: TextStyle(color: colors.text)),
          ],
        ),
      ],
    );
  }
}

class _TempoControl extends StatelessWidget {
  final double currentTempo;
  final FloatingMusicPlayerTheme colors;
  final ValueChanged<double> onTempoChanged;

  const _TempoControl({
    required this.currentTempo,
    required this.colors,
    required this.onTempoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tempo: ${currentTempo.toStringAsFixed(2)}x',
          style: TextStyle(color: colors.text),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Slider(
            value: currentTempo,
            min: _FloatingMusicPlayerState._minTempo,
            max: _FloatingMusicPlayerState._maxTempo,
            divisions: _FloatingMusicPlayerState._tempoDivisions,
            onChanged: onTempoChanged,
            activeColor: colors.sliderActiveTrack,
            inactiveColor: colors.sliderInactiveTrack,
          ),
        ),
      ],
    );
  }
}

class _BpmDisplay extends StatelessWidget {
  final int adjustedBPM;

  const _BpmDisplay({required this.adjustedBPM});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'BPM: ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextSpan(
            text: '$adjustedBPM',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButtons extends StatelessWidget {
  final FloatingMusicPlayerTheme colors;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final VoidCallback onPlayPause;
  final bool isPlaying;

  const _ControlButtons({
    required this.colors,
    required this.onTap,
    required this.onReset,
    required this.onPlayPause,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              label: 'Tap',
              icon: CupertinoIcons.metronome,
              onPressed: onTap,
              backgroundColor: colors.tapButtonBackground,
            ),
            _PlayPauseButton(
              isPlaying: isPlaying,
              onPressed: onPlayPause,
              colors: colors,
            ),
            _ControlButton(
              label: 'Reset',
              icon: Icons.replay,
              onPressed: onReset,
              backgroundColor: colors.resetButtonBackground,
            ),
          ],
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 32),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final FloatingMusicPlayerTheme colors;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: colors.playPauseButtonBackground,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.border.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          size: 36,
        ),
        color: colors.playPauseButtonIcon,
        onPressed: onPressed,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}