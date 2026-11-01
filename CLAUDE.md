# Pulse Check — project guide for Claude Code

## Purpose
A learning project: the owner is learning every DevOps stage (plan, code,
build, test, release, deploy, operate, monitor) with a deliberately tiny
Android app. Keep everything minimal, beginner-friendly, free, and explain
changes simply.

## App: Pulse Check (Flutter, Android only)
Camera-based heart rate (PPG). User covers the rear camera with a finger,
flash on, app measures for 20 s and shows BPM.

### v1 (current)
- One screen: Measure button, live wave area, result area.
- Measure: camera permission (first time), flash (torch) on, 20 s countdown.
- Each frame: average red value from YUV420 (`R ≈ Y + 1.402 (V − 128)`),
  sampled on a sparse pixel grid, timestamped with a Stopwatch.
- Live wave: last ~5 s, drawn with a CustomPainter (no chart library).
- After 20 s: flash off, show BPM, or "Couldn't detect pulse, try again"
  if no valid pulse or BPM outside 40–200.
- Disclaimer: "For demo purposes only, not a medical device."

### v1.1 (next)
- Settings screen: recipient emails (comma-separated), validated, saved
  locally with shared_preferences.
- After a measurement: "Share results" opens the phone's email app
  (flutter_email_sender) with recipients, subject, summary body and a CSV
  attachment. If no emails saved, point the user to Settings.
- CSV: `#` header lines with recording_start, recording_end, exported_at
  (ISO 8601 with timezone offset), duration_s, fps_actual, bpm, status;
  then `timestamp_ms,red_value` rows. File name `pulsecheck_YYYY-MM-DD_HHMM.csv`.

### Out of scope (for now)
Database/history, HRV, high FPS, peak interpolation, iOS, accounts,
backend, crash monitoring, release signing (planned as v1.2).

## Code layout
- `lib/pulse_analysis.dart` — pure Dart signal processing (no Flutter
  imports). All BPM logic lives here and is unit tested.
- `lib/measure_screen.dart` — camera + UI.
- `lib/wave_painter.dart` — draws the live wave.
- v1.1 adds `session_export.dart` (pure: CSV + email validation),
  `settings_store.dart`, `settings_screen.dart`.

## Rules
- Keep business logic in pure Dart files so it can be unit tested without
  a device. Keep tests minimal (this is a DevOps tutorial).
- Code must pass `flutter analyze` with zero issues (infos count as
  failures in CI) and `flutter test`.
- Never commit to `main`. Work on a branch per GitHub issue
  (e.g. `feature/share-session`), push, open a PR with `gh pr create`.
- Run `flutter analyze` and `flutter test` before every commit.

## CI/CD (GitHub Actions)
- `ci.yml` — on PRs to main: analyze + test.
- `deploy.yml` — on push to main: analyze, test, build APK, upload to
  Firebase App Distribution (secrets: FIREBASE_APP_ID,
  FIREBASE_SERVICE_ACCOUNT; tester group: `testers`).
- `release.yml` — on tags `v*.*.*`: build APK, create a GitHub Release.

## Commands
- `flutter pub get` · `flutter analyze` · `flutter test` · `flutter run`
- Release tag: `git tag v1.0.0 && git push origin v1.0.0`
