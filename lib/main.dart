import 'package:flutter/material.dart';

import 'measure_screen.dart';

void main() => runApp(const PulseCheckApp());

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
