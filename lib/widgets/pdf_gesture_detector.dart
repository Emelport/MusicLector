

import 'package:flutter/widgets.dart';
import 'package:music_lector/data/models/pdf_documents.dart';

class PdfGestureDetector extends StatelessWidget {
  final Widget child;
  final PdfDocumentModel documentModel;

  const PdfGestureDetector({
    super.key,
    required this.child,
    required this.documentModel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _handleTapDown(details, context),
      onVerticalDragEnd: (details) => _handleVerticalDragEnd(details),
      child: child,
    );
  }

  void _handleTapDown(TapDownDetails details, BuildContext context) {
    final currentState = documentModel.stateNotifier.value;
    if (currentState.isEditing) return;

    final dy = details.localPosition.dy;
    final height = MediaQuery.of(context).size.height;
    final dx = details.localPosition.dx;
    final width = MediaQuery.of(context).size.width;

    if (dy > height - 120) {
      documentModel.toggleSlider(true);
    } else if (dx > width * 0.75) {
      documentModel.nextPage();
    } else if (dx < width * 0.25) {
      documentModel.previousPage();
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 400) {
      documentModel.toggleSlider(false);
    }
  }
}