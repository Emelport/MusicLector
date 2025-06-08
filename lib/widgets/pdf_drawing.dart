import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:music_lector/data/models/drawing_model.dart';


class PDFDrawingLayer extends StatefulWidget {
  final Uint8List pdfImage;
  final List<DrawingStroke> strokes;
  final Function(List<DrawingStroke>) onStrokesUpdated;
  final Color strokeColor;
  final double strokeWidth;

  const PDFDrawingLayer({
    super.key,
    required this.pdfImage,
    required this.strokes,
    required this.onStrokesUpdated,
    this.strokeColor = Colors.red,
    this.strokeWidth = 3.0,
  });

  @override
  State<PDFDrawingLayer> createState() => _PDFDrawingLayerState();
}

class _PDFDrawingLayerState extends State<PDFDrawingLayer> {
  DrawingStroke? _currentStroke;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: CustomPaint(
        size: Size.infinite,
        painter: PDFDrawingPainter(
          pdfImage: widget.pdfImage,
          strokes: widget.strokes,
          currentStroke: _currentStroke,
        ),
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [details.localPosition],
        color: widget.strokeColor,
        width: widget.strokeWidth,
      );
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke?.points.add(details.localPosition);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      if (_currentStroke != null) {
        widget.onStrokesUpdated([...widget.strokes, _currentStroke!]);
        _currentStroke = null;
      }
    });
  }
}

class PDFDrawingPainter extends CustomPainter {
  final Uint8List pdfImage;
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;

  PDFDrawingPainter({
    required this.pdfImage,
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) async {
    final bgImage = await bytesToImage(pdfImage);
    canvas.drawImageRect(
      bgImage,
      Rect.fromLTWH(0, 0, bgImage.width.toDouble(), bgImage.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (stroke.points.isNotEmpty) {
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PDFDrawingPainter oldDelegate) {
    return oldDelegate.pdfImage != pdfImage ||
        oldDelegate.strokes.length != strokes.length ||
        oldDelegate.currentStroke != currentStroke;
  }
}