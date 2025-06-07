import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewer extends StatefulWidget {
  final String filePath;
  final bool multipleFiles;
  final int indexStart;

  const PdfViewer({
    super.key,
    required this.filePath,
    this.multipleFiles = false,
    this.indexStart = 0,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> with WidgetsBindingObserver {
  late PdfDocument document;
  List<PdfDocument> documents = [];
  List<MapEntry<int, PdfDocument>> pageMap = [];
  int currentPage = 1;
  int totalPages = 0;

  Uint8List? leftImageBytes;
  Uint8List? rightImageBytes;
  Uint8List? previewImageBytes;
  Uint8List? editedImageBytes;

  Orientation? _lastOrientation;
  final ValueNotifier<Alignment> alignmentNotifier = ValueNotifier(Alignment.topCenter);
  final ValueNotifier<bool> showSliderNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isEditingNotifier = ValueNotifier(false);

  double? _sliderValue;
  bool _isSliding = false;
  int previewPage = 1;

  // Variables for editing mode
  List<DrawingPointRelative> drawingPoints = [];
  double strokeWidth = 3.0;
  Color selectedColor = Colors.red;
  DrawingMode drawingMode = DrawingMode.pen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPdf();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final doc in documents) {
      doc.close();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final orientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      _renderPages();
    }
  }

  Future<void> loadPdf() async {
    if (widget.multipleFiles) {
      final paths = widget.filePath.split(';|;').map((e) => e.trim()).toList();
      documents = await Future.wait(paths.map((path) => PdfDocument.openFile(path)));

      totalPages = 0;
      pageMap.clear();
      int pageIndex = 1;
      for (final doc in documents) {
        for (int i = 1; i <= doc.pagesCount; i++) {
          pageMap.add(MapEntry(pageIndex, doc));
          pageIndex++;
        }
        totalPages += doc.pagesCount;
      }

      int startFileIndex = widget.indexStart.clamp(0, documents.length - 1);
      int startPage = 1;
      for (int i = 0; i < startFileIndex; i++) {
        startPage += documents[i].pagesCount;
      }
      currentPage = startPage;
    } else {
      document = await PdfDocument.openFile(widget.filePath);
      totalPages = document.pagesCount;
      currentPage = widget.indexStart.clamp(1, totalPages);
    }

    await _renderPages();
    await _renderPreview(currentPage);
  }

  Future<PdfPage> _getPage(int pageNumber) async {
    if (!widget.multipleFiles) return await document.getPage(pageNumber);

    int pageCounted = 0;
    for (final doc in documents) {
      if (pageNumber <= pageCounted + doc.pagesCount) {
        return await doc.getPage(pageNumber - pageCounted);
      }
      pageCounted += doc.pagesCount;
    }
    throw Exception("Page not found");
  }

  Future<void> _renderPages() async {
    final leftPage = await _getPage(currentPage);
    final leftImage = await leftPage.render(width: 1000, height: 1400);
    await leftPage.close();

    Uint8List? rightBytes;
    if (currentPage + 1 <= totalPages) {
      final rightPage = await _getPage(currentPage + 1);
      final rightImage = await rightPage.render(width: 1000, height: 1400);
      rightBytes = rightImage?.bytes;
      await rightPage.close();
    }

    if (mounted) {
      setState(() {
        leftImageBytes = leftImage?.bytes;
        rightImageBytes = rightBytes;
        editedImageBytes = null;
        drawingPoints.clear();
      });
    }
  }

  Future<void> _renderPreview(int page, {double width = 120, double height = 170}) async {
    final previewPage = await _getPage(page);
    final previewImage = await previewPage.render(width: width, height: height);
    await previewPage.close();
    if (mounted) {
      setState(() {
        previewImageBytes = previewImage?.bytes;
      });
    }
  }

  Future<void> _next() async {
    final orientation = MediaQuery.of(context).orientation;
    int step = (orientation == Orientation.portrait) ? 1 : 2;

    if (currentPage + step <= totalPages) {
      currentPage += step;
      await _renderPages();
      await _renderPreview(currentPage);
    }
  }

  Future<void> _prev() async {
    final orientation = MediaQuery.of(context).orientation;
    int step = (orientation == Orientation.portrait) ? 1 : 2;

    currentPage = (currentPage - step).clamp(1, totalPages);
    await _renderPages();
    await _renderPreview(currentPage);
  }

  void _handleTapDown(TapDownDetails details, Size screenSize) {
    if (isEditingNotifier.value) return;

    final dx = details.localPosition.dx;
    final width = screenSize.width;

    if (dx > width * 0.75) {
      _next();
    } else if (dx < width * 0.25) {
      _prev();
    }
  }

  Future<void> _saveDrawing() async {
    if (leftImageBytes == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(1000, 1400);
    
    // Draw background image
    final bgImage = await decodeImageFromList(leftImageBytes!);
    canvas.drawImage(bgImage, Offset.zero, Paint());
    
    // Draw annotations
    final painter = DrawingPainterRelative(drawingPoints: drawingPoints);
    painter.paint(canvas, size);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();
    
    if (pngBytes != null && mounted) {
      setState(() {
        editedImageBytes = pngBytes;
        isEditingNotifier.value = false;
      });
    }
  }

  Widget _buildEditorControls() {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // Tool selector
            Row(
              children: [
                _buildToolButton(
                  icon: Icons.brush,
                  isSelected: drawingMode == DrawingMode.pen,
                  onPressed: () => setState(() => drawingMode = DrawingMode.pen),
                ),
                _buildToolButton(
                  icon: Icons.highlight,
                  isSelected: drawingMode == DrawingMode.highlighter,
                  onPressed: () => setState(() {
                    drawingMode = DrawingMode.highlighter;
                    selectedColor = selectedColor.withOpacity(0.4);
                  }),
                ),
              ],
            ),
            
            // Color selector
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                children: [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.black,
                  Colors.purple,
                ].map((color) {
                  return GestureDetector(
                    onTap: () => setState(() {
                      selectedColor = drawingMode == DrawingMode.highlighter 
                          ? color.withOpacity(0.4) 
                          : color;
                    }),
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
            ),
            
            // Stroke width
            Slider(
              value: strokeWidth,
              min: 1,
              max: 20,
              onChanged: (value) => setState(() => strokeWidth = value),
            ),
            
            // Action buttons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: () {
                    setState(() {
                      if (drawingPoints.isNotEmpty) drawingPoints.removeLast();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  color: Colors.green,
                  onPressed: _saveDrawing,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.red,
                  onPressed: () {
                    setState(() {
                      isEditingNotifier.value = false;
                      drawingPoints.clear();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      color: isSelected ? Colors.blue[900] : Colors.grey,
      onPressed: onPressed,
    );
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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final Orientation orientation = MediaQuery.of(context).orientation;

    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      _renderPages();
    }

    if (leftImageBytes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPortrait = orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: ValueListenableBuilder<bool>(
        valueListenable: isEditingNotifier,
        builder: (context, isEditing, child) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              final dy = details.localPosition.dy;
              final height = MediaQuery.of(context).size.height;

              if (dy > height - 120) {
                showSliderNotifier.value = true;
              } else if (!isEditing) {
                _handleTapDown(details, screenSize);
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
                showSliderNotifier.value = false;
              }
            },
            child: Stack(
              children: [
                // PDF view or edited image
                Center(
                  child: isPortrait
                      ? AspectRatio(
                          aspectRatio: 1000 / 1400,
                          child: isEditing
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    final imageWidth = constraints.maxWidth;
                                    final imageHeight = constraints.maxHeight;
                                    return GestureDetector(
                                      onPanStart: (details) {
                                        final local = _transformToImageCoords(
                                          details.localPosition,
                                          imageWidth,
                                          imageHeight,
                                        );
                                        setState(() {
                                          drawingPoints.add(DrawingPointRelative(
                                            relativePoint: local,
                                            paint: Paint()
                                              ..color = selectedColor
                                              ..strokeWidth = strokeWidth / imageWidth * 1000
                                              ..strokeCap = StrokeCap.round
                                              ..isAntiAlias = true,
                                          ));
                                        });
                                      },
                                      onPanUpdate: (details) {
                                        final local = _transformToImageCoords(
                                          details.localPosition,
                                          imageWidth,
                                          imageHeight,
                                        );
                                        setState(() {
                                          drawingPoints.add(DrawingPointRelative(
                                            relativePoint: local,
                                            paint: Paint()
                                              ..color = selectedColor
                                              ..strokeWidth = strokeWidth / imageWidth * 1000
                                              ..strokeCap = StrokeCap.round
                                              ..isAntiAlias = true,
                                          ));
                                        });
                                      },
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(leftImageBytes!, fit: BoxFit.contain),
                                          CustomPaint(
                                            painter: DrawingPainterRelative(
                                              drawingPoints: drawingPoints,
                                            ),
                                            size: Size(imageWidth, imageHeight),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Image.memory(
                                  editedImageBytes ?? leftImageBytes!,
                                  fit: BoxFit.contain,
                                ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: 1000 / 1400,
                              child: Image.memory(leftImageBytes!, fit: BoxFit.contain),
                            ),
                            if (rightImageBytes != null) const SizedBox(width: 4),
                            if (rightImageBytes != null)
                              AspectRatio(
                                aspectRatio: 1000 / 1400,
                                child: Image.memory(rightImageBytes!, fit: BoxFit.contain),
                              ),
                          ],
                        ),
                ),

                // Top toolbar
                if (!isEditing)
                  ValueListenableBuilder<Alignment>(
                    valueListenable: alignmentNotifier,
                    builder: (context, alignment, child) {
                      return Align(
                        alignment: alignment,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            final RenderBox box = context.findRenderObject() as RenderBox;
                            final Offset localPosition = box.globalToLocal(details.globalPosition);
                            final double x = (localPosition.dx / box.size.width) * 2 - 1;
                            final double y = (localPosition.dy / box.size.height) * 2 - 1;

                            double snapThreshold = 0.92;
                            double snappedDx = x.clamp(-1.0, 1.0);
                            if (snappedDx <= -snapThreshold) snappedDx = -1.0;
                            else if (snappedDx >= snapThreshold) snappedDx = 1.0;

                            alignmentNotifier.value = Alignment(snappedDx, y.clamp(-1.0, 1.0));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back, color: Colors.blue[900]),
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.blue[900]),
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    isEditingNotifier.value = true;
                                    drawingPoints.clear();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.bookmark_add_outlined, color: Colors.blue[900]),
                                  tooltip: 'Add Bookmark',
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Editing controls
                if (isEditing) _buildEditorControls(),

                // Navigation slider
                ValueListenableBuilder<bool>(
                  valueListenable: showSliderNotifier,
                  builder: (context, showSlider, child) {
                    if (!showSlider && !_isSliding) return const SizedBox.shrink();
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        alignment: Alignment.center,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 24, left: 60, right: 60),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.98),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    trackShape: const RoundedRectSliderTrackShape(),
                                    activeTrackColor: Colors.blue[700],
                                    inactiveTrackColor: Colors.blue[100],
                                  ),
                                  child: Slider(
                                    value: _sliderValue ?? currentPage.toDouble(),
                                    min: 1,
                                    max: totalPages.toDouble(),
                                    divisions: totalPages > 1 ? totalPages - 1 : 1,
                                    label: 'Page ${(_sliderValue ?? currentPage).round()}',
                                    onChanged: (value) async {
                                      setState(() {
                                        _sliderValue = value;
                                        _isSliding = true;
                                        previewPage = value.round();
                                      });
                                      await _renderPreview(value.round(), width: 320, height: 440);
                                    },
                                    onChangeEnd: (value) async {
                                      setState(() {
                                        _isSliding = false;
                                        _sliderValue = null;
                                        currentPage = value.round();
                                      });
                                      await _renderPages();
                                      await _renderPreview(currentPage);
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  '${(_sliderValue ?? currentPage).round()} / $totalPages',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Preview while sliding
                if (_isSliding && previewImageBytes != null)
                  Positioned(
                    bottom: 90,
                    left: MediaQuery.of(context).size.width / 2 - 80,
                    child: Material(
                      elevation: 8,
                      color: Colors.transparent,
                      child: Container(
                        width: 160,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueAccent, width: 3),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.memory(previewImageBytes!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum DrawingMode {
  pen,
  highlighter,
}

class DrawingPointRelative {
  final Offset relativePoint; // x,y in 0..1 range
  final Paint paint;
  final DateTime time;

  DrawingPointRelative({
    required this.relativePoint,
    required this.paint,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class DrawingPainterRelative extends CustomPainter {
  final List<DrawingPointRelative> drawingPoints;

  DrawingPainterRelative({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (drawingPoints.isEmpty) return;
    
    Path path = Path();
    bool isFirst = true;
    
    for (int i = 0; i < drawingPoints.length; i++) {
      final point = drawingPoints[i];
      final offset = Offset(
        point.relativePoint.dx * size.width,
        point.relativePoint.dy * size.height,
      );
      
      if (isFirst) {
        path.moveTo(offset.dx, offset.dy);
        isFirst = false;
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
      
      // Draw the point itself
      canvas.drawCircle(offset, point.paint.strokeWidth / 2, point.paint);
    }
    
    // Draw the connecting lines
    canvas.drawPath(path, drawingPoints.first.paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}