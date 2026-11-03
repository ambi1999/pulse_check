import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_check/pulse_analysis.dart';
import 'package:pulse_check/session_export.dart';

void main() {
  test('CSV has all header fields and one row per sample', () {
    final session = MeasurementSession(
      recordingStart: DateTime.utc(2026, 10, 30, 3, 5, 12),
      recordingEnd: DateTime.utc(2026, 10, 30, 3, 5, 32),
      timestampsMs: const [0, 33.3, 66.7],
      values: const [183.42, 183.61, 184.05],
      result: const PulseResult.ok(72),
    );

    final csv = buildSessionCsv(session, DateTime.utc(2026, 10, 30, 7, 30));
    final lines = csv.trim().split('\n');

    for (final field in [
      'recording_start: 2026-10-30T03:05:12.000Z',
      'recording_end: 2026-10-30T03:05:32.000Z',
      'exported_at:',
      'duration_s: 20.0',
      'bpm: 72',
      'status: ok',
    ]) {
      expect(csv, contains(field));
    }
    final dataRows = lines.skipWhile((l) => l != 'timestamp_ms,red_value').skip(1);
    expect(dataRows.length, 3);
  });

  test('email list validation', () {
    expect(isValidEmailList('a@example.com, b@example.org'), isTrue);
    expect(isValidEmailList('a@example.com, not-an-email'), isFalse);
    expect(isValidEmailList(''), isFalse);
  });
}
