import 'package:flutter/material.dart';

class TapTempoEstimator extends StatefulWidget {
  final Function(int bpm) onBPMCalculated; // Callback to pass the calculated BPM

  TapTempoEstimator({required this.onBPMCalculated});

  @override
  _TapTempoEstimatorState createState() => _TapTempoEstimatorState();
}

class _TapTempoEstimatorState extends State<TapTempoEstimator> {
  List<DateTime> _tapTimes = []; // Store tap timestamps
  int _calculatedBPM = 0; // Displayed BPM

  void _recordTap() {
    final now = DateTime.now();
    setState(() {
      _tapTimes.add(now);

      // Keep the last 6 taps for more stable BPM calculations
      if (_tapTimes.length > 6) {
        _tapTimes.removeAt(0);
      }

      _calculateBPM();
    });
  }

  void _calculateBPM() {
    if (_tapTimes.length < 2) return; // Not enough data for BPM calculation

    // Calculate intervals between taps in seconds
    List<double> intervals = [];
    for (int i = 1; i < _tapTimes.length; i++) {
      intervals.add(
        _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds / 1000.0,
      );
    }

    // Calculate average interval and BPM
    final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    _calculatedBPM = (60.0 / averageInterval).round();

    // Pass the calculated BPM back to the parent widget
    widget.onBPMCalculated(_calculatedBPM);
  }

  void _reset() {
    setState(() {
      _tapTimes.clear();
      _calculatedBPM = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _calculatedBPM > 0 ? "BPM: $_calculatedBPM" : "Tap to Start",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _recordTap,
              child: Text("Tap"),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: _reset,
              child: Text("Reset"),
            ),
          ],
        ),
      ],
    );
  }
}
