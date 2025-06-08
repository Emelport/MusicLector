import 'package:flutter/material.dart';
import 'package:music_lector/data/models/pdf_documents.dart';

class PdfControls extends StatelessWidget {
  final PdfDocumentModel documentModel;
  final Alignment alignment;

  const PdfControls({
    super.key,
    required this.documentModel,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        onPanUpdate: (details) => _handleToolbarDrag(details, context),
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
                onPressed: () => documentModel.toggleEditing(true),
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
  }

  void _handleToolbarDrag(DragUpdateDetails details, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double x = (localPosition.dx / box.size.width) * 2 - 1;
    final double y = (localPosition.dy / box.size.height) * 2 - 1;

    double snapThreshold = 0.92;
    double snappedDx = x.clamp(-1.0, 1.0);
    if (snappedDx <= -snapThreshold) snappedDx = -1.0;
    else if (snappedDx >= snapThreshold) snappedDx = 1.0;

    documentModel.updateToolbarAlignment(Alignment(snappedDx, y.clamp(-1.0, 1.0)));
  }
}