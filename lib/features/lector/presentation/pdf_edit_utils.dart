
import 'package:flutter/material.dart';

enum DrawingMode {
  pen,
  highlighter,
}

class DrawingPointRelative {
  final Offset relativePoint; // x,y in 0..1 range
  final Paint paint;
  final DateTime time;

  DrawingPointRelative({
    required this.relativePoint,
    required this.paint,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class DrawingPainterRelative extends CustomPainter {
  final List<DrawingPointRelative> drawingPoints;

  DrawingPainterRelative({required this.drawingPoints});

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

   Offset transformToImageCoords(Offset local, double widgetW, double widgetH) {
    const imgW = 1000.0;
    const imgH = 1400.0;
    final widgetAspect = widgetW / widgetH;
    final imgAspect = imgW / imgH;

    double scale, dx = 0, dy = 0;
    if (widgetAspect > imgAspect) {
      // Horizontal letterbox
      scale = widgetH / imgH;
      dx = (widgetW - imgW * scale) / 2;
    } else {
      // Vertical letterbox
      scale = widgetW / imgW;
      dy = (widgetH - imgH * scale) / 2;
    }
    final x = ((local.dx - dx) / (imgW * scale)).clamp(0.0, 1.0);
    final y = ((local.dy - dy) / (imgH * scale)).clamp(0.0, 1.0);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  
}