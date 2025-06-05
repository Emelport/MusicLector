import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewer extends StatefulWidget {
  final String filePath;
  final bool multipleFiles;
  const PdfViewer(
      {super.key, required this.filePath, this.multipleFiles = false});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> with WidgetsBindingObserver {
  late PdfDocument document;
  List<PdfDocument> documents = [];
  List<MapEntry<int, PdfDocument>> pageMap = []; // index -> document
  int currentPage = 1;
  int totalPages = 0;

  Uint8List? leftImageBytes;
  Uint8List? rightImageBytes;
  Uint8List? previewImageBytes;

  Orientation? _lastOrientation;
  final ValueNotifier<Alignment> alignmentNotifier =
      ValueNotifier(Alignment.topCenter);

  double? _sliderValue;
  bool _isSliding = false;
  int previewPage = 1;

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
      final paths = widget.filePath.split(',').map((e) => e.trim()).toList();
      documents =
          await Future.wait(paths.map((path) => PdfDocument.openFile(path)));

      totalPages = 0;
      pageMap.clear();
      for (final doc in documents) {
        for (int i = 1; i <= doc.pagesCount; i++) {
          pageMap.add(MapEntry(i, doc));
        }
        totalPages += doc.pagesCount;
      }
    } else {
      document = await PdfDocument.openFile(widget.filePath);
      totalPages = document.pagesCount;
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
      });
    }
  }

  Future<void> _renderPreview(int page,
      {double width = 120, double height = 170}) async {
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
      _renderPages();
    }

    if (leftImageBytes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isPortrait = orientation == Orientation.portrait;
    final ValueNotifier<bool> showSliderNotifier = ValueNotifier(false);

    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Listener(
        onPointerHover: (event) {
          if (event.position.dy > screenSize.height - 120) {
            showSliderNotifier.value = true;
          } else if (!_isSliding) {
            showSliderNotifier.value = false;
          }
        },
        onPointerDown: (event) {
          if (event.position.dy > screenSize.height - 120) {
            showSliderNotifier.value = true;
          }
        },
        onPointerUp: (event) {
          if (!_isSliding) {
            showSliderNotifier.value = false;
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _handleTapDown(details, screenSize),
          onPanStart: (details) {
            if (details.localPosition.dy > screenSize.height - 120) {
              showSliderNotifier.value = true;
            }
          },
          onPanEnd: (details) {
            if (!_isSliding) {
              showSliderNotifier.value = false;
            }
          },
          child: Stack(
            children: [
              Center(
                child: isPortrait
                    ? AspectRatio(
                        aspectRatio: 1000 / 1400,
                        child:
                            Image.memory(leftImageBytes!, fit: BoxFit.contain),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                      onPanStart: (_) => alignmentNotifier.value = alignment,
                      onPanUpdate: (details) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final Offset localPosition =
                            box.globalToLocal(details.globalPosition);

                        final double x =
                            (localPosition.dx / box.size.width) * 2 - 1;
                        final double y =
                            (localPosition.dy / box.size.height) * 2 - 1;

                        double snapThreshold = 0.92;
                        double snappedDx = x.clamp(-1.0, 1.0);
                        if (snappedDx <= -snapThreshold)
                          snappedDx = -1.0;
                        else if (snappedDx >= snapThreshold) snappedDx = 1.0;

                        alignmentNotifier.value =
                            Alignment(snappedDx, y.clamp(-1.0, 1.0));
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
                              icon: Icon(Icons.arrow_back,
                                  color: Colors.blue[900]),
                              tooltip: 'Volver',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue[900]),
                              tooltip: 'Editar',
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: Icon(Icons.flag, color: Colors.blue[900]),
                              tooltip: 'Bandera',
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: showSliderNotifier,
                builder: (context, showSlider, child) {
                  if (!showSlider && !_isSliding)
                    return const SizedBox.shrink();
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Container(
                        margin: const EdgeInsets.only(
                            bottom: 24, left: 60, right: 60),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14),
                                  trackShape:
                                      const RoundedRectSliderTrackShape(),
                                  activeTrackColor: Colors.blue[700],
                                  inactiveTrackColor: Colors.blue[100],
                                ),
                                child: Slider(
                                  value: _sliderValue ?? currentPage.toDouble(),
                                  min: 1,
                                  max: totalPages.toDouble(),
                                  divisions:
                                      totalPages > 1 ? totalPages - 1 : 1,
                                  label:
                                      'Página ${(_sliderValue ?? currentPage).round()}',
                                  onChanged: (value) async {
                                    setState(() {
                                      _sliderValue = value;
                                      _isSliding = true;
                                      previewPage = value.round();
                                    });
                                    await _renderPreview(value.round(),
                                        width: 320, height: 440);
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
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
                        child:
                            Image.memory(previewImageBytes!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
