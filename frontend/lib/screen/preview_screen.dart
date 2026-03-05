import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/services/yolo_service.dart';
import 'package:shelf_scanner/screen/book_spine_detail_screen.dart';


class PreviewScreen extends StatefulWidget {
  final XFile imageFile;
  final YoloService visionModel;

  const PreviewScreen(
      {super.key, required this.imageFile, required this.visionModel});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late List<Map<String, dynamic>> yoloResults;

  double imageHeight = 1.0;
  double imageWidth = 1.0;

  // API state
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    yoloResults = [];
    yoloOnImage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  yoloOnImage() async {
    yoloResults.clear();
    Uint8List byte = await widget.imageFile.readAsBytes();
    final image = await decodeImageFromList(byte);
    imageHeight = image.height.toDouble();
    imageWidth = image.width.toDouble();
    final result = await widget.visionModel.runOnImage(
        bytesList: byte,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.70); // raised from 0.5 — reduces false positives like keyboards
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight;
    double bottomNavBarHeight = kBottomNavigationBarHeight;

    double bodyHeight =
        totalHeight - statusBarHeight - appBarHeight - bottomNavBarHeight;
    Size size = MediaQuery.of(context).size;

    List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
      if (yoloResults.isEmpty) return [];

      double availableHeight = bodyHeight;
      double availableWidth = screen.width;

      double scaleX = availableWidth / imageWidth;
      double scaleY = availableHeight / imageHeight;
      double scale = (scaleX < scaleY) ? scaleX : scaleY;

      double scaledWidth = imageWidth * scale;
      double scaledHeight = imageHeight * scale;

      double offsetX = (availableWidth - scaledWidth) / 2;
      double offsetY = (availableHeight - scaledHeight) / 2;

      return yoloResults.map((result) {
        double x1 = result["box"][0] * scale + offsetX;
        double y1 = result["box"][1] * scale + offsetY;
        double width = (result["box"][2] - result["box"][0]) * scale;
        double height = (result["box"][3] - result["box"][1]) * scale;

        return Positioned(
          left: x1,
          top: y1,
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(1.0)),
              border: Border.all(color: Colors.pink, width: 2.0),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                color: Colors.pink,
                child: Text(
                  "${(result["box"][4] * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => saveImage(File(widget.imageFile.path), context),
          ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        Center(
          child: Image.file(
            File(widget.imageFile.path),
            fit: BoxFit.contain,
            width: size.width,
            height: bodyHeight,
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
        // Full-screen loading overlay while fetching recommendations
        if (_isSearching)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Getting details...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: ElevatedButton.icon(
          icon: _isSearching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_isSearching ? 'Searching…' : 'Get Recommendation'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _isSearching ? null : _getRecommendation,
        ),
      ),
    );
  }

  // ── Core: send spine image to backend → show results ─────────────────────
  Future<void> _getRecommendation() async {
    setState(() => _isSearching = true);

    try {
      final imageBytes = await File(widget.imageFile.path).readAsBytes();

      // Each entry = one detected spine's crop bytes + its book result.
      final List<SpineEntry> entries = [];
      // Track ISBNs globally so the same book doesn't appear in two cards.
      final seen = <String>{};

      if (yoloResults.isNotEmpty) {
        // Crop each detected spine and scan individually so PaddleOCR
        // receives a clean single-spine image (not a multi-spine shelf photo).
        final decoded = img.decodeImage(imageBytes);
        if (decoded != null) {
          for (final box in yoloResults) {
            // box[0]=x1, [1]=y1, [2]=x2, [3]=y2 in original image pixels
            final x1 = (box['box'][0] as double).clamp(0.0, imageWidth - 1).toInt();
            final y1 = (box['box'][1] as double).clamp(0.0, imageHeight - 1).toInt();
            final x2 = (box['box'][2] as double).clamp(x1 + 1.0, imageWidth).toInt();
            final y2 = (box['box'][3] as double).clamp(y1 + 1.0, imageHeight).toInt();

            final crop = img.copyCrop(decoded,
                x: x1, y: y1, width: x2 - x1, height: y2 - y1);
            final cropBytes = Uint8List.fromList(img.encodeJpg(crop, quality: 90));

            try {
              final results = await ApiService.scanSpine(cropBytes);
              // Take only the top-1 match per spine crop → 3 spines = 3 cards.
              if (results.isNotEmpty && seen.add(results.first.isbn)) {
                entries.add(SpineEntry(book: results.first, spineBytes: cropBytes));
              }
            } on ApiException catch (e) {
              debugPrint('Crop scan failed: ${e.message}');
            }
          }
        }
      }

      // Fallback: scan the full image if no crops produced results.
      if (entries.isEmpty) {
        final results = await ApiService.scanSpine(imageBytes);
        for (final r in results) {
          if (seen.add(r.isbn)) {
            entries.add(SpineEntry(book: r)); // no crop bytes for full-image scan
          }
        }
      }

      if (!mounted) return;

      if (entries.isEmpty) {
        _showError('No matching book found. Try a clearer photo.');
        return;
      }

      // Navigate — pass the full list so the detail screen shows every spine.
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookSpineDetailScreen(entries: entries),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('Failed to reach the server. Is it running?');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void saveImage(File? capturedImage, BuildContext context) async {
    if (capturedImage == null) return;
    try {
      await Gal.putImage(capturedImage.path, album: "ShelfScanner");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved to Gallery!")),
        );
      }
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }
}
