// Pure Dart signal processing for camera PPG. No Flutter imports, so it can
// be unit tested without a phone.
import 'dart:math' as math;

enum PulseStatus { ok, noPulse }

class PulseResult {
  const PulseResult.ok(double this.bpm) : status = PulseStatus.ok;
  const PulseResult.noPulse()
      : status = PulseStatus.noPulse,
        bpm = null;

  final PulseStatus status;
  final double? bpm;
}

const double minBpm = 40;
const double maxBpm = 200;
const double _minDurationMs = 5000;
const int _minPeaks = 4;
const double _maxIntervalVariation = 0.4;
const double _minPeriodicity = 0.4;

/// Calculates heart rate from brightness samples.
///
/// [timestampsMs] and [values] must be the same length, one entry per frame.
PulseResult calculateBpm(List<double> timestampsMs, List<double> values) {
  if (values.length < 10 || timestampsMs.length != values.length) {
    return const PulseResult.noPulse();
  }
  final durationMs = timestampsMs.last - timestampsMs.first;
  if (durationMs < _minDurationMs || _stdDev(values) < 1e-6) {
    return const PulseResult.noPulse();
  }

  // 1. Remove slow drift: subtract a ~1 second moving average.
  final fps = (values.length - 1) * 1000 / durationMs;
  final trend = movingAverage(values, fps.round());
  final detrended = [
    for (var i = 0; i < values.length; i++) values[i] - trend[i],
  ];

  // 2. Light smoothing to reduce frame-to-frame noise.
  final signal = movingAverage(detrended, 3);
  final threshold = 0.5 * _stdDev(signal);
  if (threshold < 1e-9) {
    return const PulseResult.noPulse();
  }

  // 3. Find peaks, at least one max-BPM interval apart.
  final minGapMs = 60000 / maxBpm;
  final peaks = <int>[];
  for (var i = 1; i < signal.length - 1; i++) {
    final isPeak = signal[i] > threshold &&
        signal[i] > signal[i - 1] &&
        signal[i] >= signal[i + 1];
    if (!isPeak) {
      continue;
    }
    if (peaks.isNotEmpty && timestampsMs[i] - timestampsMs[peaks.last] < minGapMs) {
      if (signal[i] > signal[peaks.last]) {
        peaks[peaks.length - 1] = i;
      }
      continue;
    }
    peaks.add(i);
  }
  if (peaks.length < _minPeaks) {
    return const PulseResult.noPulse();
  }

  // 4. Beat-to-beat intervals -> BPM (median is robust to a missed beat).
  final intervals = [
    for (var i = 1; i < peaks.length; i++)
      timestampsMs[peaks[i]] - timestampsMs[peaks[i - 1]],
  ];
  final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
  if (_stdDev(intervals) / meanInterval > _maxIntervalVariation) {
    return const PulseResult.noPulse(); // too irregular: probably noise
  }
  final medianInterval = _median(intervals);

  // 5. A real pulse repeats: the signal should match itself shifted by one
  //    beat. Random noise doesn't, even if it happens to have peaks.
  final lag = (medianInterval / 1000 * fps).round();
  if (_autocorrelation(signal, lag) < _minPeriodicity) {
    return const PulseResult.noPulse();
  }

  final bpm = 60000 / medianInterval;
  if (bpm < minBpm || bpm > maxBpm) {
    return const PulseResult.noPulse();
  }
  return PulseResult.ok(bpm);
}

/// Last [maxPoints] samples, detrended, smoothed and inverted so each
/// heartbeat points upward. Used only for drawing.
List<double> waveForDisplay(List<double> values, {int maxPoints = 150}) {
  if (values.length < 3) {
    return const [];
  }
  final recent = values.sublist(math.max(0, values.length - maxPoints));
  final trend = movingAverage(recent, 31);
  final detrended = [
    for (var i = 0; i < recent.length; i++) recent[i] - trend[i],
  ];
  return [for (final v in movingAverage(detrended, 3)) -v];
}

/// Centered moving average; the window shrinks at the edges.
List<double> movingAverage(List<double> values, int window) {
  if (values.isEmpty) {
    return const [];
  }
  final half = math.max(window, 1) ~/ 2;
  final prefix = List<double>.filled(values.length + 1, 0);
  for (var i = 0; i < values.length; i++) {
    prefix[i + 1] = prefix[i] + values[i];
  }
  return [
    for (var i = 0; i < values.length; i++)
      _rangeMean(prefix, math.max(0, i - half), math.min(values.length - 1, i + half)),
  ];
}

double _rangeMean(List<double> prefix, int from, int to) =>
    (prefix[to + 1] - prefix[from]) / (to - from + 1);

double _stdDev(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
  return math.sqrt(variance);
}

double _autocorrelation(List<double> values, int lag) {
  if (lag <= 0 || lag >= values.length) {
    return 0;
  }
  final mean = values.reduce((a, b) => a + b) / values.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < values.length; i++) {
    final d = values[i] - mean;
    denominator += d * d;
    if (i + lag < values.length) {
      numerator += d * (values[i + lag] - mean);
    }
  }
  return denominator == 0 ? 0 : numerator / denominator;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
