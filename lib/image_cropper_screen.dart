import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageCropperScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset> detectedCorners;

  const ImageCropperScreen({
    super.key,
    required this.imagePath,
    required this.detectedCorners,
  });

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  late List<Offset> corners;
  int? selectedCorner;
  ui.Image? image;
  bool isLoading = true;
  double imageScale = 1.0;
  Offset imageOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    corners = List.from(widget.detectedCorners);
    _loadImage();
  }

  Future<void> _loadImage() async {
    final file = File(widget.imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      image = frame.image;
      isLoading = false;
    });
  }

  void _updateCorner(Offset localPosition, Size displaySize) {
    if (selectedCorner == null || image == null) return;

    // Convert display coordinates to image coordinates
    final scaleX = image!.width / displaySize.width;
    final scaleY = image!.height / displaySize.height;

    setState(() {
      corners[selectedCorner!] = Offset(
        localPosition.dx.clamp(0, displaySize.width) * scaleX,
        localPosition.dy.clamp(0, displaySize.height) * scaleY,
      );
    });
  }

  Future<void> _cropAndSave() async {
    if (image == null) return;

    try {
      // Create a new canvas for the cropped image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Calculate the bounding rectangle
      final sortedX = corners.map((c) => c.dx).toList()..sort();
      final sortedY = corners.map((c) => c.dy).toList()..sort();

      final minX = sortedX.first;
      final maxX = sortedX.last;
      final minY = sortedY.first;
      final maxY = sortedY.last;

      final width = maxX - minX;
      final height = maxY - minY;

      // Apply perspective transform (simplified approach)
      canvas.save();
      canvas.translate(-minX, -minY);

      // Draw the image
      canvas.drawImage(image!, Offset.zero, Paint());
      canvas.restore();

      // Convert to image
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(width.toInt(), height.toInt());

      // Save to file
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to convert image');

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final croppedPath = p.join(
        tempDir.path,
        'cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      final file = File(croppedPath);
      await file.writeAsBytes(buffer);

      if (mounted) {
        Navigator.pop(context, croppedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crop failed: $e')),
        );
      }
    }
  }

  void _autoDetect() {
    // Reset to automatic detection
    setState(() {
      corners = List.from(widget.detectedCorners);
    });
  }

  void _skipCrop() {
    Navigator.pop(context, widget.imagePath);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || image == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust Corners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _autoDetect,
            tooltip: 'Auto-detect',
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: _skipCrop,
            tooltip: 'Skip crop',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final displayWidth = constraints.maxWidth;
                final displayHeight = constraints.maxHeight;
                final imageAspectRatio = image!.width / image!.height;
                final displayAspectRatio = displayWidth / displayHeight;

                Size displaySize;
                if (imageAspectRatio > displayAspectRatio) {
                  displaySize = Size(displayWidth, displayWidth / imageAspectRatio);
                } else {
                  displaySize = Size(displayHeight * imageAspectRatio, displayHeight);
                }

                final scaleX = displaySize.width / image!.width;
                final scaleY = displaySize.height / image!.height;

                return Center(
                  child: SizedBox(
                    width: displaySize.width,
                    height: displaySize.height,
                    child: GestureDetector(
                      onPanStart: (details) {
                        final localPos = details.localPosition;
                        // Find the nearest corner
                        double minDistance = double.infinity;
                        int? nearestCorner;

                        for (int i = 0; i < corners.length; i++) {
                          final cornerDisplay = Offset(
                            corners[i].dx * scaleX,
                            corners[i].dy * scaleY,
                          );
                          final distance = (cornerDisplay - localPos).distance;
                          if (distance < minDistance && distance < 50) {
                            minDistance = distance;
                            nearestCorner = i;
                          }
                        }
                        setState(() {
                          selectedCorner = nearestCorner;
                        });
                      },
                      onPanUpdate: (details) {
                        _updateCorner(details.localPosition, displaySize);
                      },
                      onPanEnd: (details) {
                        setState(() {
                          selectedCorner = null;
                        });
                      },
                      child: CustomPaint(
                        painter: CropOverlayPainter(
                          image: image!,
                          corners: corners,
                          selectedCorner: selectedCorner,
                          scaleX: scaleX,
                          scaleY: scaleY,
                        ),
                        size: displaySize,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                const Text(
                  'Drag corners to adjust crop area',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cropAndSave,
                    icon: const Icon(Icons.crop),
                    label: const Text('Crop & Continue'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> corners;
  final int? selectedCorner;
  final double scaleX;
  final double scaleY;

  CropOverlayPainter({
    required this.image,
    required this.corners,
    required this.selectedCorner,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image
    final paint = Paint();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Draw semi-transparent overlay outside the crop area
    final path = Path();
    final displayCorners = corners.map((c) => Offset(c.dx * scaleX, c.dy * scaleY)).toList();

    path.moveTo(displayCorners[0].dx, displayCorners[0].dy);
    for (int i = 1; i < displayCorners.length; i++) {
      path.lineTo(displayCorners[i].dx, displayCorners[i].dy);
    }
    path.close();

    final overlayPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.clipPath(path, clipOp: ui.ClipOp.difference);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    canvas.restore();

    // Draw crop area border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < displayCorners.length; i++) {
      final start = displayCorners[i];
      final end = displayCorners[(i + 1) % displayCorners.length];
      canvas.drawLine(start, end, borderPaint);
    }

    // Draw corner handles
    for (int i = 0; i < displayCorners.length; i++) {
      final isSelected = i == selectedCorner;
      final cornerPaint = Paint()
        ..color = isSelected ? Colors.blue : Colors.white
        ..style = PaintingStyle.fill;

      final outerPaint = Paint()
        ..color = isSelected ? Colors.blue : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(displayCorners[i], isSelected ? 15 : 12, cornerPaint);
      canvas.drawCircle(displayCorners[i], isSelected ? 18 : 15, outerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.selectedCorner != selectedCorner;
  }
}
