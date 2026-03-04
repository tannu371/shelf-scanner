import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shelf_scanner/services/yolo_service.dart';

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  late CameraController controller;
  late List<CameraDescription> cameras;
  late YoloService vision;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? currentFrame;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    vision = YoloService();
    init();
  }

  @override
  void dispose() {
    vision.dispose();
    controller.dispose();
    super.dispose(); // Always last
  }

  Future<void> init() async {
    try {
      cameras = await availableCameras();
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      // Step 1: initialise camera on main isolate
      await controller.initialize();
      // Step 2: load TFLite interpreter on main isolate (must NOT be in a .then())
      await loadYoloModel();
      // Step 3: now safe to start streaming
      if (mounted) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
        await startDetection();
      }
    } catch (e) {
      debugPrint('LiveDetectionScreen init error: $e');
    }
  }

  Future<void> loadYoloModel() async {
    // CPU-only: numThreads=2, no GPU delegate (GPU causes native abort on iOS)
    await vision.loadModel(
        modelPath: 'assets/models/yolov11-2.tflite',
        numThreads: 2,
        useGpu: false);
  }

  bool _isBusy = false;
  Future<void> yoloOnFrame(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    final result = await vision.runOnFrame(
      bytesList: image.planes.map((p) => p.bytes).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      bytesPerRow: image.planes.map((p) => p.bytesPerRow).toList(),
      iouThreshold: 0.3,
      confThreshold: 0.5,  // model outputs already in [0,1], 0.5 filters background
    );

    if (mounted) {
      setState(() => yoloResults = result); // always update — clears stale boxes
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isBusy = false;
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((image) async {
      if (isDetecting) {
        currentFrame = image;
        yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    // iOS sends landscape BGRA frames (width > height, e.g. 640×480),
    // but the preview is displayed in portrait (rotated 90°).
    // We need to swap width/height so factorX maps camera-x→screen-x
    // and factorY maps camera-y→screen-y correctly.
    final rawFrameW = (currentFrame?.width ?? 1).toDouble();
    final rawFrameH = (currentFrame?.height ?? 1).toDouble();
    // If frame arrives landscape (width > height), swap dimensions so
    // frameW = portrait width, frameH = portrait height.
    final bool isLandscapeFrame = rawFrameW > rawFrameH;
    final frameW = isLandscapeFrame ? rawFrameH : rawFrameW;
    final frameH = isLandscapeFrame ? rawFrameW : rawFrameH;

    final previewW = screen.width;
    // StackFit.expand forces CameraPreview to fill the entire body area
    // (tight constraints → AspectRatio is ignored, camera uses resizeAspectFill).
    // So the camera content covers screen.width × screen.height with NO letterboxing.
    // topOffset = 0; factorY = screen.height / frameH.
    final previewH = screen.height;
    const double topOffset = 0;
    double factorX = previewW / frameW;
    double factorY = previewH / frameH;

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top:  result["box"][1] * factorY + topOffset,
        width:  (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white)),
        title: const Text('Scanning...', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: toggleFlash,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use the true rendered Stack size so topOffset is exact.
          final stackSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
              ...displayBoxesAroundRecognizedObjects(stackSize),
            ],
          );
        },
      ),

      // Bottom controls
      bottomNavigationBar: Container(
        height: 150,
        padding: const EdgeInsets.only(bottom: 30),
        decoration: const BoxDecoration(
          color: Colors.black, // Slight transparency for better visibility
        ),
        child: Column(
          children: <Widget>[
            // Mode selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                    onPressed: () => setState(() => mode = 0),
                    child: Text('Photo',
                        style: TextStyle(
                            color: mode == 0 ? Colors.yellow : Colors.white,
                            fontWeight: FontWeight.bold))),
                TextButton(
                    onPressed: () => setState(() => mode = 1),
                    child: Text('Video',
                        style: TextStyle(
                            color: mode == 1 ? Colors.yellow : Colors.white,
                            fontWeight: FontWeight.bold))),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pick from gallery
                Expanded(
                  child: GestureDetector(
                    onTap: pickFromGallery,
                    child: SvgPicture.asset(
                      'assets/icons/gallery-import.svg',
                      width: 30, // Control the size here
                      height: 30,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
      
                if (mode == 0) ...[
                  // Capture button for Photo mode
                  Expanded(
                    child: GestureDetector(
                      onTap: takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.grey,
                              width: 4,
                              style: BorderStyle.solid),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Capture button for Video mode
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Implement video recording logic here
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.grey,
                              width: 4,
                              style: BorderStyle.solid),
                        ),
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
      
                const Spacer() // Spacer to balance layout
              ],
            ),
          ],
        ),
      ),
    );
  }

  // capture photo
  XFile? image;
  final player = AudioPlayer();
  bool isCaptureProcessing = false;
  void takePicture() async {
    if (isCaptureProcessing) return;
    isCaptureProcessing = true;
    try {
      image = await controller.takePicture();
      // Play shutter sound immediately (fire-and-forget — don't await).
      // Stop it before navigating so it doesn't bleed into the preview screen.
      unawaited(player.play(AssetSource('sounds/iphone-camera-capture-6448.mp3')));
    } catch (e) {
      throw Exception('Error capturing picture: $e');
    } finally {
      isCaptureProcessing = false;
    }

    stopDetection();
    if (!mounted) return;
    // Stop audio before leaving so it doesn't play on the preview screen.
    await player.stop();
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/preview',
      arguments: {'imageFile': image, 'visionModel': vision},
    );
    if (mounted) startDetection();
  }

  // Pick image from gallery
  final ImagePicker picker = ImagePicker();
  bool isPickingImage = false;
  void pickFromGallery() async {
    if (isPickingImage) return;
    isPickingImage = true;
    try {
      image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
    } catch (e) {
      throw Exception('Gallery error: $e');
    }

    stopDetection();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(
      '/preview',
      arguments: {
        'imageFile': image,
        'visionModel': vision,
      },
    );
    if (mounted) startDetection();
    isPickingImage = false;
  }

  // Flash mode management
  bool isFlashOn = false;
  void toggleFlash() {
    setState(() {
      if (isFlashOn) {
        controller.setFlashMode(FlashMode.off);
      } else {
        controller.setFlashMode(FlashMode.torch);
      }
      isFlashOn = !isFlashOn;
    });
  }

  // Mode selection
  int mode = 0; // 0: Photo, 1: Video
}