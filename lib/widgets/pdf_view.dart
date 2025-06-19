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
    final PdfViewerState state = documentModel.stateNotifier.value;
    final bool isLandscape = orientation == Orientation.landscape;
    final bool isAtEndLandscape = isLandscape &&
        (state.currentPage + 1 >=
            (documentModel.activeBookmarkTo ?? state.totalPages));

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              !isAtEndLandscape) {
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
                  : _buildLandscapeView(context,
                      isAtEndLandscape: isAtEndLandscape),
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
                color: isAtEndLandscape
                    ? Colors.grey
                    : Colors.black.withOpacity(0.5),
                onPressed: isAtEndLandscape ? null : documentModel.nextPage,
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
    final PdfViewerState state = documentModel.stateNotifier.value;
    final bool isLastPage = state.currentPage == state.totalPages ||
        (documentModel.activeBookmarkTo != null &&
            state.currentPage == documentModel.activeBookmarkTo);
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          isEditing
              ? _buildEditablePage(context)
              : _buildStaticImage(state.leftImageBytes),
          if (isLastPage)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 8,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.red.withOpacity(0.7)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLandscapeView(BuildContext context,
      {bool isAtEndLandscape = false}) {
    final PdfViewerState s = documentModel.stateNotifier.value;
    final bool isLastPair = (documentModel.activeBookmarkTo != null &&
            (s.currentPage + 1 >= documentModel.activeBookmarkTo!)) ||
        (s.currentPage + 1 >= s.totalPages);
    if (s.rightImageBytes == null) {
      // Solo una página, centrarla visualmente en landscape
      return Center(
        child: SizedBox(
          width: 420,
          child: _buildLandscapePage(s.leftImageBytes, context),
        ),
      );
    }
    // Dos páginas: mostrar ambas lado a lado, cada una con el mismo ancho
    // Si es la última vista, no repitas la última página en ambos lados
    final bool isLast = isAtEndLandscape &&
        (s.currentPage + 1 > s.totalPages ||
            (documentModel.activeBookmarkTo != null &&
                s.currentPage + 1 > documentModel.activeBookmarkTo!));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Flexible(
          flex: 1,
          child: _buildLandscapePage(s.leftImageBytes, context),
        ),
        const SizedBox(width: 4),
        Flexible(
          flex: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!isLast) _buildLandscapePage(s.rightImageBytes, context),
              if (isLastPair)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 8,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.blue.shade900.withOpacity(0.85)
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapePage(Uint8List? bytes, BuildContext context) {
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: isEditing
          ? _buildEditablePage(context, imageBytes: bytes)
          : _buildStaticImage(bytes),
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
              documentModel.startNewDrawingPoint(
                  e.localPosition, Size(c.maxWidth, c.maxHeight),
                  pressure: e.pressure);
            }
          },
          onPointerMove: (PointerMoveEvent e) {
            if (e.kind == PointerDeviceKind.stylus ||
                e.kind == PointerDeviceKind.invertedStylus) {
              documentModel.updateDrawingPoint(
                  e.localPosition, Size(c.maxWidth, c.maxHeight),
                  pressure: e.pressure);
            }
          },
          child: GestureDetector(
            onPanStart: (DragStartDetails d) =>
                documentModel.startNewDrawingPoint(
                    d.localPosition, Size(c.maxWidth, c.maxHeight)),
            onPanUpdate: (DragUpdateDetails d) =>
                documentModel.updateDrawingPoint(
                    d.localPosition, Size(c.maxWidth, c.maxHeight)),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildStaticImage(imageBytes ??
                    documentModel.stateNotifier.value.leftImageBytes),
                CustomPaint(
                  painter: DrawingPainter(
                      drawingPoints:
                          documentModel.stateNotifier.value.drawingPoints),
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
