import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TapTempoEstimator extends StatefulWidget {
  final Function(int bpm) onBPMCalculated;

  const TapTempoEstimator({super.key, required this.onBPMCalculated});

  @override
  State<TapTempoEstimator> createState() => _TapTempoEstimatorState();
}

class _TapTempoEstimatorState extends State<TapTempoEstimator> {
  final List<DateTime> _tapTimes = [];
  int _calculatedBPM = 0;
  Timer? _inactivityTimer;
  double _tapConsistency = 0.0;

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _recordTap() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 4), _reset);
    HapticFeedback.lightImpact();

    setState(() {
      _tapTimes.add(DateTime.now());
      if (_tapTimes.length > 12) _tapTimes.removeAt(0);
      _calculateBPM();
      _calculateConsistency();
    });
  }

  void _calculateBPM() {
    if (_tapTimes.length < 2) return;

    final intervals = _calculateIntervals();
    final averageInterval = _calculateWeightedAverage(intervals);
    final bpm = (60 / averageInterval).round();

    if (bpm < 20 || bpm > 300) return;

    setState(() => _calculatedBPM = bpm);
    widget.onBPMCalculated(bpm);
  }

  List<double> _calculateIntervals() {
    return List.generate(
      _tapTimes.length - 1,
          (i) => _tapTimes[i + 1].difference(_tapTimes[i]).inMilliseconds / 1000,
    );
  }

  double _calculateWeightedAverage(List<double> intervals) {
    double weightedSum = 0;
    for (int i = 0; i < intervals.length; i++) {
      weightedSum += intervals[i] * (i + 1);
    }
    return weightedSum / (intervals.length * (intervals.length + 1) / 2);
  }

  void _calculateConsistency() {
    if (_tapTimes.length < 2) {
      _tapConsistency = 0.0;
      return;
    }

    final intervals = _calculateIntervals();
    final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals.map((i) => (i - averageInterval).abs()).reduce((a, b) => a + b);

    setState(() {
      _tapConsistency = (1 - (variance / intervals.length / averageInterval)).clamp(0.0, 1.0);
    });
  }

  void _reset() {
    setState(() {
      _tapTimes.clear();
      _calculatedBPM = 0;
      _tapConsistency = 0.0;
    });
    widget.onBPMCalculated(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        _buildBpmDisplay(),
        const SizedBox(height: 12),
        _buildConsistencyIndicator(),
        const SizedBox(height: 20),
        _buildControlButtons(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBpmDisplay() {
    return Column(
      children: [
        Text(
          _calculatedBPM > 0 ? '$_calculatedBPM BPM' : 'Tap Rhythm',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          _tapTimes.length < 2 ? '(2+ taps needed)' : ' ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildConsistencyIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _tapConsistency,
            backgroundColor: Colors.grey.shade200,
            color: _tapConsistency > 0.7
                ? Colors.green.shade400
                : _tapConsistency > 0.4
                ? Colors.orange.shade400
                : Colors.red.shade400,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text(
            'Consistency: ${(_tapConsistency * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTapButton(),
        const SizedBox(width: 20),
        _buildResetButton(),
      ],
    );
  }

  Widget _buildTapButton() {
    return ElevatedButton(
      onPressed: _recordTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade800,
      ),
      child: const Text(
        'TAP',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return IconButton(
      icon: Icon(Icons.replay, size: 32),
      color: Colors.grey.shade700,
      onPressed: _reset,
      style: IconButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}