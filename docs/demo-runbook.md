# Pulse Check: CI/CD demo runbook

Nov 7, 2026 · @Am

## What this runbook is for

Two live demos show the Pulse Check pipeline in under 30 minutes: CI blocks a bug before it reaches `main`, and CD delivers a merged change to a phone with no manual steps. Rehearse the full run the day before, then reset (see Reset after a rehearsal) so everything is ready again.

| Demo | What it proves | Live time |
| --- | --- | --- |
| 1. CI blocks a bug | Tests and branch protection stop a broken change, even from the repo owner | About 12 min (make the change, 2 min to red, fix, 5 min to green) |
| 2. CD to the phone | A merge is analysed, tested, signed, built and delivered automatically | About 15 min (make the change, 5 min CI, 7 min deploy, 1 min install) |

Run the demos one after the other: finish Demo 1 completely, including closing its pull request, before starting Demo 2. The phone's screen is shown on the projector with scrcpy (see Before the demo).

## Before the demo

Both code changes are made live in front of the audience, so they see the whole journey from editing a file to the result. Only the screen sharing and a short checklist need doing beforehand.

Optional safety net: during your rehearsal, also push the finished changes to two spare branches (for example `backup/ci-bug` and `backup/cd-change`). If a live edit goes wrong under pressure, open the pull request from the backup branch instead and carry on.

**Showing the phone on the projector (one-time setup)**

Use scrcpy, a free tool that mirrors an Android phone's screen in a window on the laptop over USB. The audience sees the real phone, and you control it with the mouse.

```
# Install scrcpy (one time)
winget install Genymobile.scrcpy

# With the phone plugged in by USB and USB debugging on, open the phone's screen in a window
scrcpy
```

Accept the "Allow USB debugging?" prompt on the phone the first time. Close the window to stop mirroring.

**On the demo day**

- [ ] Phone charged, App Tester signed in, latest build installed from App Tester (not a PR or `flutter run` build)
- [ ] Phone connected by USB and `scrcpy` showing its screen on the laptop
- [ ] Laptop on `main`, VS Code open in the project, `git pull` done
- [ ] Browser tabs open: Pull requests, Actions, Settings → Rules, Firebase App Distribution
- [ ] githubstatus.com shows no incidents
- [ ] Screenshots from the last rehearsal ready as a fallback

## Demo 1: CI blocks a bug

You make a small, believable mistake in the heart-rate formula live, skip running the tests, and push it. CI's unit test catches it, GitHub refuses to merge it, and you fix it.

**Information: CI in plain words**

Every time someone proposes a change, an automated system takes a clean computer, downloads the code and runs all the automatic checks, like a spell-checker plus a set of practice exam questions with known answers. If any answer comes out wrong, GitHub refuses to add the change to the real app until it is fixed, whoever wrote it, including the repository owner. Mistakes are caught within minutes, before any user sees them.

**Good practice: test before you commit**

A developer should run `flutter test` (and `flutter analyze`) on their own laptop and only commit when everything passes; the mistake would be caught right there in seconds. In this demo the step is deliberately skipped to show a developer who forgot. Developers sometimes forget, and some tests only fail on another machine; CI is the safety net that catches what slips through, every time. Teams can also make the laptop check automatic with a pre-commit hook, which runs the tests whenever someone tries to commit.

1. **Show the rule.** In GitHub, open **Settings → Rules → Rulesets → protect-main** and point to these four things:
   - **Enforcement status: Active.** The rule is switched on.
   - **Target branches: Default branch** (`main`). The rule protects `main`.
   - **Bypass list: empty.** Nobody is exempt, including you as the owner and admin. This is what makes it "even for me".
   - **Rules ticked:** "Require a pull request before merging" (no pushing straight to `main`) and "Require status checks to pass" with **analyze-and-test** listed (the CI job must be green).
2. **Show where the check comes from.** Open `.github/workflows/ci.yml`. `analyze-and-test` is the name of the job defined in this file; GitHub shows it on pull requests as the check "CI / analyze-and-test", and the ruleset requires that name.

   ```yaml
   # =============================================================================
   # CI (Continuous Integration): the quality gate for every proposed change
   #
   # What this file is:
   #   A recipe that GitHub follows automatically. Every time someone opens or
   #   updates a pull request into main, GitHub borrows a brand-new computer,
   #   downloads our code and runs the checks below, in order. If any step
   #   fails, the whole run turns red and the change cannot be merged.
   #
   # How it connects to the "protect-main" ruleset
   #   (GitHub: Settings > Rules > Rulesets > protect-main)
   #
   #   - Enforcement status: Active
   #       The rule is switched on. ("Evaluate" would only report, not block.)
   #   - Target branches: Default branch (main)
   #       The rule protects main, the branch the real app is built from.
   #   - Require a pull request before merging
   #       Nobody can push straight to main. Every change must arrive as a
   #       pull request, which is what starts this file.
   #   - Require status checks to pass: analyze-and-test
   #       The job below is called "analyze-and-test". The ruleset names that
   #       job, so the Merge button stays locked until this job is green.
   #   - Bypass list: empty
   #       Nobody is exempt, not even the repository owner or admins. The same
   #       rules apply to everyone, every time.
   # =============================================================================
   
   # The name shown on the Actions tab and on pull requests ("CI / analyze-and-test").
   name: CI
   
   # WHEN to run: whenever a pull request wants to change the main branch
   # (when it is opened, and again every time new code is pushed to it).
   on:
     pull_request:
       branches: [main]
   
   jobs:
     # The job name. This exact name is the "status check" the ruleset requires.
     analyze-and-test:
       # WHERE to run: a fresh Linux computer from GitHub, wiped after every run,
       # so results never depend on what happens to be installed on someone's laptop.
       runs-on: ubuntu-latest
   
       # WHAT to do, in order. If any step fails, the later steps are skipped
       # and the check turns red.
       steps:
         # 1. Download our code from GitHub onto the fresh computer.
         #    "uses:" means "run a ready-made tool" (here, GitHub's own checkout tool).
         #    "@v7" is the tool's version; Dependabot keeps it up to date for us.
         - name: Check out code
           uses: actions/checkout@v7
   
         # 2. Install Java. Android's build tools are written in Java, so the
         #    app cannot be built without it. "temurin" is a free, widely used
         #    edition of Java; version 17 is what current Android tools expect.
         - name: Set up Java
           uses: actions/setup-java@v6
           with:
             distribution: temurin
             java-version: '17'
   
         # 3. Install Flutter, the toolkit the app is written with.
         #    "stable" = the tested, recommended release of Flutter.
         #    "cache" keeps a copy of the download from earlier runs, so this
         #    step is faster next time.
         - name: Set up Flutter
           uses: subosito/flutter-action@v2
           with:
             channel: stable
             cache: true
   
         # 4. Download the packages the app relies on (camera, email, Firebase
         #    and others) at the exact versions recorded in pubspec.lock, so
         #    every run uses the same versions as the developer's laptop.
         #    "run:" means "type this command", just like in a terminal.
         - name: Install dependencies
           run: flutter pub get
   
         # 5. Static analysis: reads the code WITHOUT running it, like a
         #    spell-checker and grammar-checker for code. It catches mistakes
         #    and bad practice. Any problem it reports fails the run.
         - name: Static analysis
           run: flutter analyze
   
         # 6. Unit tests: runs every test in the test folder. Each test feeds
         #    the code an input whose correct answer we already know (for
         #    example, a fake pulse that must read 72 beats per minute) and
         #    fails if the code gives a different answer.
         - name: Unit tests
           run: flutter test
   
         # 7. Build the installable Android app (the APK file). This proves the
         #    change still turns into a working app, not just that the tests
         #    pass. "--debug" makes a quick test build, not the official release.
         - name: Build APK
           run: flutter build apk --debug
   
         # 8. Attach the app file to this run's Summary page, so a reviewer can
         #    download it and try this exact change on a phone before merging.
         #    It is deleted automatically after 7 days to save storage.
         - name: Upload APK
           uses: actions/upload-artifact@v7
           with:
             name: pulse-check-pr-apk
             path: build/app/outputs/flutter-apk/app-debug.apk
             retention-days: 7
   ```
3. **Show the test that will catch the bug.** Open `test/pulse_analysis_test.dart`:

   ```dart
   // 20 seconds of fake camera readings, 30 per second, like a real phone camera.
   final timestamps = List<double>.generate(600, (i) => i * 1000 / 30);
   
   test('detects about 72 BPM from a synthetic 1.2 Hz pulse', () {
     // A perfect fake pulse: a wave that rises and falls 1.2 times every second.
     // 1.2 beats per second x 60 seconds = 72 beats per minute.
     final values = [
       for (final t in timestamps) 180 + 2 * math.sin(2 * math.pi * 1.2 * t / 1000),
     ];
   
     // Run the app's real heart-rate code on the fake pulse.
     final result = calculateBpm(timestamps, values);
   
     // We know the right answer, so check it: a pulse is found, and it is 72 give or take 3.
     expect(result.status, PulseStatus.ok);
     expect(result.bpm, closeTo(72, 3));
   });
   ```

   Because the test builds its own input, the correct answer is known to be 72. If the code ever returns anything else, the code is wrong.
4. **Make the mistake live.**

   ```
   # Switch to main and download the latest code
   git checkout main
   git pull
   
   # Create a new branch for this change and switch to it
   git checkout -b demo/ci-bug
   ```

   In `lib/pulse_analysis.dart`, find `final bpm = 60000 / medianInterval;` and change `60000` to `120000`. 60,000 is the number of milliseconds in a minute, and dividing it by the time between beats gives beats per minute. With 120,000, a 72 BPM pulse would be reported as 144 BPM.

   ```
   # Stage the changed file, so Git includes it in the next commit
   git add lib/pulse_analysis.dart
   
   # Save the change as a commit (the developer "forgot" to run the tests first)
   git commit -m "Simplify BPM calculation"
   
   # Upload the branch to GitHub
   git push -u origin demo/ci-bug
   ```
5. **Open the pull request.**

   ```
   # Ask GitHub to merge this branch into main (this starts CI)
   gh pr create --base main --head demo/ci-bug --title "Simplify BPM calculation" --body "Small refactor of the BPM formula."
   
   # Open the new pull request in the browser
   gh pr view demo/ci-bug --web
   ```
6. **Watch CI run (about 2 minutes).** Open the running check and walk through the steps: a fresh Linux machine checks out the code, installs Flutter, runs static analysis, then the unit tests.
7. **Show the failure.** The check turns red at **Unit tests**. Expand the step and point to:

   ```
   Expected: a numeric value within <3> of <72>
     Actual: <144.0>
   ```

   The change looks harmless, but the test knows the right answer is 72, and the code now returns 144.
8. **Show the block.** Back on the pull request, the merge box says checks failed and merging is blocked.
9. **Show what the developer should have done.** On the laptop:

   ```
   # Run the same tests locally: the same failure appears in seconds
   flutter test
   ```
10. **Fix it.** In `lib/pulse_analysis.dart`, change `120000` back to `60000`, then:

    ```
    # Run the tests again: they pass now, so it is safe to commit
    flutter test
    
    # Stage the fixed file
    git add lib/pulse_analysis.dart
    
    # Save the fix as a new commit
    git commit -m "Fix BPM formula"
    
    # Upload the fix; GitHub re-runs CI on the open pull request automatically
    git push
    ```
11. **Show the re-run.** After about 5 minutes (the APK build is included), the check is green and **Merge pull request** is enabled.
12. **Close without merging.** In real work the pull request would be merged at this point; in the demo it is closed so that main stays unchanged.

    ```
    # Close the pull request without merging, leaving main unchanged
    gh pr close demo/ci-bug --comment "Demo only"
    
    # Go back to main, ready for the next demo
    git checkout main
    ```

## Demo 2: CD from merge to phone

You change the app's background colour live, merge it, and the pipeline delivers a signed build to the phone through App Tester with no manual build or upload.

**Information: CD in plain words**

Once a change is approved, nobody builds the app, signs it or sends it out by hand. When the change is merged, the pipeline checks everything again, packages the app, signs it with the official key so phones trust it, and sends it straight to testers' phones. It takes about seven minutes from the merge to a new version on a tester's phone, and it is done the same way every time, so there is no "it worked on my machine". Releasing to the public remains a separate, deliberate decision.

1. **Show the starting point.** In the scrcpy window, open Pulse Check and point out the white background and the version line at the bottom.
2. **Make the change live.**

   ```
   # Switch to main and download the latest code
   git checkout main
   git pull
   
   # Create a new branch for this change and switch to it
   git checkout -b demo/cd-change
   ```

   In `lib/main.dart`, find the line that starts with `theme: ThemeData(` and add a background colour inside the brackets, so it reads:

   ```dart
   theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true, scaffoldBackgroundColor: Colors.amber.shade100),
   ```

   Keep whatever was already inside the brackets; only `scaffoldBackgroundColor: Colors.amber.shade100` is new. Every screen's background turns light yellow.

   ```
   # Good practice: check and test locally before committing
   flutter analyze
   flutter test
   
   # Stage the changed file
   git add lib/main.dart
   
   # Save the change as a commit
   git commit -m "Change background colour"
   
   # Upload the branch to GitHub
   git push -u origin demo/cd-change
   ```
3. **Open the pull request.**

   ```
   # Ask GitHub to merge this branch into main (this starts CI)
   gh pr create --base main --head demo/cd-change --title "Change background colour" --body "Visual tweak for the demo."
   
   # Open the new pull request in the browser
   gh pr view demo/cd-change --web
   ```
4. **Merge once CI is green (about 5 minutes).** Click **Merge pull request**, then **Confirm merge**.
5. **Follow the deploy (about 7 minutes).** Open Actions → **Deploy to Firebase**. The steps, in order: analysis and tests run again on `main`; the signing key is rebuilt from GitHub Secrets; a signed release APK is built; a service account uploads it to Firebase. No one, including the repository owner, handles the signing key or the upload by hand.
6. **Update the phone.** When the run is green, open App Tester in the scrcpy window, pull down to refresh, and tap **Update** on the newest build. It installs over the existing app without an uninstall, because every pipeline build uses the same signing key.
7. **Show the result.** Open Pulse Check: the background is now light yellow and the build number has gone up.
8. **Tidy up the laptop.**

   ```
   # Go back to main and download the merged change
   git checkout main
   git pull
   ```

## Reset after a rehearsal

After each run, undo Demo 2's merge and delete the two demo branches, so the next run can create them fresh with the same names.

1. **Undo the background change.** On the merged Demo 2 pull request, click **Revert**, then **Create pull request**, wait for CI, and merge. Deploy to Firebase delivers the original white background again. (This doubles as practice for a rollback demo.)
2. **Update your laptop and delete the demo branches.**

   ```
   # Switch to the main branch
   git checkout main
   
   # Download the latest main, including the revert
   git pull
   
   # Delete both demo branches on this laptop
   git branch -D demo/ci-bug demo/cd-change
   
   # Delete both demo branches on GitHub
   git push origin --delete demo/ci-bug demo/cd-change
   ```
3. **Update the phone** to the newest App Tester build.

## Troubleshooting and fallback

Most demo problems are GitHub or Firebase delays, not your code; re-run, and use a previous successful run to show the steps while you wait.

| Problem | What to do |
| --- | --- |
| CI or deploy stays queued for minutes | Check githubstatus.com; meanwhile walk through the steps of an earlier green run |
| A step fails with HTTP 500, timeout or "Too many retries" | Temporary server error: **Re-run jobs → Re-run failed jobs** |
| Merge button is not blocked in Demo 1 | Your account is on the ruleset's bypass list; remove it in Settings → Rules |
| Demo 1 fails at a step other than Unit tests | Check the edit for a typo (run `flutter analyze` locally); make sure you ran `git pull` on `main` before creating the branch |
| `git checkout -b` says the branch already exists | A previous run wasn't reset; do the Reset steps, or use a new name such as `demo/ci-bug-2` |
| scrcpy says no device found | Unlock the phone, accept the USB debugging prompt, try another USB cable or port |
| App Tester shows no new build | Pull down to refresh; confirm the release in Firebase → App Distribution; use the link in the Firebase email |
| Phone asks to uninstall before updating | A PR or `flutter run` build is installed; before the interview, reinstall the latest build from App Tester |
| No internet or GitHub is down | Switch to the fallback below |

**Fallback:** during the rehearsal, take a screenshot at each stage: the red test log, the blocked merge box, the green check, the deploy run, App Tester showing the update, and the yellow background. Keep the links to those runs bookmarked; Actions keeps run logs for 90 days.
