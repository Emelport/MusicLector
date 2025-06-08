import 'package:flutter/material.dart';
import 'package:music_lector/data/models/drawing_point.dart';
import 'package:music_lector/data/models/pdf_documents.dart';

class PdfPageView extends StatelessWidget {
  final PdfDocumentModel documentModel;
  final bool isEditing;

  const PdfPageView({
    super.key,
    required this.documentModel,
    required this.isEditing,
  });

 @override
Widget build(BuildContext context) {
  final orientation = MediaQuery.of(context).orientation;
  final isPortrait = orientation == Orientation.portrait;
  final screenSize = MediaQuery.of(context).size;

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (details) => _handleTapDown(details, screenSize),
    onVerticalDragEnd: (details) => _handleVerticalDragEnd(details),
    child: Center(
      child: isPortrait
          ? _buildPortraitView(context)
          : _buildLandscapeView(),
    ),
  );
}

void _handleTapDown(TapDownDetails details, Size screenSize) {
  if (isEditing) return;
  
  final dx = details.localPosition.dx;
  final width = screenSize.width;

  if (dx > width * 0.7) { // Toque en el 30% derecho
    documentModel.nextPage();
  } else if (dx < width * 0.3) { // Toque en el 30% izquierdo
    documentModel.previousPage();
  } else { // Toque en el 40% central
    documentModel.toggleSlider(!documentModel.stateNotifier.value.showSlider);
  }
}

void _handleVerticalDragEnd(DragEndDetails details) {
  if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
    documentModel.toggleSlider(false);
  }
}


  Widget _buildPortraitView(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: isEditing
          ? _buildEditablePage(context)
          : Image.memory(
              documentModel.editedImageBytes ?? documentModel.leftImageBytes!,
              fit: BoxFit.contain,
            ),
    );
  }

  Widget _buildEditablePage(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth;
        final imageHeight = constraints.maxHeight;
        
        return GestureDetector(
          onPanStart: (details) => _handlePanStart(details, imageWidth, imageHeight),
          onPanUpdate: (details) => _handlePanUpdate(details, imageWidth, imageHeight),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(documentModel.leftImageBytes!, fit: BoxFit.contain),
              CustomPaint(
                painter: DrawingPainter(
                  drawingPoints: documentModel.stateNotifier.value.drawingPoints,
                ),
                size: Size(imageWidth, imageHeight),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handlePanStart(DragStartDetails details, double width, double height) {
    final local = _transformToImageCoords(details.localPosition, width, height);
    documentModel.addDrawingPoint(DrawingPoint(
      relativePoint: local,
      paint: Paint()
        ..color = documentModel.selectedColor
        ..strokeWidth = documentModel.strokeWidth / width * 1000
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    ));
  }

  void _handlePanUpdate(DragUpdateDetails details, double width, double height) {
    final local = _transformToImageCoords(details.localPosition, width, height);
    documentModel.addDrawingPoint(DrawingPoint(
      relativePoint: local,
      paint: Paint()
        ..color = documentModel.selectedColor
        ..strokeWidth = documentModel.strokeWidth / width * 1000
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    ));
  }

  Offset _transformToImageCoords(Offset local, double widgetW, double widgetH) {
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

  Widget _buildLandscapeView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1000 / 1400,
          child: Image.memory(documentModel.leftImageBytes!, fit: BoxFit.contain),
        ),
        if (documentModel.rightImageBytes != null) const SizedBox(width: 4),
        if (documentModel.rightImageBytes != null)
          AspectRatio(
            aspectRatio: 1000 / 1400,
            child: Image.memory(documentModel.rightImageBytes!, fit: BoxFit.contain),
          ),
      ],
    );
  }
}