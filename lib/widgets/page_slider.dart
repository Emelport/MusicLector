import 'dart:typed_data';

import 'package:flutter/material.dart';

class PageSlider extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final int previewPage;
  final bool isSliding;
  final bool showSlider;
  final Uint8List? previewImageBytes;
  final Function(double) onChanged;
  final Function(double) onChangeEnd;

  const PageSlider({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.previewPage,
    required this.isSliding,
    required this.showSlider,
    required this.previewImageBytes,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSlider && !isSliding) return const SizedBox.shrink();

    return Stack(
      children: [
        // Slider container
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
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
                  Flexible(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        trackShape: const RoundedRectSliderTrackShape(),
                        activeTrackColor: Colors.blue[700],
                        inactiveTrackColor: Colors.blue[100],
                      ),
                      child: Slider(
                        value: previewPage.toDouble(),
                        min: 1,
                        max: pageCount.toDouble(),
                        divisions: pageCount > 1 ? pageCount - 1 : 1,
                        label: 'Page ${previewPage.round()}',
                        onChanged: onChanged,
                        onChangeEnd: onChangeEnd,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '$previewPage / $pageCount',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Preview image
        if (isSliding && previewImageBytes != null)
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
                  child: Image.memory(previewImageBytes!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
