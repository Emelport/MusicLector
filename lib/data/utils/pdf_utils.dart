import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Enumeración para los modos de dibujo
enum DrawingMode { pen, highlighter }

/// Modelo para puntos de dibujo
class DrawingPoint {
  final List<Offset> points;
  final Paint paint;
  final DateTime time;

  DrawingPoint({
    required this.points,
    required this.paint,
    required this.time,
  });
}

/// Renderiza una página PDF a imagen
Future<Uint8List?> renderPdfPageToImage(PdfPage page, {int width = 1000, int height = 1400}) async {
  try {
    final image = await page.render(width: width, height: height);
    return image?.bytes;
  } catch (e) {
    debugPrint('Error al renderizar página PDF: $e');
    return null;
  }
}

/// Guarda el dibujo como imagen combinando fondo y anotaciones
Future<Uint8List?> saveDrawingAsImage({
  required Uint8List backgroundImageBytes,
  required List<DrawingPoint> drawingPoints,
  int width = 1000,
  int height = 1400,
}) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    
    // Dibujar la imagen de fondo
    final bgImage = await decodeImageFromList(backgroundImageBytes);
    canvas.drawImageRect(
      bgImage, 
      Rect.fromLTWH(0, 0, bgImage.width.toDouble(), bgImage.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
    );
    
    // Dibujar las anotaciones
    final painter = DrawingPainter(drawingPoints: drawingPoints);
    painter.paint(canvas, size);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Error al guardar el dibujo: $e');
    return null;
  }
}

/// Crea un Paint configurado según el modo de dibujo
Paint createDrawingPaint({
  required Color color,
  required double strokeWidth,
  required DrawingMode mode,
}) {
  return Paint()
    ..color = mode == DrawingMode.highlighter ? color.withOpacity(0.4) : color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
}

/// Painter para dibujar las anotaciones
class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (final drawingPoint in drawingPoints) {
      final points = drawingPoint.points;
      if (points.length > 1) {
        for (int i = 0; i < points.length - 1; i++) {
          canvas.drawLine(
            points[i],
            points[i + 1],
            drawingPoint.paint,
          );
        }
      } else if (points.length == 1) {
        canvas.drawPoints(
          ui.PointMode.points,
          [points.first],
          drawingPoint.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Crea un botón de herramienta estilizado
Widget buildToolButton({
  required IconData icon,
  required bool isSelected,
  required VoidCallback onPressed,
  Color? selectedColor,
  Color? unselectedColor,
}) {
  return IconButton(
    icon: Icon(icon),
    color: isSelected 
      ? selectedColor ?? Colors.blue[900] 
      : unselectedColor ?? Colors.grey,
    onPressed: onPressed,
  );
}

/// Widget para selector de colores
Widget buildColorPicker({
  required Color selectedColor,
  required ValueChanged<Color> onColorSelected,
  List<Color> colors = const [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.black,
    Colors.purple,
  ],
}) {
  return SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      shrinkWrap: true,
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            margin: const EdgeInsets.all(4),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selectedColor == color ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}