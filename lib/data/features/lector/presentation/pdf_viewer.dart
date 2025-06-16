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
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
              ),

              // Controls
              if (!state.isEditing)
                PdfControls(
                  documentModel: documentModel,
                  alignment: state.toolbarAlignment,
                ),

              // Editor Tools
              if (state.isEditing)
                PdfEditorTools(
                  documentModel: documentModel,
                  drawingPoints: state.drawingPoints,
                ),

              // Page Slider
              if (state.showSlider || state.isSliding)
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
}