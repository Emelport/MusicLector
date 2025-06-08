import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class ImageUtils {
  static Rect getImageRect(Size widgetSize, Uint8List imageBytes) {
    final image = decodeImageFromList(imageBytes);
    final imageRatio = image.width / image.height;
    final widgetRatio = widgetSize.width / widgetSize.height;
    
    if (widgetRatio > imageRatio) {
      // Altura limitante
      final height = widgetSize.height;
      final width = height * imageRatio;
      final left = (widgetSize.width - width) / 2;
      return Rect.fromLTWH(left, 0, width, height);
    } else {
      // Ancho limitante
      final width = widgetSize.width;
      final height = width / imageRatio;
      final top = (widgetSize.height - height) / 2;
      return Rect.fromLTWH(0, top, width, height);
    }
  }
}

class RelativePoint {
  final double x;
  final double y;
  
  RelativePoint({required this.x, required this.y});
}