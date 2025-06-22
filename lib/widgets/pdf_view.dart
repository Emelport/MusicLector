import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_lector/data/models/pdf_documents.dart';
import '../data/models/drawing_point.dart';
import 'package:flutter/foundation.dart';

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
  TransformationController _transformationController =
      TransformationController();
  bool _showControls = true;
  bool _isZooming = false;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.documentModel.stateNotifier.value.currentPage;
    widget.documentModel.stateNotifier.addListener(_onPageChange);
  }

  @override
  void dispose() {
    widget.documentModel.stateNotifier.removeListener(_onPageChange);
    _transformationController.dispose();
    super.dispose();
  }

  void _onPageChange() {
    final currentPage = widget.documentModel.stateNotifier.value.currentPage;
    if (currentPage != _lastPage) {
      setState(() {
        _transformationController.value = Matrix4.identity();
        _lastPage = currentPage;
        _isZooming = false;
        _showControls = true;
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
        if (event is KeyDownEvent && !_isZooming) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              !isAtEndLandscape) {
            widget.documentModel.nextPage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.documentModel.previousPage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape &&
              _isZoomed()) {
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
              if (_isZoomed()) {
                _resetZoom();
              } else {
                setState(() {
                  _transformationController.value =
                      Matrix4.diagonal3Values(2.0, 2.0, 1.0);
                  _isZooming = true;
                  _showControls = false;
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
          ],
          // FABs de selección de página para edición en landscape
          if (_showControls &&
              isLandscape &&
              isEditing &&
              state.rightImageBytes != null) ...[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              top: 16,
              right: 16,
              child: AnimatedOpacity(
                opacity: isEditing ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
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
        panEnabled: !isEditing, // Deshabilitar pan durante la edición
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

  void _handleTapDown(TapDownDetails details, Size screenSize) {
    if (widget.isEditing || _isZooming) return;
    final double dx = details.localPosition.dx;
    final double w = screenSize.width;

    if (dx > w * 0.7) {
      widget.documentModel.nextPage();
    } else if (dx < w * 0.3) {
      widget.documentModel.previousPage();
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isZooming &&
        details.primaryVelocity != null &&
        details.primaryVelocity! > 400) {
      widget.documentModel.toggleSlider(false);
    }
  }

  Widget _buildPortraitView(BuildContext context) {
    final PdfViewerState state = widget.documentModel.stateNotifier.value;
    final bool isLastPage = state.currentPage == state.totalPages ||
        (widget.documentModel.activeBookmarkTo != null &&
            state.currentPage == widget.documentModel.activeBookmarkTo);

    Widget page = widget.isEditing
        ? _buildEditablePage(context)
        : _buildStaticImage(state.leftImageBytes);

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
    final bool isEditing = widget.isEditing;
    final String activeEditSide = widget.documentModel.activeEditSide;

    if (s.rightImageBytes == null) {
      Widget page = isEditing
          ? _buildEditablePage(context, imageBytes: s.leftImageBytes)
          : _buildStaticImage(s.leftImageBytes);

      return Center(
        child: SizedBox(
          width: 420,
          child: page,
        ),
      );
    }

    Widget leftPage = (isEditing && activeEditSide == 'left')
        ? _buildEditablePage(context, imageBytes: s.leftImageBytes)
        : _buildStaticImage(s.leftImageBytes);
    Widget rightPage = (isEditing && activeEditSide == 'right')
        ? _buildEditablePage(context, imageBytes: s.rightImageBytes)
        : _buildStaticImage(s.rightImageBytes);

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
        : _AnimatedFadeInImage(bytes: bytes);
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

class _AnimatedFadeInImage extends StatefulWidget {
  final Uint8List bytes;
  const _AnimatedFadeInImage({required this.bytes});

  @override
  State<_AnimatedFadeInImage> createState() => _AnimatedFadeInImageState();
}

class _AnimatedFadeInImageState extends State<_AnimatedFadeInImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedFadeInImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Image.memory(widget.bytes, fit: BoxFit.contain),
    );
  }
}
