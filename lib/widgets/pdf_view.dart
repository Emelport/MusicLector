
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_lector/data/models/pdf_documents.dart';
import '../data/models/drawing_point.dart';

class PdfPageView extends StatelessWidget {
  const PdfPageView({
    super.key,
    required this.documentModel,
    required this.isEditing,
  });

  final PdfDocumentModel documentModel;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final Orientation orientation = MediaQuery.of(context).orientation;
    final bool isPortrait = orientation == Orientation.portrait;
    final Size screenSize = MediaQuery.of(context).size;

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            documentModel.nextPage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            documentModel.previousPage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails d) => _handleTapDown(d, screenSize),
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: Center(
              child: isPortrait
                  ? _buildPortraitView(context)
                  : _buildLandscapeView(context),
            ),
          ),
          // ← arrow
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.arrow_left, size: 40),
                color: Colors.black.withOpacity(0.5),
                onPressed: documentModel.previousPage,
              ),
            ),
          ),
          // → arrow
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.arrow_right, size: 40),
                color: Colors.black.withOpacity(0.5),
                onPressed: documentModel.nextPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Interaction helpers
  // -------------------------------------------------------------------------
  void _handleTapDown(TapDownDetails details, Size screenSize) {
    if (isEditing) return;
    final double dx = details.localPosition.dx;
    final double w = screenSize.width;

    if (dx > w * 0.7) {
      documentModel.nextPage();
    } else if (dx < w * 0.3) {
      documentModel.previousPage();
    } else {
      documentModel.toggleSlider(!documentModel.stateNotifier.value.showSlider);
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
      documentModel.toggleSlider(false);
    }
  }

  // -------------------------------------------------------------------------
  // Layout helpers
  // -------------------------------------------------------------------------
  Widget _buildPortraitView(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: isEditing ? _buildEditablePage(context) : _buildStaticImage(documentModel.stateNotifier.value.leftImageBytes),
    );
  }

  Widget _buildLandscapeView(BuildContext context) {
    final PdfViewerState s = documentModel.stateNotifier.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildLandscapePage(s.leftImageBytes, context),
        if (s.rightImageBytes != null) const SizedBox(width: 4),
        if (s.rightImageBytes != null) _buildLandscapePage(s.rightImageBytes, context),
      ],
    );
  }

  Widget _buildLandscapePage(Uint8List? bytes, BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: isEditing ? _buildEditablePage(context, imageBytes: bytes) : _buildStaticImage(bytes),
    );
  }

  Widget _buildStaticImage(Uint8List? bytes) {
    return bytes == null
        ? const Center(child: CircularProgressIndicator())
        : Image.memory(bytes, fit: BoxFit.contain);
  }

  Widget _buildEditablePage(BuildContext context, {Uint8List? imageBytes}) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        return Listener(
          onPointerDown: (PointerDownEvent e) {
            if (e.kind == PointerDeviceKind.stylus ||
                e.kind == PointerDeviceKind.invertedStylus) {
              documentModel.startNewDrawingPoint(e.localPosition, Size(c.maxWidth, c.maxHeight), pressure: e.pressure);
            }
          },
          onPointerMove: (PointerMoveEvent e) {
            if (e.kind == PointerDeviceKind.stylus ||
                e.kind == PointerDeviceKind.invertedStylus) {
              documentModel.updateDrawingPoint(e.localPosition, Size(c.maxWidth, c.maxHeight), pressure: e.pressure);
            }
          },
          child: GestureDetector(
            onPanStart: (DragStartDetails d) => documentModel.startNewDrawingPoint(d.localPosition, Size(c.maxWidth, c.maxHeight)),
            onPanUpdate: (DragUpdateDetails d) => documentModel.updateDrawingPoint(d.localPosition, Size(c.maxWidth, c.maxHeight)),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildStaticImage(imageBytes ?? documentModel.stateNotifier.value.leftImageBytes),
                CustomPaint(
                  painter: DrawingPainter(drawingPoints: documentModel.stateNotifier.value.drawingPoints),
                  size: Size(c.maxWidth, c.maxHeight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
