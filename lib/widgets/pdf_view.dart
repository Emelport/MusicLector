import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import '../data/models/drawing_point.dart';
import '../data/models/pdf_documents.dart';

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
      children: [
        GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _handleTapDown(details, screenSize),
        onVerticalDragEnd: (details) => _handleVerticalDragEnd(details),
        child: Center(
          child: isPortrait
            ? _buildPortraitView(context)
            : _buildLandscapeView(context),
        ),
        ),
        // Flecha izquierda
        Positioned(
        left: 8,
        top: 0,
        bottom: 0,
        child: Center(
          child: IconButton(
          icon: const Icon(Icons.arrow_left, size: 40),
          color: Colors.black.withOpacity(0.5),
          onPressed: () {
            documentModel.previousPage();
          },
          ),
        ),
        ),
        // Flecha derecha
        Positioned(
        right: 8,
        top: 0,
        bottom: 0,
        child: Center(
          child: IconButton(
          icon: const Icon(Icons.arrow_right, size: 40),
          color: Colors.black.withOpacity(0.5),
          onPressed: () {
            documentModel.nextPage();
          },
          ),
        ),
        ),
      ],
      ),
    );
  }

  void _handleTapDown(TapDownDetails details, Size screenSize) {
    if (isEditing) return;
    
    final dx = details.localPosition.dx;
    final width = screenSize.width;

    if (dx > width * 0.7) {
      documentModel.nextPage();
    } else if (dx < width * 0.3) {
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
        return Listener(
          onPointerDown: (details) {
            if (details.kind == PointerDeviceKind.stylus || details.kind == PointerDeviceKind.invertedStylus) {
              documentModel.startNewDrawingPoint(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                pressure: details.pressure,
              );
            }
          },
          onPointerMove: (details) {
            if (details.kind == PointerDeviceKind.stylus || details.kind == PointerDeviceKind.invertedStylus) {
              documentModel.updateDrawingPoint(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
                pressure: details.pressure,
              );
            }
          },
          child: GestureDetector(
            onPanStart: (details) {
              documentModel.startNewDrawingPoint(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
            onPanUpdate: (details) {
              documentModel.updateDrawingPoint(
                details.localPosition,
                Size(constraints.maxWidth, constraints.maxHeight),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  documentModel.leftImageBytes!,
                  fit: BoxFit.contain,
                ),
                CustomPaint(
                  painter: DrawingPainter(
                    drawingPoints: documentModel.stateNotifier.value.drawingPoints,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandscapeView(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLandscapePage(documentModel.leftImageBytes!, context),
        if (documentModel.rightImageBytes != null) const SizedBox(width: 4),
        if (documentModel.rightImageBytes != null)
          _buildLandscapePage(documentModel.rightImageBytes!, context),
      ],
    );
  }

  Widget _buildLandscapePage(Uint8List imageBytes, BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: isEditing
          ? LayoutBuilder(
              builder: (context, constraints) {
                return Listener(
                  onPointerDown: (details) {
                    if (details.kind == PointerDeviceKind.stylus || details.kind == PointerDeviceKind.invertedStylus) {
                      documentModel.startNewDrawingPoint(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                        pressure: details.pressure,
                      );
                    }
                  },
                  onPointerMove: (details) {
                    if (details.kind == PointerDeviceKind.stylus || details.kind == PointerDeviceKind.invertedStylus) {
                      documentModel.updateDrawingPoint(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                        pressure: details.pressure,
                      );
                    }
                  },
                  child: GestureDetector(
                    onPanStart: (details) {
                      documentModel.startNewDrawingPoint(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                    },
                    onPanUpdate: (details) {
                      documentModel.updateDrawingPoint(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(imageBytes, fit: BoxFit.contain),
                        CustomPaint(
                          painter: DrawingPainter(
                            drawingPoints: documentModel.stateNotifier.value.drawingPoints,
                          ),
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : Image.memory(
              documentModel.editedImageBytes ?? imageBytes,
              fit: BoxFit.contain,
            ),
    );
  }
}