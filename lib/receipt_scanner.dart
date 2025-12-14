
import 'dart:developer' as developer;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:edge_detection/edge_detection.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiptScanner extends StatefulWidget {
  const ReceiptScanner({super.key});

  @override
  State<ReceiptScanner> createState() => _ReceiptScannerState();
}

class _ReceiptScannerState extends State<ReceiptScanner> {
  CameraController? _cameraController;
  late TextRecognizer _textRecognizer;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    _initializeCamera();
    _textRecognizer = GoogleMlKit.vision.textRecognizer();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera].request();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _scanForReceipt() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final imagePath = p.join(
        (await getTemporaryDirectory()).path,
        '${DateTime.now()}.png',
      );

      final image = await _cameraController!.takePicture();
      await image.saveTo(imagePath);

      if (!mounted) return;

      bool success = await EdgeDetection.detectEdge(
        imagePath,
        canUseGallery: false,
      );

      if (success) {
        setState(() {
          _imagePath = imagePath;
        });
      }
    } catch (e) {
      developer.log('Error scanning for receipt: $e');
    }
  }

  Future<void> _processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    developer.log('Recognized text: ${recognizedText.text}');
    if (!mounted) return;
    Navigator.pop(context, recognizedText.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: _imagePath != null
          ? Column(
              children: [
                Expanded(child: Image.file(File(_imagePath!))),
                ElevatedButton(
                  onPressed: () => _processImage(_imagePath!),
                  child: const Text('Use this image'),
                ),
              ],
            )
          : _cameraController == null || !_cameraController!.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : CameraPreview(_cameraController!),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanForReceipt,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
