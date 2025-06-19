import 'package:flutter/material.dart';
import 'package:music_lector/data/models/drawing_point.dart';
import 'package:music_lector/data/models/pdf_documents.dart';

class PdfEditorTools extends StatelessWidget {
  final PdfDocumentModel documentModel;
  final List<DrawingPoint> drawingPoints;
  final VoidCallback? onExitEdit;

  const PdfEditorTools({
    super.key,
    required this.documentModel,
    required this.drawingPoints,
    this.onExitEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: ValueListenableBuilder(
        valueListenable: documentModel.stateNotifier,
        builder: (context, _, __) {
          final selectedColor = _normalizeColorOpacity(
            documentModel.selectedColor,
            documentModel.drawingMode,
          );

          return Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.97),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tool selector
                    Row(
                      children: [
                        _buildToolButton(
                          icon: Icons.brush,
                          isSelected:
                              documentModel.drawingMode == DrawingMode.pen,
                          onPressed: () {
                            documentModel.setDrawingMode(DrawingMode.pen);
                            documentModel.stateNotifier.notifyListeners();
                          },
                          tooltip: "Lápiz",
                        ),
                        _buildToolButton(
                          icon: Icons.highlight,
                          isSelected: documentModel.drawingMode ==
                              DrawingMode.highlighter,
                          onPressed: () {
                            documentModel
                                .setDrawingMode(DrawingMode.highlighter);
                            documentModel.stateNotifier.notifyListeners();
                          },
                          tooltip: "Resaltador",
                        ),
                        _buildToolButton(
                          icon: Icons.auto_fix_high,
                          isSelected:
                              documentModel.drawingMode == DrawingMode.eraser,
                          onPressed: () {
                            documentModel.setDrawingMode(DrawingMode.eraser);
                            documentModel.stateNotifier.notifyListeners();
                          },
                          tooltip: "Borrador",
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Color selector
                    Row(
                      children: [
                        ...[
                          Colors.red,
                          Colors.blue,
                          Colors.green,
                          Colors.yellow,
                          Colors.black,
                          Colors.purple,
                          Colors.orange,
                          Colors.brown,
                        ].map((color) {
                          final normalized = _normalizeColorOpacity(
                              color, documentModel.drawingMode);
                          final isSelected = normalized == selectedColor;

                          return Tooltip(
                            message: _getColorName(color),
                            child: GestureDetector(
                              onTap: () {
                                documentModel.setColor(color);
                                documentModel.stateNotifier.notifyListeners();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: isSelected ? 36 : 24,
                                height: isSelected ? 36 : 24,
                                decoration: BoxDecoration(
                                  color: documentModel.drawingMode ==
                                          DrawingMode.eraser
                                      ? Colors.grey
                                      : normalized,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue.shade900
                                        : Colors.grey.shade300,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Icon(
                                          documentModel.drawingMode ==
                                                  DrawingMode.eraser
                                              ? Icons.auto_fix_high
                                              : Icons.check,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Stroke width
                    SizedBox(
                      width: 150,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Grosor: ${documentModel.strokeWidth.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Slider(
                            value: documentModel.strokeWidth,
                            min: 1,
                            max: 50,
                            divisions: 49,
                            onChanged: (value) {
                              documentModel.setStrokeWidth(value);
                              documentModel.stateNotifier.notifyListeners();
                            },
                            activeColor:
                                documentModel.drawingMode == DrawingMode.eraser
                                    ? Colors.grey
                                    : Colors.blue.shade900,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Action buttons
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.undo),
                          tooltip: "Deshacer",
                          onPressed: drawingPoints.isNotEmpty
                              ? () {
                                  documentModel.undoDrawing();
                                  documentModel.stateNotifier.notifyListeners();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: "Limpiar",
                          onPressed: drawingPoints.isNotEmpty
                              ? () {
                                  documentModel.clearDrawing();
                                  documentModel.stateNotifier.notifyListeners();
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.save),
                          color: Colors.green,
                          tooltip: "Guardar",
                          onPressed: () async {
                            await documentModel.saveDrawing();
                            if (onExitEdit != null) onExitEdit!();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Colors.red,
                          tooltip: "Cerrar",
                          onPressed: () {
                            documentModel.toggleEditing(false);
                            if (onExitEdit != null) onExitEdit!();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade900 : Colors.transparent,
            width: 2,
          ),
        ),
        child: IconButton(
          icon: Icon(icon),
          color: isSelected ? Colors.blue[900] : Colors.grey,
          onPressed: onPressed,
        ),
      ),
    );
  }

  Color _normalizeColorOpacity(Color color, DrawingMode mode) {
    return mode == DrawingMode.highlighter
        ? color.withOpacity(0.4)
        : color.withOpacity(1.0);
  }

  String _getColorName(Color color) {
    if (color == Colors.red) return "Rojo";
    if (color == Colors.blue) return "Azul";
    if (color == Colors.green) return "Verde";
    if (color == Colors.yellow) return "Amarillo";
    if (color == Colors.black) return "Negro";
    if (color == Colors.purple) return "Morado";
    if (color == Colors.orange) return "Naranja";
    if (color == Colors.brown) return "Marrón";
    return "Color";
  }
}
