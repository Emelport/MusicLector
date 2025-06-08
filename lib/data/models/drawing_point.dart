import 'package:flutter/material.dart';

enum DrawingMode {
  pen,
  highlighter,
  eraser,
}

class DrawingPoint {
  final Offset relativePoint; // x,y en rango 0..1
  final Paint paint;
  final DateTime time;

  DrawingPoint({
    required this.relativePoint,
    required this.paint,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (drawingPoints.isEmpty) return;

    // Agrupa los puntos por trazos continuos
    List<List<DrawingPoint>> strokes = [];
    List<DrawingPoint> currentStroke = [];

    for (int i = 0; i < drawingPoints.length; i++) {
      if (i == 0 || drawingPoints[i].time.difference(drawingPoints[i-1].time).inMilliseconds > 100) {
        if (currentStroke.isNotEmpty) {
          strokes.add(List.from(currentStroke));
          currentStroke.clear();
        }
      }
      currentStroke.add(drawingPoints[i]);
    }
    if (currentStroke.isNotEmpty) {
      strokes.add(currentStroke);
    }

    // Dibuja cada trazo
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      final path = Path();
      final firstPoint = stroke.first;
      path.moveTo(
        firstPoint.relativePoint.dx * size.width,
        firstPoint.relativePoint.dy * size.height,
      );

      for (int i = 1; i < stroke.length; i++) {
        final point = stroke[i];
        path.lineTo(
          point.relativePoint.dx * size.width,
          point.relativePoint.dy * size.height,
        );
      }

      canvas.drawPath(path, stroke.first.paint);

      // Dibuja un círculo en el último punto para mejor apariencia
      if (stroke.length == 1) {
        canvas.drawCircle(
          Offset(
            stroke.first.relativePoint.dx * size.width,
            stroke.first.relativePoint.dy * size.height,
          ),
          stroke.first.paint.strokeWidth / 2,
          stroke.first.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}