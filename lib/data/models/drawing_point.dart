import 'package:flutter/material.dart';

class DrawingRect {
  final Offset start; // relativo 0..1
  final Offset end; // relativo 0..1
  final Paint paint;
  DrawingRect({required this.start, required this.end, required this.paint});

  Map<String, dynamic> toJson() => {
        'start': {'dx': start.dx, 'dy': start.dy},
        'end': {'dx': end.dx, 'dy': end.dy},
        'color': paint.color.value,
        'strokeWidth': paint.strokeWidth,
      };

  factory DrawingRect.fromJson(Map<String, dynamic> json) => DrawingRect(
        start: Offset(
          (json['start']['dx'] as num).toDouble(),
          (json['start']['dy'] as num).toDouble(),
        ),
        end: Offset(
          (json['end']['dx'] as num).toDouble(),
          (json['end']['dy'] as num).toDouble(),
        ),
        paint: Paint()
          ..color = Color(json['color'])
          ..strokeWidth = (json['strokeWidth'] as num).toDouble()
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true,
      );
}

class DrawingPainter extends CustomPainter {
  final List<DrawingRect> rects;
  DrawingPainter({required this.rects});

  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in rects) {
      final r = Rect.fromPoints(
        Offset(rect.start.dx * size.width, rect.start.dy * size.height),
        Offset(rect.end.dx * size.width, rect.end.dy * size.height),
      );
      final fillPaint = Paint()
        ..color = rect.paint.color.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(r, fillPaint);
      canvas.drawRect(r, rect.paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
