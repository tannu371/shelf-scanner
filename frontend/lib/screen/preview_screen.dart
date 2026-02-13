import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:gal/gal.dart';

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
    double appBarHeight = kToolbarHeight; // Default is 56.0
    double bottomNavBarHeight = kBottomNavigationBarHeight; // Default is 56.0

    double bodyHeight =
        totalHeight - statusBarHeight - appBarHeight - bottomNavBarHeight;
    Size size = MediaQuery.of(context).size;

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
      if (yoloResults.isEmpty) return [];

      // Use the actual height available to the Stack (the body height)
      // We use the screen height provided to the function, but we must
      // ensure we are measuring the same area the Image.file occupies.
      double availableHeight = bodyHeight;
      double availableWidth = screen.width;

      // 1. Calculate the scaling factor (BoxFit.contain logic)
      double scaleX = availableWidth / imageWidth;
      double scaleY = availableHeight / imageHeight;
      double scale = (scaleX < scaleY) ? scaleX : scaleY;

      // 2. Calculate the scaled dimensions of the image
      double scaledWidth = imageWidth * scale;
      double scaledHeight = imageHeight * scale;

      // 3. Calculate the letterboxing offsets
      // These center the boxes over the 'Fit.contain' image
      double offsetX = (availableWidth - scaledWidth) / 2;
      double offsetY = (availableHeight - scaledHeight) / 2;

      return yoloResults.map((result) {
        // result["box"] = [x1, y1, x2, y2, confidence]
        // Apply scale and then add the offset to align with the centered image
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                // Recommendation Logic
                throw ("Get Recommendations Clicked");
              },
              child: const Text("Get Recommendation"),
            ),
          ),
        ],
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
