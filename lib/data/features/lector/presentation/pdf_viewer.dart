import 'package:flutter/material.dart';
import 'package:music_lector/data/models/pdf_documents.dart';
import 'package:music_lector/widgets/page_slider.dart';
import 'package:music_lector/widgets/pdf_controls.dart';
import 'package:music_lector/widgets/pdf_editor.dart';
import 'package:music_lector/widgets/pdf_view.dart';

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
  late PdfDocumentModel documentModel;
  Orientation? _lastOrientation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    documentModel = PdfDocumentModel(
      filePath: widget.filePath,
      multipleFiles: widget.multipleFiles,
      indexStart: widget.indexStart,
    );
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      await documentModel.loadPdf();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing PDF: $e');
      // Puedes agregar manejo de errores visual aquí
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    documentModel.dispose();
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
