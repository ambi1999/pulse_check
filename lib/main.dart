import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'measure_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Errors inside Flutter (e.g. while building a screen) go to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Any other uncaught errors (e.g. in async code) go to Crashlytics too.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const PulseCheckApp());
}

class PulseCheckApp extends StatelessWidget {
  const PulseCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse Check',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const MeasureScreen(),
    );
  }
}
