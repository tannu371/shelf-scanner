import 'dart:typed_data';
import 'package:shelf_scanner/models/book_result.dart';

/// Pairs a [BookResult] with the raw JPEG bytes of its cropped spine image
/// so the detail screen can show the actual scan crop alongside the metadata.
class SpineEntry {
  final BookResult book;

  /// Raw bytes (JPEG) of the cropped spine photo taken from the shelf image.
  /// `null` when the full image was scanned without per-spine cropping.
  final Uint8List? spineBytes;

  const SpineEntry({required this.book, this.spineBytes});
}
