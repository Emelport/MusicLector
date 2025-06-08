import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:pdfx/pdfx.dart';
import '../models/drawing_point.dart';

class PdfViewerState {
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

  PdfViewerState({
    this.isLoading = true,
    this.currentPage = 1,
    this.totalPages = 0,
    this.previewPage = 1,
    this.isEditing = false,
    this.showSlider = false,
    this.isSliding = false,
    this.toolbarAlignment = Alignment.topCenter,
    this.previewImageBytes,
    this.drawingPoints = const [],
    this.leftImageBytes,
    this.rightImageBytes,
  });

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

class PdfDocumentModel {
  final String filePath;
  final bool multipleFiles;
  final int indexStart;

  final ValueNotifier<PdfViewerState> stateNotifier =
      ValueNotifier(PdfViewerState());

  late PdfDocument document;
  List<PdfDocument> documents = [];
  List<MapEntry<int, PdfDocument>> pageMap = [];
  Uint8List? leftImageBytes;
  Uint8List? rightImageBytes;
  Uint8List? editedImageBytes;

  // Editor properties
  double strokeWidth = 3.0;
  Color selectedColor = Colors.red;
  DrawingMode drawingMode = DrawingMode.pen;
  List<DrawingPoint> _currentPoints = [];

  PdfDocumentModel({
    required this.filePath,
    required this.multipleFiles,
    required this.indexStart,
  });

  Future<void> loadPdf() async {
    stateNotifier.value = stateNotifier.value.copyWith(isLoading: true);

    try {
      if (multipleFiles) {
        final paths = filePath.split(';|;').map((e) => e.trim()).toList();
        documents = await Future.wait(paths.map((path) => PdfDocument.openFile(path)));

        int totalPages = 0;
        pageMap.clear();
        int pageIndex = 1;
        for (final doc in documents) {
          for (int i = 1; i <= doc.pagesCount; i++) {
            pageMap.add(MapEntry(pageIndex, doc));
            pageIndex++;
          }
          totalPages += doc.pagesCount;
        }

        int startFileIndex = indexStart.clamp(0, documents.length - 1);
        int startPage = 1;
        for (int i = 0; i < startFileIndex; i++) {
          startPage += documents[i].pagesCount;
        }

        stateNotifier.value = stateNotifier.value.copyWith(
          currentPage: startPage,
          totalPages: totalPages,
          isLoading: false,
        );
      } else {
        document = await PdfDocument.openFile(filePath);
        stateNotifier.value = stateNotifier.value.copyWith(
          currentPage: indexStart.clamp(1, document.pagesCount),
          totalPages: document.pagesCount,
          isLoading: false,
        );
      }

      await renderPages();
      await renderPreview(stateNotifier.value.currentPage);
    } catch (e) {
      stateNotifier.value = stateNotifier.value.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<PdfPage> _getPage(int pageNumber) async {
    if (!multipleFiles) return await document.getPage(pageNumber);

    int pageCounted = 0;
    for (final doc in documents) {
      if (pageNumber <= pageCounted + doc.pagesCount) {
        return await doc.getPage(pageNumber - pageCounted);
      }
      pageCounted += doc.pagesCount;
    }
    throw Exception("Page not found");
  }

  Future<void> renderPages() async {
    final currentState = stateNotifier.value;
    final leftPage = await _getPage(currentState.currentPage);
    final leftImage = await leftPage.render(width: 1000, height: 1400);
    await leftPage.close();

    Uint8List? rightBytes;
    if (currentState.currentPage + 1 <= currentState.totalPages) {
      final rightPage = await _getPage(currentState.currentPage + 1);
      final rightImage = await rightPage.render(width: 1000, height: 1400);
      rightBytes = rightImage?.bytes;
      await rightPage.close();
    }

    leftImageBytes = leftImage?.bytes;
    rightImageBytes = rightBytes;

    stateNotifier.value = currentState.copyWith(
      drawingPoints: currentState.isEditing ? currentState.drawingPoints : [],
    );
  }

  Future<void> renderPreview(int page, {double width = 120, double height = 170}) async {
    final previewPage = await _getPage(page);
    final previewImage = await previewPage.render(width: width, height: height);
    await previewPage.close();

    stateNotifier.value = stateNotifier.value.copyWith(
      previewImageBytes: previewImage?.bytes,
    );
  }

  Future<void> nextPage() async {
    final currentState = stateNotifier.value;
    final orientation = MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int step = (orientation == Orientation.portrait) ? 1 : 2;

    if (currentState.currentPage + step <= currentState.totalPages) {
      final newPage = currentState.currentPage + step;
      stateNotifier.value = currentState.copyWith(currentPage: newPage);
      await renderPages();
      await renderPreview(newPage);
    }
  }

  Future<void> previousPage() async {
    final currentState = stateNotifier.value;
    final orientation = MediaQueryData.fromView(WidgetsBinding.instance.window).orientation;
    int step = (orientation == Orientation.portrait) ? 1 : 2;

    final newPage = (currentState.currentPage - step).clamp(1, currentState.totalPages);
    stateNotifier.value = currentState.copyWith(currentPage: newPage);
    await renderPages();
    await renderPreview(newPage);
  }

  Future<void> goToPage(int page) async {
    final currentState = stateNotifier.value;
    final newPage = page.clamp(1, currentState.totalPages);
    stateNotifier.value = currentState.copyWith(
      currentPage: newPage,
      isSliding: false,
    );
    await renderPages();
    await renderPreview(newPage);
  }

  void updateToolbarAlignment(Alignment alignment) {
    stateNotifier.value = stateNotifier.value.copyWith(toolbarAlignment: alignment);
  }

  void toggleSlider(bool show) {
    stateNotifier.value = stateNotifier.value.copyWith(showSlider: show);
  }

  void toggleEditing(bool editing) {
    stateNotifier.value = stateNotifier.value.copyWith(isEditing: editing);
  }

  Future<void> updatePreviewPage(int page) async {
    final clampedPage = page.clamp(1, stateNotifier.value.totalPages);
    
    stateNotifier.value = stateNotifier.value.copyWith(
      previewPage: clampedPage,
      isSliding: true,
    );

    await renderPreview(clampedPage, width: 320, height: 440);
    
    stateNotifier.notifyListeners();
  }

  void startNewDrawingPoint(Offset localPosition, Size size) {
    final point = _createDrawingPoint(localPosition, size);
    _currentPoints = [point];
    stateNotifier.value = stateNotifier.value.copyWith(
      drawingPoints: [...stateNotifier.value.drawingPoints, point],
    );
  }

  void updateDrawingPoint(Offset localPosition, Size size) {
    final point = _createDrawingPoint(localPosition, size);
    _currentPoints.add(point);
    stateNotifier.value = stateNotifier.value.copyWith(
      drawingPoints: [...stateNotifier.value.drawingPoints, point],
    );
  }

  DrawingPoint _createDrawingPoint(Offset localPosition, Size size) {
    final relativePoint = _transformToImageCoords(localPosition, size);
    return DrawingPoint(
      relativePoint: relativePoint,
      paint: Paint()
        ..color = selectedColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  Offset _transformToImageCoords(Offset local, Size size) {
    const imgW = 1000.0;
    const imgH = 1400.0;
    final widgetAspect = size.width / size.height;
    final imgAspect = imgW / imgH;

    double scale, dx = 0, dy = 0;
    if (widgetAspect > imgAspect) {
      // Horizontal letterbox
      scale = size.height / imgH;
      dx = (size.width - imgW * scale) / 2;
    } else {
      // Vertical letterbox
      scale = size.width / imgW;
      dy = (size.height - imgH * scale) / 2;
    }
    final x = ((local.dx - dx) / (imgW * scale)).clamp(0.0, 1.0);
    final y = ((local.dy - dy) / (imgH * scale)).clamp(0.0, 1.0);
    return Offset(x, y);
  }

  void undoDrawing() {
    final currentState = stateNotifier.value;
    if (currentState.drawingPoints.isNotEmpty) {
      final newPoints = List<DrawingPoint>.from(currentState.drawingPoints);
      newPoints.removeLast();
      stateNotifier.value = currentState.copyWith(drawingPoints: newPoints);
    }
  }

  void clearDrawing() {
    stateNotifier.value = stateNotifier.value.copyWith(drawingPoints: []);
  }

  void setDrawingMode(DrawingMode mode) {
    drawingMode = mode;
    selectedColor = mode == DrawingMode.highlighter
        ? selectedColor.withOpacity(0.4)
        : selectedColor.withOpacity(1.0);
  }

  void setStrokeWidth(double width) {
    strokeWidth = width;
  }

  void setColor(Color color) {
    selectedColor = drawingMode == DrawingMode.highlighter
        ? color.withOpacity(0.4)
        : color.withOpacity(1.0);
  }

  Future<void> saveDrawing() async {
    if (leftImageBytes == null) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(1000, 1400);
    
    // Draw background image
    final bgImage = await decodeImageFromList(leftImageBytes!);
    canvas.drawImage(bgImage, Offset.zero, Paint());
    
    // Draw annotations
    final painter = DrawingPainter(drawingPoints: stateNotifier.value.drawingPoints);
    painter.paint(canvas, size);
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();
    
    if (pngBytes != null) {
      editedImageBytes = pngBytes;
      stateNotifier.value = stateNotifier.value.copyWith(
        isEditing: false,
        drawingPoints: [],
      );
    }
  }

  void dispose() {
    for (final doc in documents) {
      doc.close();
    }
    stateNotifier.dispose();
  }
}