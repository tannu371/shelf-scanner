import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:gal/gal.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/widgets/book_result_sheet.dart';

class PreviewScreen extends StatefulWidget {
  final XFile imageFile;
  final FlutterVision visionModel;

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
    final result = await widget.visionModel.yoloOnImage(
        bytesList: byte,
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.8,
        confThreshold: 0.5,
        classThreshold: 0.5);
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
      ]),
      bottomNavigationBar: Row(
        children: [
          const Spacer(),
          Expanded(
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
              ),
              onPressed: _isSearching ? null : _getRecommendation,
            ),
          ),
        ],
      ),
    );
  }

  // ── Core: send spine image to backend → show results ─────────────────────
  Future<void> _getRecommendation() async {
    setState(() => _isSearching = true);

    try {
      final imageBytes = await File(widget.imageFile.path).readAsBytes();
      final results = await ApiService.scanSpine(imageBytes);

      if (!mounted) return;

      if (results.isEmpty) {
        _showError('No matching book found. Try a clearer photo.');
        return;
      }

      // Show the first (best) match — user can scroll to similar books inside
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BookResultSheet(book: results.first),
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
