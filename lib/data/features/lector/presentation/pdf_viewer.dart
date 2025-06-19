import 'package:flutter/material.dart';
import 'package:music_lector/data/features/home/presentation/Library/pdf_list.dart';
import 'package:music_lector/data/models/pdf_documents.dart';
import 'package:music_lector/widgets/page_slider.dart';
import 'package:music_lector/widgets/pdf_controls.dart';
import 'package:music_lector/widgets/pdf_editor.dart';
import 'package:music_lector/widgets/pdf_view.dart';

class PdfViewer extends StatefulWidget {
  final String filePath;
  final bool multipleFiles;
  final int indexStart;
  final int? initialPage; // <-- agrega esto

  const PdfViewer({
    super.key,
    required this.filePath,
    this.multipleFiles = false,
    this.indexStart = -1,
    this.initialPage,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> with WidgetsBindingObserver {
  late PdfDocumentModel documentModel;
  Orientation? _lastOrientation;
  bool _isInitialized = false;
  int? _initialPage;
  String? _errorMessage;
  bool _isBookmarkModalOpen = false;
  bool _wasSliderVisibleBeforeModal = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      // Prioridad: initialPage > lastPage > 1
      int? lastPage = await PdfLastViewed.getLastPage(widget.filePath);
      _initialPage = widget.initialPage ?? lastPage ?? 1;

      documentModel = PdfDocumentModel(
        filePath: widget.filePath,
        multipleFiles: widget.multipleFiles,
        indexStart: widget.indexStart,
      );

      await documentModel.loadPdf(initialPage: _initialPage);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing PDF: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _errorMessage =
              'No se pudo abrir el PDF. Verifica que el archivo exista y no esté dañado.';
        });
      }
    }
  }

  @override
  void dispose() {
    // Guardar la última página vista al salir
    if (_isInitialized) {
      final currentPage = documentModel.stateNotifier.value.currentPage;
      PdfLastViewed.saveLastPage(widget.filePath, currentPage);
      documentModel.dispose();
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final orientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      documentModel.renderPages();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Stack(
          children: [
            Center(
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 18)),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: IconButton(
                icon: const Icon(Icons.close, size: 32, color: Colors.red),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }
    if (!_isInitialized) {
      return Scaffold(
        body: Stack(
          children: [
            const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 24,
              right: 24,
              child: IconButton(
                icon: const Icon(Icons.close, size: 32, color: Colors.red),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<PdfViewerState>(
      valueListenable: documentModel.stateNotifier,
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFEEEEEE),
          body: Stack(
            children: [
              // PDF Page View
              PdfPageView(
                documentModel: documentModel,
                isEditing: state.isEditing,
                onToggleControls: _toggleControls,
              ),

              // Controls
              if (!state.isEditing && _showControls)
                PdfControls(
                  documentModel: documentModel,
                  alignment: state.toolbarAlignment,
                  onOpenBookmarkModal: () async {
                    _wasSliderVisibleBeforeModal =
                        state.showSlider || state.isSliding;
                    setState(() {
                      _isBookmarkModalOpen = true;
                      _showControls = false;
                    });
                    if (state.showSlider) {
                      documentModel.toggleSlider(false);
                    }
                  },
                  onCloseBookmarkModal: () {
                    setState(() {
                      _isBookmarkModalOpen = false;
                      _showControls = true;
                    });
                    documentModel.toggleSlider(true);
                  },
                ),

              // Editor Tools
              if (state.isEditing)
                PdfEditorTools(
                  documentModel: documentModel,
                  drawingPoints: state.drawingPoints,
                  onExitEdit: () {
                    setState(() {
                      _showControls = true;
                    });
                  },
                ),

              // Page Slider
              if (_showControls && !state.isEditing && !_isBookmarkModalOpen)
                PageSlider(
                  pageCount: state.totalPages,
                  currentPage: state.currentPage,
                  previewPage: state.previewPage,
                  isSliding: state.isSliding,
                  showSlider: state.showSlider,
                  previewImageBytes: state.previewImageBytes,
                  onChanged: (value) async {
                    await documentModel.updatePreviewPage(value.round());
                  },
                  onChangeEnd: (value) async {
                    await documentModel.goToPage(value.round());
                  },
                )
            ],
          ),
        );
      },
    );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        documentModel.toggleSlider(true);
      } else {
        documentModel.toggleSlider(false);
      }
    });
  }
}
