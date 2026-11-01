import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_check/pulse_analysis.dart';

void main() {
  // 20 seconds of samples at 30 frames per second.
  final timestamps = List<double>.generate(600, (i) => i * 1000 / 30);

  test('detects about 72 BPM from a synthetic 1.2 Hz pulse', () {
    final values = [
      for (final t in timestamps) 180 + 2 * math.sin(2 * math.pi * 1.2 * t / 1000),
    ];

    final result = calculateBpm(timestamps, values);

    expect(result.status, PulseStatus.ok);
    expect(result.bpm, closeTo(72, 3));
  });

  test('reports no pulse for a flat signal', () {
    final values = List<double>.filled(timestamps.length, 180);

    final result = calculateBpm(timestamps, values);

    expect(result.status, PulseStatus.noPulse);
  });

  test('handles empty input without crashing', () {
    final result = calculateBpm(const [], const []);

    expect(result.status, PulseStatus.noPulse);
  });
}
