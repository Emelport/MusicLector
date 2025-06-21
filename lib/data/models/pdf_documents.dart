import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  final List<MapEntry<int, PdfDocument>> _pageMap =
      <MapEntry<int, PdfDocument>>[];

  /// Full‑resolution cache (key = 1‑based page index)
  final Map<int, Uint8List> _pageCache = <int, Uint8List>{};

  /// Low‑resolution preview cache (key = 1‑based page index)
  final Map<int, Uint8List> _previewCache = <int, Uint8List>{};

  /// Edited pages cache – keeps the raster result after drawing so the user
  /// sees instant feedback when revisiting the page.
  final Map<int, Uint8List> _editedCache = <int, Uint8List>{};

  /// Points captured while the user is drawing on the current page
  List<DrawingRect> _currentRects = <DrawingRect>[];

  /// Current drawing tool configuration
  double strokeWidth = 1.0;
  double minStrokeWidth = 1.0;
  double maxStrokeWidth = 1.0;
  Color selectedColor = Colors.red;
  DrawingMode drawingMode = DrawingMode.pen;

  late PdfConfig pdfConfig;
  String get _configPath => '$filePath.config.json';

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
    await _loadConfig();
    _state = _state.copyWith(isLoading: true);

    // 1️⃣ Open document(s) ----------------------------------------------------
    if (multipleFiles) {
      final List<String> paths = filePath
          .split(';|;')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
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
        currentPage:
            initialPage ?? indexStart.clamp(1, _singleDocument.pagesCount),
        totalPages: _singleDocument.pagesCount,
      );
    }

    // 2️⃣ Render first visible page(s) so UI appears immediately -------------
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int left = max(1, _state.currentPage);
    int right =
        orientation == Orientation.landscape && left + 1 <= _state.totalPages
            ? left + 1
            : -1;
    await _renderVisiblePagesCustom(left, right);
    await _renderPreview(_state.currentPage);

    // 3️⃣ Kick‑off background preloading of all pages & previews --------------
    _preloadAllPages(); // un‑awaited on purpose
    _state = _state.copyWith(isLoading: false);
  }

  /// Navigate to the next page (handles portrait/landscape spread logic)
  Future<void> nextPage() async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int minPage = _activeBookmarkFrom ?? 1;
    int maxPage = _activeBookmarkTo ?? _state.totalPages;
    if (orientation == Orientation.landscape) {
      int nextLeft =
          (_state.currentPage + _landscapeStep).clamp(minPage, maxPage);
      if (nextLeft > maxPage) return;
      await _goToPageInternal(nextLeft);
    } else {
      if (_state.currentPage + 1 <= maxPage) {
        await _goToPageInternal(_state.currentPage + 1);
      }
    }
  }

  /// Navigate to the previous page
  Future<void> previousPage() async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int minPage = _activeBookmarkFrom ?? 1;
    int maxPage = _activeBookmarkTo ?? _state.totalPages;
    if (orientation == Orientation.landscape) {
      int prevLeft =
          (_state.currentPage - _landscapeStep).clamp(minPage, maxPage);
      if (prevLeft < minPage) return;
      await _goToPageInternal(prevLeft);
    } else {
      if (_state.currentPage - 1 >= minPage) {
        await _goToPageInternal(_state.currentPage - 1);
      }
    }
  }

  /// Jump directly to page [page]
  Future<void> goToPage(int page) async {
    int minPage = _activeBookmarkFrom ?? 1;
    int maxPage = _activeBookmarkTo ?? _state.totalPages;
    await _goToPageInternal(page.clamp(minPage, maxPage));
  }

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
  void toggleEditing(bool editing) =>
      _state = _state.copyWith(isEditing: editing);

  // -------------------------------------------------------------------------
  // Drawing helpers
  // -------------------------------------------------------------------------

  // Página activa para edición en landscape: 'left' o 'right'
  String activeEditSide = 'left';

  // Al iniciar un trazo, determina la página activa y agrega el nuevo rectángulo a los existentes de esa página
  void startNewDrawingPoint(Offset localPosition, Size size,
      {double? pressure}) {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int leftPage = _state.currentPage;
    int? rightPage = (orientation == Orientation.landscape &&
            leftPage + 1 <= _state.totalPages)
        ? leftPage + 1
        : null;
    // Elimina la lógica de auto-selección, solo usa activeEditSide
    int pageToEdit =
        (activeEditSide == 'right' && rightPage != null) ? rightPage : leftPage;
    final Offset start = _transformToImageCoords(localPosition, size);
    final Paint paint = Paint()
      ..color = selectedColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    _currentRects = <DrawingRect>[
      DrawingRect(start: start, end: start, paint: paint)
    ];
    // Agrega el nuevo rectángulo a los existentes (no borra los anteriores)
    final List<DrawingRect> currentRects =
        List<DrawingRect>.from(_state.drawingPoints);
    currentRects.add(_currentRects.first);
    _state = _state.copyWith(drawingPoints: currentRects);
  }

  void updateDrawingPoint(Offset localPosition, Size size, {double? pressure}) {
    if (_currentRects.isEmpty) return;
    final Offset end = _transformToImageCoords(localPosition, size);
    final DrawingRect last = _currentRects.first;
    final DrawingRect updated =
        DrawingRect(start: last.start, end: end, paint: last.paint);
    final List<DrawingRect> rects =
        List<DrawingRect>.from(_state.drawingPoints as List<DrawingRect>);
    rects[rects.length - 1] = updated;
    _currentRects[0] = updated;
    _state = _state.copyWith(drawingPoints: rects);
  }

  void undoDrawing() {
    if ((_state.drawingPoints as List<DrawingRect>).isNotEmpty) {
      final List<DrawingRect> rects =
          List<DrawingRect>.from(_state.drawingPoints as List<DrawingRect>);
      rects.removeLast();
      _state = _state.copyWith(drawingPoints: rects);
    }
  }

  void clearDrawing() =>
      _state = _state.copyWith(drawingPoints: <DrawingRect>[]);

  void setDrawingMode(DrawingMode mode) {
    drawingMode = mode;
    selectedColor = mode == DrawingMode.highlighter
        ? selectedColor.withOpacity(0.4)
        : selectedColor.withOpacity(1.0);
    stateNotifier.notifyListeners();
  }

  void setStrokeWidth(double width) {
    // No hacer nada, el grosor es fijo
  }

  void setColor(Color color) {
    selectedColor = drawingMode == DrawingMode.highlighter
        ? color.withOpacity(0.4)
        : color.withOpacity(1.0);
    stateNotifier.notifyListeners();
  }

  // Al guardar, actualiza la imagen renderizada con todos los subrayados
  Future<void> saveDrawing() async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int leftPage = _state.currentPage;
    int? rightPage = (orientation == Orientation.landscape &&
            leftPage + 1 <= _state.totalPages)
        ? leftPage + 1
        : null;
    int pageToSave =
        (activeEditSide == 'right' && rightPage != null) ? rightPage : leftPage;
    saveDrawingForPage(pageToSave, _state.drawingPoints as List<DrawingRect>);
    // Limpiar los subrayados en edición y cargar los de la nueva página activa
    int pageToEdit =
        (activeEditSide == 'right' && rightPage != null) ? rightPage : leftPage;
    List<DrawingRect> newRects = getDrawingForPage(pageToEdit);
    _state = _state.copyWith(drawingPoints: newRects);
    await _renderVisiblePagesCustom(leftPage, rightPage ?? -1);
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

  // Al cambiar de página, siempre actualiza la imagen con los subrayados guardados
  Future<void> _goToPageInternal(int page) async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int leftPage = _state.currentPage;
    int? rightPage = (orientation == Orientation.landscape &&
            leftPage + 1 <= _state.totalPages)
        ? leftPage + 1
        : null;
    if (_state.isEditing && _state.drawingPoints.isNotEmpty) {
      int pageToSave = (activeEditSide == 'right' && rightPage != null)
          ? rightPage
          : leftPage;
      saveDrawingForPage(pageToSave, _state.drawingPoints as List<DrawingRect>);
    }
    int minPage = _activeBookmarkFrom ?? 1;
    int maxPage = _activeBookmarkTo ?? _state.totalPages;
    int left = max(1, page.clamp(minPage, maxPage));
    int right =
        orientation == Orientation.landscape && left < maxPage ? left + 1 : -1;
    activeEditSide = 'left';
    List<DrawingRect> drawingRects = getDrawingForPage(left);
    _state = _state.copyWith(
      currentPage: left,
      previewPage: left,
      isSliding: false,
      drawingPoints: drawingRects,
    );
    await _renderVisiblePagesCustom(left, right);
    await _renderPreview(left);
  }

  Future<void> _renderVisiblePagesCustom(int leftIndex, int rightIndex) async {
    // Validación defensiva: nunca renderizar páginas menores a 1
    if (leftIndex < 1) {
      print('Intento de renderizar leftIndex inválido: $leftIndex');
      return;
    }
    // Left
    if (!_pageCache.containsKey(leftIndex)) {
      _pageCache[leftIndex] = await _renderPage(leftIndex);
    }
    // Right (opcional)
    Uint8List? rightBytes;
    if (rightIndex != -1 &&
        rightIndex != leftIndex &&
        rightIndex >= 1 &&
        rightIndex <= (_activeBookmarkTo ?? _state.totalPages)) {
      if (!_pageCache.containsKey(rightIndex)) {
        _pageCache[rightIndex] = await _renderPage(rightIndex);
      }
      rightBytes = _editedCache[rightIndex] ?? _pageCache[rightIndex];
    } else {
      rightBytes = null;
    }
    final Uint8List? leftBytes =
        _editedCache[leftIndex] ?? _pageCache[leftIndex];

    // --- CORRECCIÓN DE PREVISUALIZACIÓN EN EDICIÓN ---
    if (_state.isEditing) {
      // Solo la página activa muestra los subrayados actuales
      int pageToEdit = leftIndex;
      if (activeEditSide == 'right' && rightIndex != -1) {
        pageToEdit = rightIndex;
      }
      final leftRects = (pageToEdit == leftIndex)
          ? _state.drawingPoints
          : getDrawingForPage(leftIndex);
      final rightRects = (pageToEdit == rightIndex)
          ? _state.drawingPoints
          : getDrawingForPage(rightIndex);
      final leftImageWithRects =
          await _overlayRectsOnImage(leftBytes, leftRects);
      Uint8List? rightImageWithRects;
      if (rightBytes != null) {
        rightImageWithRects =
            await _overlayRectsOnImage(rightBytes, rightRects);
      }
      _state = _state.copyWith(
        leftImageBytes: leftImageWithRects,
        rightImageBytes: rightImageWithRects,
      );
      return;
    }
    // Render normal (subrayados guardados)
    final leftRects = getDrawingForPage(leftIndex);
    final rightRects =
        rightIndex != -1 ? getDrawingForPage(rightIndex) : <DrawingRect>[];
    final leftImageWithRects = await _overlayRectsOnImage(leftBytes, leftRects);
    Uint8List? rightImageWithRects;
    if (rightBytes != null) {
      rightImageWithRects = await _overlayRectsOnImage(rightBytes, rightRects);
    }
    _state = _state.copyWith(
      leftImageBytes: leftImageWithRects,
      rightImageBytes: rightImageWithRects,
    );
  }

  // Helper para superponer los subrayados sobre la imagen de la página
  Future<Uint8List> _overlayRectsOnImage(
      Uint8List? baseBytes, List<DrawingRect> rects) async {
    if (baseBytes == null) return Uint8List(0);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    const Size size = Size(1000, 1400);
    final ui.Image base = await decodeImageFromList(baseBytes);
    canvas.drawImage(base, Offset.zero, Paint());
    final DrawingPainter painter = DrawingPainter(rects: rects);
    painter.paint(canvas, size);
    final ui.Picture pic = recorder.endRecording();
    final ui.Image img =
        await pic.toImage(size.width.toInt(), size.height.toInt());
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return baseBytes;
    return data.buffer.asUint8List();
  }

  /// Force re-render of the current visible page(s) – useful after orientation change
  Future<void> renderPages() async {
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int left = max(1, _state.currentPage);
    int right =
        orientation == Orientation.landscape && left + 1 <= _state.totalPages
            ? left + 1
            : -1;
    await _renderVisiblePagesCustom(left, right);
  }

  Future<void> _renderPreview(int page,
      {double width = 120, double height = 170}) async {
    if (_previewCache.containsKey(page)) {
      _state = _state.copyWith(previewImageBytes: _previewCache[page]);
      return;
    }

    final Uint8List bytes =
        await _renderPage(page, width: width.toInt(), height: height.toInt());
    _previewCache[page] = bytes;
    _state = _state.copyWith(previewImageBytes: bytes);
  }

  Future<Uint8List> _renderPage(int page,
      {int width = 1000, int height = 1400}) async {
    if (page < 1 || page > _state.totalPages) {
      print(
          'Intento de renderizar página inválida: $page (rango válido: 1..${_state.totalPages})');
      throw Exception('Número de página fuera de rango: $page');
    }
    final PdfPage p = await _getPage(page);
    final PdfPageImage? img =
        await p.render(width: width.toDouble(), height: height.toDouble());
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

  // Marcadores
  List<PdfBookmark> get bookmarks => pdfConfig.bookmarks;
  void addBookmark(String name, int page) {
    addBookmarkWithRange(name, page, page);
  }

  void removeBookmark(int index) {
    pdfConfig.bookmarks.removeAt(index);
    saveConfig();
    stateNotifier.notifyListeners();
  }

  void renameBookmark(int index, String newName) {
    pdfConfig.bookmarks[index] = PdfBookmark(
        name: newName,
        fromPage: pdfConfig.bookmarks[index].fromPage,
        toPage: pdfConfig.bookmarks[index].toPage);
    saveConfig();
    stateNotifier.notifyListeners();
  }

  Future<void> goToBookmark(int index) async {
    final b = pdfConfig.bookmarks[index];
    _activeBookmarkFrom = b.fromPage;
    _activeBookmarkTo = b.toPage;
    final Orientation orientation =
        MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    if (orientation == Orientation.landscape && b.fromPage < b.toPage) {
      // Mostrar par inicial (fromPage, fromPage+1) si ambos están en rango
      await goToPage(b.fromPage);
    } else {
      await goToPage(b.fromPage);
    }
  }

  // Dibujos por página
  void saveDrawingForPage(int page, List<DrawingRect> rects) {
    pdfConfig.drawings[page] = rects;
    saveC();
  }

  List<DrawingRect> getDrawingForPage(int page) {
    return (pdfConfig.drawings[page] as List<DrawingRect>?) ?? [];
  }

  int? _activeBookmarkFrom;
  int? _activeBookmarkTo;

  void addBookmarkWithRange(String name, int from, int to) {
    pdfConfig.bookmarks
        .add(PdfBookmark(name: name, fromPage: from, toPage: to));
    saveConfig();
    stateNotifier.notifyListeners();
  }

  void clearBookmarkLimits() {
    _activeBookmarkFrom = null;
    _activeBookmarkTo = null;
  }

  int? get activeBookmarkFrom => _activeBookmarkFrom;
  int? get activeBookmarkTo => _activeBookmarkTo;

  int _landscapeStep = 1; // 1: avanzar de 1 en 1, 2: de 2 en 2
  void setLandscapeStep(int step) {
    _landscapeStep = step;
  }

  // Carga la configuración del PDF (bookmarks y dibujos)
  Future<void> _loadConfig() async {
    final file = File(_configPath);
    if (await file.exists()) {
      final jsonStr = await file.readAsString();
      pdfConfig = PdfConfig.fromJson(json.decode(jsonStr));
    } else {
      pdfConfig = PdfConfig(bookmarks: [], drawings: {});
    }
  }

  // Guarda la configuración (bookmarks y dibujos)
  void saveConfig() {
    final file = File(_configPath);
    file.writeAsStringSync(json.encode(pdfConfig.toJson()));
  }

  // Alias para compatibilidad
  void saveC() => saveConfig();

  // Convierte la posición local a coordenadas relativas (0..1)
  Offset _transformToImageCoords(Offset local, Size size) {
    return Offset(local.dx / size.width, local.dy / size.height);
  }
}

// -----------------------------------------------------------------------------
// Immutable UI state – kept intentionally lean to avoid rebuilding too much UI
// -----------------------------------------------------------------------------

class PdfViewerState {
  const PdfViewerState({
    this.isLoading = true,
    int currentPage = 1,
    int totalPages = 0,
    int previewPage = 1,
    this.isEditing = false,
    this.showSlider = false,
    this.isSliding = false,
    this.toolbarAlignment = Alignment.topCenter,
    this.previewImageBytes,
    this.drawingPoints = const <DrawingRect>[],
    this.leftImageBytes,
    this.rightImageBytes,
  })  : currentPage = currentPage < 1 ? 1 : currentPage,
        totalPages = totalPages,
        previewPage = previewPage < 1 ? 1 : previewPage;

  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final int previewPage;
  final bool isEditing;
  final bool showSlider;
  final bool isSliding;
  final Alignment toolbarAlignment;
  final Uint8List? previewImageBytes;
  final List<DrawingRect> drawingPoints;
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
    List<DrawingRect>? drawingPoints,
    Uint8List? leftImageBytes,
    Uint8List? rightImageBytes,
  }) {
    return PdfViewerState(
      isLoading: isLoading ?? this.isLoading,
      currentPage: (currentPage ?? this.currentPage) < 1
          ? 1
          : (currentPage ?? this.currentPage),
      totalPages: totalPages ?? this.totalPages,
      previewPage: (previewPage ?? this.previewPage) < 1
          ? 1
          : (previewPage ?? this.previewPage),
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

class PdfBookmark {
  final String name;
  final int fromPage;
  final int toPage;
  PdfBookmark(
      {required this.name, required this.fromPage, required this.toPage});

  Map<String, dynamic> toJson() =>
      {'name': name, 'fromPage': fromPage, 'toPage': toPage};
  factory PdfBookmark.fromJson(Map<String, dynamic> json) => PdfBookmark(
        name: json['name'],
        fromPage: json['fromPage'] ?? json['page'],
        toPage: json['toPage'] ?? json['page'],
      );
}

class PdfConfig {
  List<PdfBookmark> bookmarks;
  Map<int, List<DrawingRect>> drawings;

  PdfConfig({required this.bookmarks, required this.drawings});

  Map<String, dynamic> toJson() => {
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'drawings': drawings.map((k, v) =>
            MapEntry(k.toString(), v.map((p) => p.toJson()).toList())),
      };

  factory PdfConfig.fromJson(Map<String, dynamic> json) => PdfConfig(
        bookmarks: (json['bookmarks'] as List)
            .map((b) => PdfBookmark.fromJson(b))
            .toList(),
        drawings: (json['drawings'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k),
              (v as List).map((p) => DrawingRect.fromJson(p)).toList()),
        ),
      );
}
