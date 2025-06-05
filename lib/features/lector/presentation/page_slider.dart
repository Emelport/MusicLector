import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PageSlider extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final Future<Uint8List?> Function(int page) renderPreviewImage;
  final void Function(int newPage) onPageChanged;

  const PageSlider({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.renderPreviewImage,
    required this.onPageChanged,
  });

  @override
  State<PageSlider> createState() => _PageSliderState();
}

class _PageSliderState extends State<PageSlider> {
  double? _sliderValue;
  bool _isSliding = false;
  Uint8List? _previewImageBytes;

  @override
  Widget build(BuildContext context) {
    final double value = _sliderValue ?? widget.currentPage.toDouble();

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24, left: 60, right: 60),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  if (_previewImageBytes != null && !_isSliding)
                    Container(
                      width: 48,
                      height: 68,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Image.memory(_previewImageBytes!, fit: BoxFit.cover),
                    ),
                  Flexible(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        trackShape: const RoundedRectSliderTrackShape(),
                        activeTrackColor: Colors.blue[700],
                        inactiveTrackColor: Colors.blue[100],
                      ),
                      child: Slider(
                        value: value,
                        min: 1,
                        max: widget.totalPages.toDouble(),
                        divisions:
                            widget.totalPages > 1 ? widget.totalPages - 1 : 1,
                        label: 'Página ${value.round()}',
                        onChanged: (val) async {
                          setState(() {
                            _sliderValue = val;
                            _isSliding = true;
                          });

                          final image =
                              await widget.renderPreviewImage(val.round());
                          if (mounted) {
                            setState(() {
                              _previewImageBytes = image;
                            });
                          }
                        },
                        onChangeEnd: (val) async {
                          setState(() {
                            _isSliding = false;
                            _sliderValue = null;
                          });
                          widget.onPageChanged(val.round());
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '${value.round()} / ${widget.totalPages}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isSliding && _previewImageBytes != null)
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
                  child: Image.memory(
                    _previewImageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
