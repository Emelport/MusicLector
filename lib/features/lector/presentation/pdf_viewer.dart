import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewer extends StatefulWidget {
  final String filePath;
  const PdfViewer({super.key, required this.filePath});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> with WidgetsBindingObserver {
  late PdfDocument document;
  int currentPage = 1;

  Uint8List? leftImageBytes;
  Uint8List? rightImageBytes;

  Orientation? _lastOrientation;

  final ValueNotifier<Alignment> alignmentNotifier =
      ValueNotifier(Alignment.topCenter);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPdf();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    document = await PdfDocument.openFile(widget.filePath);
    await _renderPages();
  }

  Future<void> _renderPages() async {
    final leftPage = await document.getPage(currentPage);
    final leftImage = await leftPage.render(width: 1000, height: 1400);
    await leftPage.close();

    Uint8List? rightBytes;
    if (currentPage + 1 <= document.pagesCount) {
      final rightPage = await document.getPage(currentPage + 1);
      final rightImage = await rightPage.render(width: 1000, height: 1400);
      rightBytes = rightImage?.bytes;
      await rightPage.close();
    }

    if (mounted) {
      setState(() {
        leftImageBytes = leftImage?.bytes;
        rightImageBytes = rightBytes;
      });
    }
  }

  Future<void> _next() async {
    final orientation = MediaQuery.of(context).orientation;
    int step = (orientation == Orientation.portrait) ? 1 : 2;

    if (currentPage + step <= document.pagesCount) {
      currentPage += step;
      await _renderPages();
    }
  }

  Future<void> _prev() async {
    final orientation = MediaQuery.of(context).orientation;
    int step = (orientation == Orientation.portrait) ? 1 : 2;

    currentPage = (currentPage - step).clamp(1, document.pagesCount);
    await _renderPages();
  }

  void _handleTapDown(TapDownDetails details, Size screenSize) {
    final dx = details.localPosition.dx;
    final width = screenSize.width;

    if (dx > width * 0.75) {
      _next();
    } else if (dx < width * 0.25) {
      _prev();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final Orientation orientation = MediaQuery.of(context).orientation;

    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      // No await para no bloquear build
      _renderPages();
    }

    if (leftImageBytes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPortrait = orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) => _handleTapDown(details, screenSize),
        child: Stack(
          children: [
            Center(
              child: isPortrait
                  ? AspectRatio(
                      aspectRatio: 1000 / 1400,
                      child: Image.memory(leftImageBytes!, fit: BoxFit.contain),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leftImageBytes != null)
                          AspectRatio(
                            aspectRatio: 1000 / 1400,
                            child: Image.memory(leftImageBytes!,
                                fit: BoxFit.contain),
                          ),
                        if (rightImageBytes != null) const SizedBox(width: 4),
                        if (rightImageBytes != null)
                          AspectRatio(
                            aspectRatio: 1000 / 1400,
                            child: Image.memory(rightImageBytes!,
                                fit: BoxFit.contain),
                          ),
                      ],
                    ),
            ),
            ValueListenableBuilder<Alignment>(
              valueListenable: alignmentNotifier,
              builder: (context, alignment, child) {
                return Align(
                  alignment: alignment,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      final dx = (alignment.x +
                              details.delta.dx / (screenSize.width / 2))
                          .clamp(-1.0, 1.0);
                      final dy = (alignment.y +
                              details.delta.dy / (screenSize.height / 2))
                          .clamp(-1.0, 1.0);
                      alignmentNotifier.value = Alignment(dx, dy);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                            icon:
                                Icon(Icons.arrow_back, color: Colors.blue[900]),
                            tooltip: 'Volver',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue[900]),
                            tooltip: 'Editar',
                            onPressed: () {
                              // Acción de editar
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.flag, color: Colors.blue[900]),
                            tooltip: 'Bandera',
                            onPressed: () {
                              // Acción de bandera
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
