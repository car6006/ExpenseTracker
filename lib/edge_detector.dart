import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';

class EdgeDetector {
  static Future<List<Offset>> detectEdges(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);

      // Simple edge detection: return corners based on image dimensions
      // In a production app, you'd use OpenCV or similar for actual edge detection
      final width = image.width.toDouble();
      final height = image.height.toDouble();

      // Return corners with slight padding
      return [
        Offset(width * 0.05, height * 0.05), // Top-left
        Offset(width * 0.95, height * 0.05), // Top-right
        Offset(width * 0.95, height * 0.95), // Bottom-right
        Offset(width * 0.05, height * 0.95), // Bottom-left
      ];
    } catch (e) {
      // Fallback to default corners
      return [
        const Offset(0, 0),
        const Offset(1000, 0),
        const Offset(1000, 1000),
        const Offset(0, 1000),
      ];
    }
  }

  static Future<ui.Image> decodeImageFromList(List<int> bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // Helper method to calculate distance between two points
  static double distance(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
  }

  // Order points: top-left, top-right, bottom-right, bottom-left
  static List<Offset> orderPoints(List<Offset> points) {
    if (points.length != 4) return points;

    // Sort by y-coordinate
    final sorted = List<Offset>.from(points)..sort((a, b) => a.dy.compareTo(b.dy));

    // Top two points
    final topPoints = sorted.sublist(0, 2)..sort((a, b) => a.dx.compareTo(b.dx));
    // Bottom two points
    final bottomPoints = sorted.sublist(2, 4)..sort((a, b) => a.dx.compareTo(b.dx));

    return [
      topPoints[0], // top-left
      topPoints[1], // top-right
      bottomPoints[1], // bottom-right
      bottomPoints[0], // bottom-left
    ];
  }
}
