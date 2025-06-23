import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
  late int _lastPage;
  bool _landscapeStepOne = true;
  TransformationController _transformationController = TransformationController();
  bool _showControls = true;
  bool _isZooming = false;
  bool _isChangingPage = false;
  DateTime? _lastPageChangeTime;
  bool _canGoNext = true;
  bool _canGoPrev = true;
  DateTime? _lastDoubleTapTime;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.documentModel.stateNotifier.value.currentPage;
    _updatePageBoundaries();
    widget.documentModel.stateNotifier.addListener(_onPageChange);
  }

  @override
  void dispose() {
    widget.documentModel.stateNotifier.removeListener(_onPageChange);
    _transformationController.dispose();
    super.dispose();
  }

  void _updatePageBoundaries() {
    final state = widget.documentModel.stateNotifier.value;
    final currentPage = state.currentPage;
    final totalPages = state.totalPages;
    final bookmarkTo = widget.documentModel.activeBookmarkTo;
    
    _canGoPrev = currentPage > 1;
    _canGoNext = bookmarkTo != null 
      ? currentPage < bookmarkTo
      : currentPage < totalPages;
  }

  void _onPageChange() {
    if (!mounted) return;
    
    final currentPage = widget.documentModel.stateNotifier.value.currentPage;
    if (currentPage != _lastPage) {
      _updatePageBoundaries();
      setState(() {
        _transformationController.value = Matrix4.identity();
        _lastPage = currentPage;
        _isZooming = false;
        _showControls = true;
        _isChangingPage = false;
        _lastPageChangeTime = DateTime.now();
      });
    }
  }

  bool _isZoomed() {
    return _transformationController.value != Matrix4.identity();
  }

  void _toggleLandscapeStep() {
    setState(() {
      _landscapeStepOne = !_landscapeStepOne;
    });
    widget.documentModel.setLandscapeStep(_landscapeStepOne ? 1 : 2);
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _isZooming = false;
      _showControls = true;
    });
  }

  Future<void> _changePage(bool next) async {
    if (_isChangingPage || _isZooming) return;
    
    // Check if we're at boundary
    if ((next && !_canGoNext) || (!next && !_canGoPrev)) {
      return;
    }

    final now = DateTime.now();
    if (_lastPageChangeTime != null && 
        now.difference(_lastPageChangeTime!) < Duration(milliseconds: 200)) {
      return;
    }

    setState(() {
      _isChangingPage = true;
    });

    try {
      if (next) {
        await widget.documentModel.nextPage();
      } else {
        await widget.documentModel.previousPage();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Orientation orientation = MediaQuery.of(context).orientation;
    final bool isPortrait = orientation == Orientation.portrait;
    final Size screenSize = MediaQuery.of(context).size;
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    final bool isLandscape = orientation == Orientation.landscape;
    final bool isAtEndLandscape = isLandscape && !_canGoNext;
    final bool isEditing = widget.isEditing;
    final String activeEditSide = widget.documentModel.activeEditSide;

    // Configuración de TouchBar
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      HardwareKeyboard.instance.addHandler((KeyEvent event) {
        if (event is KeyDownEvent && _isZoomed()) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _resetZoom();
            return true;
          }
        }
        return false;
      });
    }

    Widget content = Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent && !_isZooming && !_isChangingPage) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight && _canGoNext) {
            _changePage(true);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _canGoPrev) {
            _changePage(false);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape && _isZoomed()) {
            _resetZoom();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isZoomed()) {
                _resetZoom();
              } else if (widget.onToggleControls != null) {
                widget.onToggleControls!();
              }
            },
            onDoubleTap: () {
              final now = DateTime.now();
              // Prevent double tap if we're changing pages or if it's too soon after a page change
              if (_isChangingPage || 
                  (_lastPageChangeTime != null && 
                   now.difference(_lastPageChangeTime!) < Duration(milliseconds: 300))) {
                return;
              }
              
              if (_isZoomed()) {
                _resetZoom();
              } else {
                setState(() {
                  _transformationController.value =
                      Matrix4.diagonal3Values(2.0, 2.0, 1.0);
                  _isZooming = true;
                  _showControls = false;
                  _lastDoubleTapTime = now;
                });
              }
            },
            onVerticalDragEnd: _handleVerticalDragEnd,
            child: Center(
              child: isPortrait
                  ? _buildPortraitView(context)
                  : _buildLandscapeView(context,
                      isAtEndLandscape: isAtEndLandscape),
            ),
          ),
          // Controles de navegación (solo visibles sin zoom)
          if (_showControls && !_isZooming) ...[
            // ← arrow
            if (_canGoPrev)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: _isChangingPage 
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue[900],
                            ),
                          )
                        : Icon(Icons.arrow_left, size: 40),
                    color: Colors.black.withOpacity(0.5),
                    onPressed: _isChangingPage ? null : () => _changePage(false),
                  ),
                ),
              ),
            // → arrow
            if (_canGoNext)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: _isChangingPage
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue[900],
                            ),
                          )
                        : Icon(Icons.arrow_right, size: 40),
                    color: isAtEndLandscape
                        ? Colors.grey
                        : Colors.black.withOpacity(0.5),
                    onPressed: _isChangingPage || isAtEndLandscape 
                        ? null 
                        : () => _changePage(true),
                  ),
                ),
              ),
          ],
          // FABs de selección de página para edición en landscape
          if (_showControls &&
              isLandscape &&
              isEditing &&
              state.rightImageBytes != null) ...[
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'editLeftBtn',
                    backgroundColor: activeEditSide == 'left'
                        ? Colors.blue[900]
                        : Colors.white,
                    onPressed: () async {
                      if (widget.documentModel.stateNotifier.value
                          .drawingPoints.isNotEmpty) {
                        await widget.documentModel.saveDrawing();
                      }
                      setState(() {
                        widget.documentModel.activeEditSide = 'left';
                      });
                    },
                    elevation: 4,
                    child: Text('1',
                        style: TextStyle(
                            color: activeEditSide == 'left'
                                ? Colors.white
                                : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    tooltip: 'Editar página izquierda',
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    mini: true,
                    heroTag: 'editRightBtn',
                    backgroundColor: activeEditSide == 'right'
                        ? Colors.blue[900]
                        : Colors.white,
                    onPressed: () async {
                      if (widget.documentModel.stateNotifier.value
                          .drawingPoints.isNotEmpty) {
                        await widget.documentModel.saveDrawing();
                      }
                      setState(() {
                        widget.documentModel.activeEditSide = 'right';
                      });
                    },
                    elevation: 4,
                    child: Text('2',
                        style: TextStyle(
                            color: activeEditSide == 'right'
                                ? Colors.white
                                : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    tooltip: 'Editar página derecha',
                  ),
                ],
              ),
            ),
          ],
          // Botón de modo landscape: paso 1 o 2
          if (_showControls && !isPortrait && !_isZooming)
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
          // Botón para salir del zoom (solo visible cuando hay zoom)
          if (_isZoomed())
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                heroTag: 'exitZoomBtn',
                backgroundColor: Colors.white,
                onPressed: _resetZoom,
                elevation: 4,
                child: Icon(
                  Icons.fullscreen_exit,
                  color: Colors.blue[900],
                ),
                tooltip: 'Salir del zoom',
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onScaleStart: (details) {
        setState(() {
          _isZooming = true;
          _showControls = false;
        });
      },
      onScaleEnd: (details) {
        if (_transformationController.value == Matrix4.identity()) {
          setState(() {
            _isZooming = false;
            _showControls = true;
          });
        }
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.8,
        maxScale: 4.0,
        boundaryMargin: EdgeInsets.all(20),
        panEnabled: !isEditing,
        onInteractionEnd: (details) {
          if (_transformationController.value == Matrix4.identity()) {
            setState(() {
              _isZooming = false;
              _showControls = true;
            });
          }
        },
        child: content,
      ),
    );
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isZooming &&
        !_isChangingPage &&
        details.primaryVelocity != null &&
        details.primaryVelocity! > 400) {
      widget.documentModel.toggleSlider(false);
    }
  }

  Widget _buildPortraitView(BuildContext context) {
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    final bool isLastPage = !_canGoNext;

    Widget page = widget.isEditing
        ? _buildEditablePage(context)
        : Image.memory(
            state.leftImageBytes!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );

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
    final bool isLastPair = !_canGoNext;
    final bool isEditing = widget.isEditing;
    final String activeEditSide = widget.documentModel.activeEditSide;

    if (s.rightImageBytes == null) {
      Widget page = isEditing
          ? _buildEditablePage(context, imageBytes: s.leftImageBytes)
          : Image.memory(
              s.leftImageBytes!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            );

      return Center(
        child: SizedBox(
          width: 420,
          child: page,
        ),
      );
    }

    Widget leftPage = (isEditing && activeEditSide == 'left')
        ? _buildEditablePage(context, imageBytes: s.leftImageBytes)
        : Image.memory(
            s.leftImageBytes!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );
    Widget rightPage = (isEditing && activeEditSide == 'right')
        ? _buildEditablePage(context, imageBytes: s.rightImageBytes)
        : Image.memory(
            s.rightImageBytes!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );

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

  Widget _buildStaticImage(Uint8List? bytes) {
    return bytes == null
        ? const Center(child: CircularProgressIndicator())
        : Image.memory(
            bytes,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          );
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
            onPanStart: (DragStartDetails d) {
              if (!_isZooming) {
                widget.documentModel.startNewDrawingPoint(
                    d.localPosition, Size(c.maxWidth, c.maxHeight));
              }
            },
            onPanUpdate: (DragUpdateDetails d) {
              if (!_isZooming) {
                widget.documentModel.updateDrawingPoint(
                    d.localPosition, Size(c.maxWidth, c.maxHeight));
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildStaticImage(imageBytes ??
                    widget.documentModel.stateNotifier.value.leftImageBytes),
                CustomPaint(
                  painter: DrawingPainter(
                      rects: widget
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