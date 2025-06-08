import 'package:flutter/material.dart';
import 'package:music_lector/data/enums/drawing_mode.dart';
import 'package:music_lector/data/models/drawing_point.dart';
import 'package:music_lector/data/models/pdf_documents.dart';


class PdfEditorTools extends StatelessWidget {
  final PdfDocumentModel documentModel;
  final List<DrawingPoint> drawingPoints;

  const PdfEditorTools({
    super.key,
    required this.documentModel,
    required this.drawingPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // Tool selector
            Row(
              children: [
                _buildToolButton(
                  icon: Icons.brush,
                  isSelected: documentModel.drawingMode == DrawingMode.pen,
                  onPressed: () => documentModel.setDrawingMode(DrawingMode.pen),
                ),
                _buildToolButton(
                  icon: Icons.highlight,
                  isSelected: documentModel.drawingMode == DrawingMode.highlighter,
                  onPressed: () => documentModel.setDrawingMode(DrawingMode.highlighter),
                ),
              ],
            ),
            
            // Color selector
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                children: [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.black,
                  Colors.purple,
                ].map((color) {
                  return GestureDetector(
                    onTap: () => documentModel.setColor(color),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: documentModel.selectedColor == color 
                              ? Colors.white 
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Stroke width
            Slider(
              value: documentModel.strokeWidth,
              min: 1,
              max: 20,
              onChanged: (value) => documentModel.setStrokeWidth(value),
            ),
            
            // Action buttons
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: documentModel.undoDrawing,
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  color: Colors.green,
                  onPressed: documentModel.saveDrawing,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.red,
                  onPressed: () => documentModel.toggleEditing(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      color: isSelected ? Colors.blue[900] : Colors.grey,
      onPressed: onPressed,
    );
  }
}