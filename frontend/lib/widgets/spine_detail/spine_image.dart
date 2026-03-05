import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Displays the cropped spine image (left column) in the spine card.
class SpineImage extends StatelessWidget {
  final Uint8List? spineBytes;
  const SpineImage({super.key, this.spineBytes});

  @override
  Widget build(BuildContext context) {
    const width = 50.0;
    const minHeight = 80.0;

    Widget imageWidget;
    if (spineBytes != null && spineBytes!.isNotEmpty) {
      imageWidget = Image.memory(
        spineBytes!,
        fit: BoxFit.cover,
        width: width,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(width, minHeight),
      );
    } else {
      imageWidget = _placeholder(width, minHeight);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: width, minHeight: minHeight),
        child: imageWidget,
      ),
    );
  }

  Widget _placeholder(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.menu_book_rounded,
            size: 36, color: Colors.grey),
      );
}
