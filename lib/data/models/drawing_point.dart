import 'package:flutter/material.dart';

class DrawingPoint {
  final Offset relativePoint; // x,y in 0..1 range
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
    
    Path path = Path();
    bool isFirst = true;
    
    for (int i = 0; i < drawingPoints.length; i++) {
      final point = drawingPoints[i];
      final offset = Offset(
        point.relativePoint.dx * size.width,
        point.relativePoint.dy * size.height,
      );
      
      if (isFirst) {
        path.moveTo(offset.dx, offset.dy);
        isFirst = false;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      
      // Draw the point itself
      canvas.drawCircle(offset, point.paint.strokeWidth / 2, point.paint);
    }
    
    // Draw the connecting lines
    canvas.drawPath(path, drawingPoints.first.paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}