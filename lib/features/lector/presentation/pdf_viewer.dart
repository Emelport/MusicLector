import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewer extends StatelessWidget {
  final String filePath;

  const PdfViewer({Key? key, required this.filePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue[900]),
          tooltip: 'Volver',
          onPressed: () {
            context.pop(); // <-- usa esto en vez de Navigator.of(context).pop()
          },
        ),
        actions: [
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
      body: SfPdfViewer.file(
        File(filePath),
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        interactionMode: PdfInteractionMode.pan,
        enableTextSelection: true,
        initialZoomLevel: 1.0,
        maxZoomLevel: 5.0,
      ),
    );
  }
}
