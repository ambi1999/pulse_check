import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'pulse_analysis.dart';
import 'wave_painter.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  static const _measureSeconds = 20;

  CameraController? _controller;
  final _stopwatch = Stopwatch();
  final List<double> _timestampsMs = [];
  final List<double> _values = [];
  Timer? _timer;
  bool _measuring = false;
  int _secondsLeft = _measureSeconds;
  PulseResult? _result;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startMeasurement() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found on this device.');
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low, // we only need average brightness
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize(); // asks for camera permission
      await controller.setFlashMode(FlashMode.torch);

      _timestampsMs.clear();
      _values.clear();
      _stopwatch
        ..reset()
        ..start();
      setState(() {
        _measuring = true;
        _secondsLeft = _measureSeconds;
      });

      await controller.startImageStream(_onFrame);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = _measureSeconds - _stopwatch.elapsed.inSeconds;
        if (left <= 0) {
          _finishMeasurement();
        } else if (mounted) {
          setState(() => _secondsLeft = left);
        }
      });
    } on CameraException catch (e) {
      await _showStartError(
        e.code == 'CameraAccessDenied'
            ? 'Camera permission is needed to measure.'
            : 'Camera error: ${e.description ?? e.code}',
      );
    } on Exception catch (e) {
      await _showStartError('Could not start the camera: $e');
    }
  }

  Future<void> _showStartError(String message) async {
    _timer?.cancel();
    _measuring = false;
    await _stopCamera();
    if (!mounted) {
      return;
    }
    setState(() => _error = message);
  }

  void _onFrame(CameraImage image) {
    if (!_measuring) {
      return;
    }
    _timestampsMs.add(_stopwatch.elapsedMicroseconds / 1000);
    _values.add(_averageRed(image));
    if (mounted) {
      setState(() {}); // redraw the live wave
    }
  }

  /// Average red level of a YUV420 frame, sampled on a sparse grid.
  /// Red is approximately Y + 1.402 * (V - 128).
  double _averageRed(CameraImage image) {
    const step = 8;
    final yPlane = image.planes[0];
    final vPlane = image.planes.length > 2 ? image.planes[2] : null;
    var sumY = 0.0;
    var sumV = 0.0;
    var count = 0;
    for (var row = 0; row < image.height; row += step) {
      for (var col = 0; col < image.width; col += step) {
        sumY += yPlane.bytes[row * yPlane.bytesPerRow + col];
        if (vPlane != null) {
          final vIndex = (row ~/ 2) * vPlane.bytesPerRow +
              (col ~/ 2) * (vPlane.bytesPerPixel ?? 1);
          sumV += vIndex < vPlane.bytes.length ? vPlane.bytes[vIndex] : 128;
        } else {
          sumV += 128;
        }
        count++;
      }
    }
    if (count == 0) {
      return 0;
    }
    return sumY / count + 1.402 * (sumV / count - 128);
  }

  Future<void> _finishMeasurement() async {
    _timer?.cancel();
    _stopwatch.stop();
    _measuring = false;
    await _stopCamera();
    if (!mounted) {
      return;
    }
    setState(() {
      _result = calculateBpm(_timestampsMs, _values);
    });
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) {
      return;
    }
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.setFlashMode(FlashMode.off);
    } on CameraException {
      // Ignore: we are shutting the camera down anyway.
    }
    await controller.dispose();
  }

  String get _statusText {
    if (_error != null) {
      return _error!;
    }
    if (_measuring) {
      return 'Keep still... $_secondsLeft s';
    }
    final result = _result;
    if (result == null) {
      return 'Cover the rear camera and flash with your fingertip, then tap Measure.';
    }
    if (result.status == PulseStatus.ok) {
      return '${result.bpm!.round()} BPM';
    }
    return "Couldn't detect pulse, try again.";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Pulse Check')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: CustomPaint(
                  painter: WavePainter(waveForDisplay(_values), colors.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: _result?.status == PulseStatus.ok && !_measuring
                    ? Theme.of(context).textTheme.displayMedium
                    : Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (_measuring &&
                  controller != null &&
                  controller.value.isInitialized)
                Center(
                  // A small preview keeps the camera pipeline running and
                  // lets the user check their finger covers the lens.
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipOval(child: CameraPreview(controller)),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _measuring ? null : _startMeasurement,
                child: Text(_measuring ? 'Measuring...' : 'Measure'),
              ),
              const SizedBox(height: 12),
              Text(
                'For demo purposes only, not a medical device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
