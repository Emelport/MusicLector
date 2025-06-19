import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:music_lector/data/models/drawing_point.dart';
import 'package:pdfx/pdfx.dart';

/// Drawing tools
enum DrawingMode { pen, highlighter, eraser }

/// Centralised model that manages one or several PDF documents, navigation,
/// full‑size page cache, preview cache and drawing/annotation state.
class PdfDocumentModel {
  /// Constructor ---------------------------------------------------------------
  PdfDocumentModel({
    required this.filePath,
    this.multipleFiles = false,
    this.indexStart = 1,
  });

  /// ------------------------------------------------------------------------
  /// Public immutable configuration
  /// ------------------------------------------------------------------------
  final String filePath; // Concatenated paths when [multipleFiles] == true
  final bool multipleFiles; // Treats [filePath] as semicolon‑separated list
  final int indexStart; // 1‑based page to open initially (global index)

  /// ------------------------------------------------------------------------
  /// Reactive state (read‑only for UI) – wrapped in a [ValueNotifier]
  /// ------------------------------------------------------------------------
  final ValueNotifier<PdfViewerState> stateNotifier =
      ValueNotifier<PdfViewerState>(const PdfViewerState());

  /// ------------------------------------------------------------------------
  /// Private runtime fields
  /// ------------------------------------------------------------------------
  late PdfDocument _singleDocument; // Used when !multipleFiles
  final List<PdfDocument> _documents = <PdfDocument>[]; // Used when multiple

  /// Global page‑to‑document map when multiple files are open. Each entry maps
  /// the global page index (1‑N) to its owning [PdfDocument].
  final List<MapEntry<int, PdfDocument>> _pageMap = <MapEntry<int, PdfDocument>>[];

  /// Full‑resolution cache (key = 1‑based page index)
  final Map<int, Uint8List> _pageCache = <int, Uint8List>{};

  /// Low‑resolution preview cache (key = 1‑based page index)
  final Map<int, Uint8List> _previewCache = <int, Uint8List>{};

  /// Edited pages cache – keeps the raster result after drawing so the user
  /// sees instant feedback when revisiting the page.
  final Map<int, Uint8List> _editedCache = <int, Uint8List>{};

  /// Points captured while the user is drawing on the current page
  List<DrawingPoint> _currentPoints = <DrawingPoint>[];

  /// Current drawing tool configuration
  double strokeWidth = 3.0;
  double minStrokeWidth = 1.0;
  double maxStrokeWidth = 50.0;
  Color selectedColor = Colors.red;
  DrawingMode drawingMode = DrawingMode.pen;

  /// Convenience getters ------------------------------------------------------

  PdfViewerState get _state => stateNotifier.value;
  set _state(PdfViewerState value) => stateNotifier.value = value;

  /// ------------------------------------------------------------------------
  /// Public API
  /// ------------------------------------------------------------------------

  /// Update toolbar alignment (used for draggable controls)
  void updateToolbarAlignment(Alignment alignment) {
    _state = _state.copyWith(toolbarAlignment: alignment);
  }

  Future<void> loadPdf({int? initialPage}) async {
    _state = _state.copyWith(isLoading: true);

    // 1️⃣ Open document(s) ----------------------------------------------------
    if (multipleFiles) {
      final List<String> paths =
          filePath.split(';|;').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      _documents.clear();
      _documents.addAll(await Future.wait(paths.map(PdfDocument.openFile)));

      // Build page map and total page count
      int pagePointer = 1;
      for (final PdfDocument doc in _documents) {
        for (int i = 1; i <= doc.pagesCount; ++i) {
          _pageMap.add(MapEntry<int, PdfDocument>(pagePointer, doc));
          ++pagePointer;
        }
      }
      _state = _state.copyWith(
        currentPage: initialPage ?? indexStart.clamp(1, pagePointer - 1),
        totalPages: pagePointer - 1,
      );
    } else {
      _singleDocument = await PdfDocument.openFile(filePath);
      _state = _state.copyWith(
        currentPage: initialPage ?? indexStart.clamp(1, _singleDocument.pagesCount),
        totalPages: _singleDocument.pagesCount,
      );
    }

    // 2️⃣ Render first visible page(s) so UI appears immediately -------------
    await _renderVisiblePages();
    await _renderPreview(_state.currentPage);

    // 3️⃣ Kick‑off background preloading of all pages & previews --------------
    _preloadAllPages(); // un‑awaited on purpose
    _state = _state.copyWith(isLoading: false);
  }

  /// Navigate to the next page (handles portrait/landscape spread logic)
  Future<void> nextPage() async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    final int step = orientation == Orientation.portrait ? 1 : 2;

    if (_state.currentPage + step <= _state.totalPages) {
      await _goToPageInternal(_state.currentPage + step);
    }
  }

  /// Navigate to the previous page
  Future<void> previousPage() async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    final int step = orientation == Orientation.portrait ? 1 : 2;

    await _goToPageInternal((_state.currentPage - step).clamp(1, _state.totalPages));
  }

  /// Jump directly to page [page]
  Future<void> goToPage(int page) async => _goToPageInternal(page.clamp(1, _state.totalPages));

  /// Updates preview page index while the user is sliding the tooltip slider
  Future<void> updatePreviewPage(int page) async {
    final int clamped = page.clamp(1, _state.totalPages);
    _state = _state.copyWith(previewPage: clamped, isSliding: true);

    if (_previewCache.containsKey(clamped)) {
      _state = _state.copyWith(previewImageBytes: _previewCache[clamped]);
    } else {
      await _renderPreview(clamped, width: 320, height: 440);
    }
  }

  /// Toggle the tooltip slider
  void toggleSlider(bool show) => _state = _state.copyWith(showSlider: show);

  /// Toggle editing mode (drawing)
  void toggleEditing(bool editing) => _state = _state.copyWith(isEditing: editing);

  // -------------------------------------------------------------------------
  // Drawing helpers
  // -------------------------------------------------------------------------

  void startNewDrawingPoint(Offset localPosition, Size size, {double? pressure}) {
    final DrawingPoint p = _createDrawingPoint(localPosition, size, pressure: pressure);
    _currentPoints = <DrawingPoint>[p];
    _state = _state.copyWith(drawingPoints: <DrawingPoint>[..._state.drawingPoints, p]);
  }

  void updateDrawingPoint(Offset localPosition, Size size, {double? pressure}) {
    final DrawingPoint p = _createDrawingPoint(localPosition, size, pressure: pressure);
    _currentPoints.add(p);
    _state = _state.copyWith(drawingPoints: <DrawingPoint>[..._state.drawingPoints, p]);
  }

  void undoDrawing() {
    if (_state.drawingPoints.isNotEmpty) {
      final List<DrawingPoint> pts = List<DrawingPoint>.from(_state.drawingPoints)..removeLast();
      _state = _state.copyWith(drawingPoints: pts);
    }
  }

  void clearDrawing() => _state = _state.copyWith(drawingPoints: <DrawingPoint>[]);

  void setDrawingMode(DrawingMode mode) {
    drawingMode = mode;
    selectedColor = mode == DrawingMode.highlighter
        ? selectedColor.withOpacity(0.4)
        : selectedColor.withOpacity(1.0);
    stateNotifier.notifyListeners();
  }

  void setStrokeWidth(double width) {
    strokeWidth = width.clamp(minStrokeWidth, maxStrokeWidth);
    stateNotifier.notifyListeners();
  }

  void setColor(Color color) {
    selectedColor = drawingMode == DrawingMode.highlighter
        ? color.withOpacity(0.4)
        : color.withOpacity(1.0);
    stateNotifier.notifyListeners();
  }

  /// Permanently rasterise current page drawing into a PNG and cache it
  Future<void> saveDrawing() async {
    if (!_pageCache.containsKey(_state.currentPage)) return;

    // Merge original page bitmap with drawing overlay
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Size size = Size(1000, 1400);

    // Original page
    final ui.Image base = await decodeImageFromList(_pageCache[_state.currentPage]!);
    canvas.drawImage(base, Offset.zero, Paint());

    // Annotations
    final DrawingPainter painter = DrawingPainter(drawingPoints: _state.drawingPoints);
    painter.paint(canvas, size);

    final ui.Picture pic = recorder.endRecording();
    final ui.Image img = await pic.toImage(size.width.toInt(), size.height.toInt());
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;

    final Uint8List png = data.buffer.asUint8List();
    _editedCache[_state.currentPage] = png;
    _pageCache[_state.currentPage] = png; // overwrite cache so navigation is instant

    _state = _state.copyWith(isEditing: false, drawingPoints: <DrawingPoint>[]);
  }

  /// Dispose resources
  void dispose() {
    if (multipleFiles) {
      for (final PdfDocument doc in _documents) doc.close();
    } else {
      _singleDocument.close();
    }
    stateNotifier.dispose();
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Future<void> _goToPageInternal(int page) async {
    // Auto‑save drawing if user forgets
    if (_state.isEditing && _state.drawingPoints.isNotEmpty) {
      await saveDrawing();
    }

    _state = _state.copyWith(currentPage: page, previewPage: page, isSliding: false);
    await _renderVisiblePages();
    await _renderPreview(page);
  }

  Future<void> _renderVisiblePages() async {
    final int leftIndex = _state.currentPage;
    final int rightIndex = leftIndex + 1 <= _state.totalPages ? leftIndex + 1 : -1;

    // Left
    if (!_pageCache.containsKey(leftIndex)) {
      _pageCache[leftIndex] = await _renderPage(leftIndex);
    }

    // Right (optional)
    if (rightIndex != -1 && !_pageCache.containsKey(rightIndex)) {
      _pageCache[rightIndex] = await _renderPage(rightIndex);
    }

    // Extract edited version if available
    final Uint8List? leftBytes = _editedCache[leftIndex] ?? _pageCache[leftIndex];
    final Uint8List? rightBytes = rightIndex != -1
        ? _editedCache[rightIndex] ?? _pageCache[rightIndex]
        : null;

    _state = _state.copyWith(
      leftImageBytes: leftBytes,
      rightImageBytes: rightBytes,
    );
  }

  /// Force re-render of the current visible page(s) – useful after orientation change
  Future<void> renderPages() async => _renderVisiblePages();


  Future<void> _renderPreview(int page, {double width = 120, double height = 170}) async {
    if (_previewCache.containsKey(page)) {
      _state = _state.copyWith(previewImageBytes: _previewCache[page]);
      return;
    }

    final Uint8List bytes = await _renderPage(page, width: width.toInt(), height: height.toInt());
    _previewCache[page] = bytes;
    _state = _state.copyWith(previewImageBytes: bytes);
  }

  Future<Uint8List> _renderPage(int page, {int width = 1000, int height = 1400}) async {
    final PdfPage p = await _getPage(page);
    final PdfPageImage? img = await p.render(width: width.toDouble(), height: height.toDouble());
    await p.close();
    return img!.bytes;
  }

  Future<PdfPage> _getPage(int pageNumber) async {
    if (!multipleFiles) return _singleDocument.getPage(pageNumber);

    int counted = 0;
    for (final PdfDocument doc in _documents) {
      if (pageNumber <= counted + doc.pagesCount) {
        return doc.getPage(pageNumber - counted);
      }
      counted += doc.pagesCount;
    }
    throw Exception('Page not found');
  }

  /// Background task that renders **all** pages and previews sequentially.
  /// This guarantees zero latency when the user navigates after initial load.
  Future<void> _preloadAllPages() async {
    for (int i = 1; i <= _state.totalPages; ++i) {
      if (!_pageCache.containsKey(i)) {
        _pageCache[i] = await _renderPage(i);
      }
      if (!_previewCache.containsKey(i)) {
        _previewCache[i] = await _renderPage(i, width: 120, height: 170);
      }

      // Optionally, yield to event‑loop every few pages to keep UI fluid.
      if (i % 4 == 0) await Future<void>.delayed(Duration.zero);
    }
  }

  // -------------------------------------------------------------------------
  // Helper: drawing point creation & coordinate transform
  // -------------------------------------------------------------------------

  DrawingPoint _createDrawingPoint(Offset local, Size size, {double? pressure}) {
    final Offset relative = _transformToImageCoords(local, size);
    final double p = pressure ?? 1.0;
    final double widthFactor = drawingMode == DrawingMode.eraser ? 0.8 : 1.0;

    return DrawingPoint(
      relativePoint: relative,
      paint: Paint()
        ..color = selectedColor
        ..strokeWidth = _calculateStrokeWidth(p) * widthFactor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  double _calculateStrokeWidth(double pressure) {
    final double adj = pressure.clamp(0.1, 1.0);
    return minStrokeWidth + (strokeWidth - minStrokeWidth) * (adj * adj);
  }

  Offset _transformToImageCoords(Offset local, Size size) {
    const double imgW = 1000.0;
    const double imgH = 1400.0;
    final double widgetAspect = size.width / size.height;
    final double imgAspect = imgW / imgH;

    double scale, dx = 0, dy = 0;
    if (widgetAspect > imgAspect) {
      scale = size.height / imgH;
      dx = (size.width - imgW * scale) / 2;
    } else {
      scale = size.width / imgW;
      dy = (size.height - imgH * scale) / 2;
    }
    final double x = ((local.dx - dx) / (imgW * scale)).clamp(0.0, 1.0);
    final double y = ((local.dy - dy) / (imgH * scale)).clamp(0.0, 1.0);
    return Offset(x, y);
  }
}



// -----------------------------------------------------------------------------
// Immutable UI state – kept intentionally lean to avoid rebuilding too much UI
// -----------------------------------------------------------------------------

class PdfViewerState {
  const PdfViewerState({
    this.isLoading = true,
    this.currentPage = 1,
    this.totalPages = 0,
    this.previewPage = 1,
    this.isEditing = false,
    this.showSlider = false,
    this.isSliding = false,
    this.toolbarAlignment = Alignment.topCenter,
    this.previewImageBytes,
    this.drawingPoints = const <DrawingPoint>[],
    this.leftImageBytes,
    this.rightImageBytes,
  });

  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final int previewPage;
  final bool isEditing;
  final bool showSlider;
  final bool isSliding;
  final Alignment toolbarAlignment;
  final Uint8List? previewImageBytes;
  final List<DrawingPoint> drawingPoints;
  final Uint8List? leftImageBytes;
  final Uint8List? rightImageBytes;

  PdfViewerState copyWith({
    bool? isLoading,
    int? currentPage,
    int? totalPages,
    int? previewPage,
    bool? isEditing,
    bool? showSlider,
    bool? isSliding,
    Alignment? toolbarAlignment,
    Uint8List? previewImageBytes,
    List<DrawingPoint>? drawingPoints,
    Uint8List? leftImageBytes,
    Uint8List? rightImageBytes,
  }) {
    return PdfViewerState(
      isLoading: isLoading ?? this.isLoading,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      previewPage: previewPage ?? this.previewPage,
      isEditing: isEditing ?? this.isEditing,
      showSlider: showSlider ?? this.showSlider,
      isSliding: isSliding ?? this.isSliding,
      toolbarAlignment: toolbarAlignment ?? this.toolbarAlignment,
      previewImageBytes: previewImageBytes ?? this.previewImageBytes,
      drawingPoints: drawingPoints ?? this.drawingPoints,
      leftImageBytes: leftImageBytes ?? this.leftImageBytes,
      rightImageBytes: rightImageBytes ?? this.rightImageBytes,
    );
  }
}
