import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class PdfEditor extends StatefulWidget {
  final Uint8List pdfImageBytes;
  final Function(Uint8List) onSave;
  final Function onCancel;

  const PdfEditor({
    super.key,
    required this.pdfImageBytes,
    required this.onSave,
    required this.onCancel,
  });

  @override
  _PdfEditorState createState() => _PdfEditorState();
}

class _PdfEditorState extends State<PdfEditor> {
  List<DrawingPoint> drawingPoints = [];
  double strokeWidth = 3.0;
  Color selectedColor = Colors.red;
  DrawingMode drawingMode = DrawingMode.pen;
  List<Uint8List> imageStates = [];
  int currentStateIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Imagen del PDF de fondo
        Image.memory(widget.pdfImageBytes, fit: BoxFit.contain),
        
        // Canvas para dibujar
        CustomPaint(
          painter: DrawingPainter(
            drawingPoints: drawingPoints,
          ),
          child: Container(),
        ),
        
        // Controles de edición
        Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 24, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de herramientas
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolButton(
                      icon: Icons.brush,
                      isSelected: drawingMode == DrawingMode.pen,
                      onPressed: () => setState(() => drawingMode = DrawingMode.pen),
                    ),
                    _buildToolButton(
                      icon: Icons.highlight,
                      isSelected: drawingMode == DrawingMode.highlighter,
                      onPressed: () => setState(() => drawingMode = DrawingMode.highlighter),
                    ),
                    _buildToolButton(
                      icon: Icons.text_fields,
                      isSelected: drawingMode == DrawingMode.text,
                      onPressed: () => setState(() => drawingMode = DrawingMode.text),
                    ),
                  ],
                ),
                
                // Selector de color
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
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color 
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
                
                // Grosor del trazo
                Slider(
                  value: strokeWidth,
                  min: 1,
                  max: 20,
                  onChanged: (value) => setState(() => strokeWidth = value),
                ),
                
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: _undo,
                      color: Colors.blue[900],
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo),
                      onPressed: _redo,
                      color: Colors.blue[900],
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveDrawing,
                      color: Colors.green,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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

  void _undo() {
    if (drawingPoints.isNotEmpty) {
      setState(() {
        drawingPoints.removeLast();
      });
    }
  }

  void _redo() {
    // Implementar lógica de redo si se usa historial de estados
  }

  Future<void> _saveDrawing() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = DrawingPainter(drawingPoints: drawingPoints);
    
    painter.paint(canvas, Size(
      widget.pdfImageBytes.lengthInBytes.toDouble(),
      widget.pdfImageBytes.lengthInBytes.toDouble(),
    ));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(1000, 1000);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List();
    
    if (pngBytes != null) {
      widget.onSave(pngBytes);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

enum DrawingMode {
  pen,
  highlighter,
  text,
  erase,
}

class DrawingPoint {
  final Offset point;
  final Paint paint;
  final DateTime time;

  DrawingPoint({
    required this.point,
    required this.paint,
    required this.time,
  });
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < drawingPoints.length - 1; i++) {
      if (drawingPoints[i + 1] != null) {
        canvas.drawLine(
          drawingPoints[i].point,
          drawingPoints[i + 1].point,
          drawingPoints[i].paint,
        );
      } else if (drawingPoints[i] != null) {
        canvas.drawPoints(
          ui.PointMode.points,
          [drawingPoints[i].point],
          drawingPoints[i].paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}