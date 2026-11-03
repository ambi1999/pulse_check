// Pure Dart: session data, CSV building and email validation.
// No Flutter imports, so it can be unit tested without a phone.
import 'pulse_analysis.dart';

class MeasurementSession {
  const MeasurementSession({
    required this.recordingStart,
    required this.recordingEnd,
    required this.timestampsMs,
    required this.values,
    required this.result,
  });

  final DateTime recordingStart;
  final DateTime recordingEnd;
  final List<double> timestampsMs;
  final List<double> values;
  final PulseResult result;

  double get durationSeconds =>
      recordingEnd.difference(recordingStart).inMilliseconds / 1000;

  double get fpsActual {
    if (timestampsMs.length < 2) {
      return 0;
    }
    final spanMs = timestampsMs.last - timestampsMs.first;
    return spanMs <= 0 ? 0 : (timestampsMs.length - 1) * 1000 / spanMs;
  }

  String get bpmText {
    final bpm = result.bpm;
    return result.status == PulseStatus.ok && bpm != null ? '${bpm.round()}' : 'none';
  }

  String get statusText => result.status == PulseStatus.ok ? 'ok' : 'no_pulse';
}

/// ISO 8601 with the timezone offset, e.g. 2026-10-30T14:05:12.000+11:00.
String isoWithOffset(DateTime time) {
  if (time.isUtc) {
    return time.toIso8601String();
  }
  final offset = time.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${time.toIso8601String()}$sign$hours:$minutes';
}

String buildSessionCsv(MeasurementSession session, DateTime exportedAt) {
  final buffer = StringBuffer()
    ..writeln('# Pulse Check session')
    ..writeln('# recording_start: ${isoWithOffset(session.recordingStart)}')
    ..writeln('# recording_end: ${isoWithOffset(session.recordingEnd)}')
    ..writeln('# exported_at: ${isoWithOffset(exportedAt)}')
    ..writeln('# duration_s: ${session.durationSeconds.toStringAsFixed(1)}')
    ..writeln('# fps_actual: ${session.fpsActual.toStringAsFixed(1)}')
    ..writeln('# bpm: ${session.bpmText}')
    ..writeln('# status: ${session.statusText}')
    ..writeln('timestamp_ms,red_value');
  final firstMs = session.timestampsMs.isEmpty ? 0.0 : session.timestampsMs.first;
  for (var i = 0; i < session.values.length; i++) {
    final t = session.timestampsMs[i] - firstMs;
    buffer.writeln('${t.toStringAsFixed(1)},${session.values[i].toStringAsFixed(2)}');
  }
  return buffer.toString();
}

String sessionFileName(MeasurementSession session) {
  final s = session.recordingStart;
  String two(int n) => n.toString().padLeft(2, '0');
  return 'pulsecheck_${s.year}-${two(s.month)}-${two(s.day)}_${two(s.hour)}${two(s.minute)}.csv';
}

String sessionEmailBody(MeasurementSession session) {
  return 'Pulse Check session\n'
      'Recorded: ${isoWithOffset(session.recordingStart)}\n'
      'Duration: ${session.durationSeconds.toStringAsFixed(0)} s\n'
      'Heart rate: ${session.bpmText} BPM\n'
      'Status: ${session.statusText}\n\n'
      'Raw data is attached as CSV.\n'
      'For demo purposes only, not a medical device.';
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Splits "a@b.com, c@d.org" into a list, ignoring extra spaces.
List<String> parseEmails(String input) => input
    .split(RegExp(r'[,;\s]+'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// True when there is at least one address and every address looks valid.
bool isValidEmailList(String input) {
  final emails = parseEmails(input);
  return emails.isNotEmpty && emails.every(_emailPattern.hasMatch);
}
