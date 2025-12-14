import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'edge_detector.dart';
import 'image_cropper_screen.dart';

class EnhancedScanner extends StatefulWidget {
  const EnhancedScanner({super.key});

  @override
  State<EnhancedScanner> createState() => _EnhancedScannerState();
}

class _EnhancedScannerState extends State<EnhancedScanner> {
  CameraController? _cameraController;
  late TextRecognizer _textRecognizer;
  final List<ScannedPage> _scannedPages = [];
  int _currentPageIndex = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    _initializeCamera();
    _textRecognizer = TextRecognizer();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.storage].request();
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

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final imagePath = p.join(
        (await getTemporaryDirectory()).path,
        'scan_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final image = await _cameraController!.takePicture();
      await image.saveTo(imagePath);

      if (!mounted) return;

      // Detect edges
      final detectedCorners = await EdgeDetector.detectEdges(imagePath);

      if (!mounted) return;

      // Navigate to crop screen
      final croppedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(
            imagePath: imagePath,
            detectedCorners: detectedCorners,
          ),
        ),
      );

      if (croppedPath != null && mounted) {
        await _processImage(croppedPath);
      }
    } catch (e) {
      developer.log('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isProcessing = true);

      try {
        final detectedCorners = await EdgeDetector.detectEdges(image.path);

        if (!mounted) return;

        final croppedPath = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => ImageCropperScreen(
              imagePath: image.path,
              detectedCorners: detectedCorners,
            ),
          ),
        );

        if (croppedPath != null && mounted) {
          await _processImage(croppedPath);
        }
      } catch (e) {
        developer.log('Error processing gallery image: $e');
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      developer.log('Recognized text: ${recognizedText.text}');

      if (mounted) {
        setState(() {
          _scannedPages.add(ScannedPage(
            imagePath: imagePath,
            text: recognizedText.text,
            timestamp: DateTime.now(),
          ));
          _currentPageIndex = _scannedPages.length - 1;
        });
      }
    } catch (e) {
      developer.log('Error processing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
        );
      }
    }
  }

  void _deletePage(int index) {
    setState(() {
      _scannedPages.removeAt(index);
      if (_currentPageIndex >= _scannedPages.length && _scannedPages.isNotEmpty) {
        _currentPageIndex = _scannedPages.length - 1;
      }
    });
  }

  void _finishScanning() {
    if (_scannedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages scanned yet')),
      );
      return;
    }

    final allText = _scannedPages.map((page) => page.text).join('\n\n--- Page Break ---\n\n');
    Navigator.pop(context, allText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scannedPages.isEmpty
            ? 'Scan Document'
            : 'Pages: ${_scannedPages.length}'),
        actions: [
          if (_scannedPages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _finishScanning,
              tooltip: 'Finish',
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
          : _scannedPages.isEmpty
              ? _buildCameraView()
              : _buildPageView(),
      floatingActionButton: _scannedPages.isEmpty
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'gallery',
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'camera',
                  onPressed: _isProcessing ? null : _captureAndProcess,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _captureAndProcess,
              label: const Text('Add Page'),
              icon: const Icon(Icons.add_a_photo),
            ),
    );
  }

  Widget _buildCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: EdgeOverlayPainter(),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Position document within the frame',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageView() {
    final currentPage = _scannedPages[_currentPageIndex];

    return Column(
      children: [
        // Page navigation
        if (_scannedPages.length > 1)
          Container(
            height: 80,
            color: Colors.grey[200],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _scannedPages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => setState(() => _currentPageIndex = index),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: index == _currentPageIndex
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        width: index == _currentPageIndex ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(_scannedPages[index].imagePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        // Current page view
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.file(File(currentPage.imagePath)),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Text:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        currentPage.text.isEmpty
                            ? 'No text detected'
                            : currentPage.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Action buttons
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => _deletePage(_currentPageIndex),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
              TextButton.icon(
                onPressed: () {
                  // Copy text to clipboard
                  // Clipboard.setData(ClipboardData(text: currentPage.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Text copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ScannedPage {
  final String imagePath;
  final String text;
  final DateTime timestamp;

  ScannedPage({
    required this.imagePath,
    required this.text,
    required this.timestamp,
  });
}

class EdgeOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.1,
      size.width * 0.9,
      size.height * 0.7,
    );

    // Draw corner markers
    final cornerLength = 30.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final corner in corners) {
      // Horizontal line
      canvas.drawLine(
        corner,
        Offset(
          corner.dx + (corner.dx == rect.left ? cornerLength : -cornerLength),
          corner.dy,
        ),
        paint..strokeWidth = 3,
      );
      // Vertical line
      canvas.drawLine(
        corner,
        Offset(
          corner.dx,
          corner.dy + (corner.dy == rect.top ? cornerLength : -cornerLength),
        ),
        paint..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
