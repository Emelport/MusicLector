import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_lector/data/models/pdf_documents.dart';
import '../data/models/drawing_point.dart';

class PdfPageView extends StatefulWidget {
  const PdfPageView({
    super.key,
    required this.documentModel,
    required this.isEditing,
    this.onToggleControls,
  });

  final PdfDocumentModel documentModel;
  final bool isEditing;
  final VoidCallback? onToggleControls;

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  double _zoom = 1.0;
  bool _zoomEnabled = false;
  late int _lastPage;
  bool _landscapeStepOne = true; // true: avanzar de 1 en 1, false: de 2 en 2
  bool _showZoomPageSelector = false;
  String _zoomPageSide = 'left'; // 'left' o 'right'

  @override
  void initState() {
    super.initState();
    _lastPage = widget.documentModel.stateNotifier.value.currentPage;
    widget.documentModel.stateNotifier.addListener(_onPageChange);
  }

  @override
  void dispose() {
    widget.documentModel.stateNotifier.removeListener(_onPageChange);
    super.dispose();
  }

  void _onPageChange() {
    final currentPage = widget.documentModel.stateNotifier.value.currentPage;
    if (currentPage != _lastPage) {
      setState(() {
        _zoom = 1.0;
        _zoomEnabled = false;
        _lastPage = currentPage;
      });
    }
  }

  void _toggleZoom() {
    final Orientation orientation = MediaQuery.of(context).orientation;
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    final bool isLandscape = orientation == Orientation.landscape;
    final bool hasRightPage = state.rightImageBytes != null;
    setState(() {
      if (!_zoomEnabled && isLandscape && hasRightPage) {
        // Mostrar selectores de página
        _showZoomPageSelector = true;
      } else {
        _zoomEnabled = !_zoomEnabled;
        if (!_zoomEnabled) {
          _zoom = 1.0;
          _showZoomPageSelector = false;
        }
      }
    });
  }

  void _selectZoomPage(String side) {
    setState(() {
      _zoomPageSide = side;
      _zoomEnabled = true;
      _showZoomPageSelector = false;
    });
  }

  void _toggleLandscapeStep() {
    setState(() {
      _landscapeStepOne = !_landscapeStepOne;
    });
    widget.documentModel.setLandscapeStep(_landscapeStepOne ? 1 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final Orientation orientation = MediaQuery.of(context).orientation;
    final bool isPortrait = orientation == Orientation.portrait;
    final Size screenSize = MediaQuery.of(context).size;
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    final bool isLandscape = orientation == Orientation.landscape;
    final bool isAtEndLandscape = isLandscape &&
        (state.currentPage + 1 >=
            (widget.documentModel.activeBookmarkTo ?? state.totalPages));
    final bool hasRightPage = state.rightImageBytes != null;

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              !isAtEndLandscape &&
              !_zoomEnabled) {
            widget.documentModel.nextPage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              !_zoomEnabled) {
            widget.documentModel.previousPage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: <Widget>[
          // Si el zoom está activado, solo mostrar una página y permitir pinch-to-zoom
          if (_zoomEnabled)
            Center(
              child: _buildZoomableSinglePage(context),
            )
          else
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
          if (!_zoomEnabled)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.arrow_left, size: 40),
                  color: Colors.black.withOpacity(0.5),
                  onPressed: widget.documentModel.previousPage,
                ),
              ),
            ),
          // → arrow
          if (!_zoomEnabled)
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
                  onPressed:
                      isAtEndLandscape ? null : widget.documentModel.nextPage,
                ),
              ),
            ),
          // Botón de zoom
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _toggleZoom,
                child: FloatingActionButton(
                  mini: true,
                  heroTag: 'zoomBtn',
                  backgroundColor: Colors.white,
                  onPressed: _toggleZoom,
                  elevation: 4,
                  child: Icon(
                    _zoomEnabled ? Icons.zoom_out_map : Icons.zoom_in,
                    color: Colors.blue[900],
                  ),
                  tooltip: _zoomEnabled ? 'Desactivar zoom' : 'Activar zoom',
                ),
              ),
            ),
          ),
          // FABs de selección de página para zoom en landscape
          if (_showZoomPageSelector && isLandscape && hasRightPage) ...[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              top: 16,
              right: 76,
              child: AnimatedScale(
                scale: _showZoomPageSelector ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _showZoomPageSelector ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'zoomRightBtn',
                    backgroundColor: Colors.white,
                    onPressed: () => _selectZoomPage('right'),
                    elevation: 4,
                    child: Text('2',
                        style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    tooltip: 'Ampliar página derecha',
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              top: 76,
              right: 16,
              child: AnimatedScale(
                scale: _showZoomPageSelector ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _showZoomPageSelector ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 260),
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'zoomLeftBtn',
                    backgroundColor: Colors.white,
                    onPressed: () => _selectZoomPage('left'),
                    elevation: 4,
                    child: Text('1',
                        style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    tooltip: 'Ampliar página izquierda',
                  ),
                ),
              ),
            ),
          ],
          // Botón de modo landscape: paso 1 o 2
          if (!isPortrait && !_zoomEnabled)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _toggleLandscapeStep,
                  child: FloatingActionButton(
                    mini: true,
                    heroTag: 'landscapeStepBtn',
                    backgroundColor: Colors.white,
                    onPressed: _toggleLandscapeStep,
                    elevation: 4,
                    child: Icon(
                      _landscapeStepOne ? Icons.filter_1 : Icons.filter_2,
                      color: Colors.blue[900],
                    ),
                    tooltip: _landscapeStepOne
                        ? 'Avance de 1 en 1'
                        : 'Avance de 2 en 2',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // NUEVO: Widget para mostrar solo una página con zoom interactivo
  Widget _buildZoomableSinglePage(BuildContext context) {
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    Widget page;
    if (_zoomPageSide == 'right' && state.rightImageBytes != null) {
      page = _buildStaticImage(state.rightImageBytes);
    } else {
      page = widget.isEditing
          ? _buildEditablePage(context)
          : _buildStaticImage(state.leftImageBytes);
    }
    return SizedBox.expand(
      child: InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        scaleEnabled: true,
        panEnabled: true,
        child: page,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Interaction helpers
  // -------------------------------------------------------------------------
  void _handleTapDown(TapDownDetails details, Size screenSize) {
    if (widget.isEditing) return;
    final double dx = details.localPosition.dx;
    final double w = screenSize.width;

    if (dx > w * 0.7) {
      widget.documentModel.nextPage();
    } else if (dx < w * 0.3) {
      widget.documentModel.previousPage();
    } else {
      if (widget.onToggleControls != null) {
        widget.onToggleControls!();
      }
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
      widget.documentModel.toggleSlider(false);
    }
  }

  // -------------------------------------------------------------------------
  // Layout helpers
  // -------------------------------------------------------------------------
  Widget _buildPortraitView(BuildContext context) {
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    final bool isLastPage = state.currentPage == state.totalPages ||
        (widget.documentModel.activeBookmarkTo != null &&
            state.currentPage == widget.documentModel.activeBookmarkTo);
    Widget page = widget.isEditing
        ? _buildEditablePage(context)
        : _buildStaticImage(state.leftImageBytes);
    if (_zoomEnabled) {
      page = InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        scaleEnabled: true,
        panEnabled: true,
        child: page,
      );
    }
    return AspectRatio(
      aspectRatio: 1000 / 1400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          page,
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
    );
  }

  Widget _buildLandscapeView(BuildContext context,
      {bool isAtEndLandscape = false}) {
    final PdfViewerState s = widget.documentModel.stateNotifier.value;
    final bool isLastPair = (widget.documentModel.activeBookmarkTo != null &&
            (s.currentPage + 1 >= widget.documentModel.activeBookmarkTo!)) ||
        (s.currentPage + 1 >= s.totalPages);
    if (s.rightImageBytes == null) {
      // Solo una página, centrarla visualmente en landscape
      Widget page = _buildLandscapePage(s.leftImageBytes, context);
      if (_zoomEnabled) {
        page = InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          scaleEnabled: true,
          panEnabled: true,
          child: page,
        );
      }
      return Center(
        child: SizedBox(
          width: 420,
          child: page,
        ),
      );
    }
    // Dos páginas: mostrar ambas lado a lado, cada una con el mismo ancho
    // Si es la última vista, no repitas la última página en ambos lados
    final bool isLast = isAtEndLandscape &&
        (s.currentPage + 1 > s.totalPages ||
            (widget.documentModel.activeBookmarkTo != null &&
                s.currentPage + 1 > widget.documentModel.activeBookmarkTo!));
    Widget leftPage = _buildLandscapePage(s.leftImageBytes, context);
    Widget rightPage = _buildLandscapePage(s.rightImageBytes, context);
    if (_zoomEnabled) {
      leftPage = InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        scaleEnabled: true,
        panEnabled: true,
        child: leftPage,
      );
      rightPage = InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        scaleEnabled: true,
        panEnabled: true,
        child: rightPage,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Flexible(
          flex: 1,
          child: leftPage,
        ),
        const SizedBox(width: 4),
        Flexible(
          flex: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              rightPage,
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
      child: widget.isEditing
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
              widget.documentModel.startNewDrawingPoint(
                  e.localPosition, Size(c.maxWidth, c.maxHeight),
                  pressure: e.pressure);
            }
          },
          onPointerMove: (PointerMoveEvent e) {
            if (e.kind == PointerDeviceKind.stylus ||
                e.kind == PointerDeviceKind.invertedStylus) {
              widget.documentModel.updateDrawingPoint(
                  e.localPosition, Size(c.maxWidth, c.maxHeight),
                  pressure: e.pressure);
            }
          },
          child: GestureDetector(
            onPanStart: (DragStartDetails d) => widget.documentModel
                .startNewDrawingPoint(
                    d.localPosition, Size(c.maxWidth, c.maxHeight)),
            onPanUpdate: (DragUpdateDetails d) => widget.documentModel
                .updateDrawingPoint(
                    d.localPosition, Size(c.maxWidth, c.maxHeight)),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildStaticImage(imageBytes ??
                    widget.documentModel.stateNotifier.value.leftImageBytes),
                CustomPaint(
                  painter: DrawingPainter(
                      drawingPoints: widget
                          .documentModel.stateNotifier.value.drawingPoints),
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
