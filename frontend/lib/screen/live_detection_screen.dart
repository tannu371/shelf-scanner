import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  late CameraController controller;
  late List<CameraDescription> cameras;
  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? currentFrame;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    vision = FlutterVision();
    init();
  }

  @override
  void dispose() {
    vision.closeYoloModel();
    controller.dispose();
    super.dispose(); // Always last
  }

  init() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
      }).then((value) {
        startDetection();
      });
    });
  }

  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
        labels: 'assets/models/labels.txt',
        modelPath: 'assets/models/yolov11-2.tflite',
        modelVersion: "yolov11",
        numThreads: 2,
        useGpu: true);
    setState(() {
      isLoaded = true;
    });
  }

  bool _isBusy = false;
  Future<void> yoloOnFrame(CameraImage image) async {
    if (_isBusy) {
      return; // Skip this frame if we are still processing the last one
    }
    _isBusy = true;

    final result = await vision.yoloOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.4,
        confThreshold: 0.2,
        classThreshold: 0.5);

    if (result.isNotEmpty && mounted) {
      setState(() {
        yoloResults = result;
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isBusy = false; // Ready for the next frame
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
    double factorX = screen.width / (currentFrame?.height ?? 1);
    double factorY = screen.height / (currentFrame?.width ?? 1);

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
        width: (result["box"][2] - result["box"][0]) * factorX,
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
    double totalHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight; // Default is 56.0
    double bottomNavBarHeight = kBottomNavigationBarHeight; // Default is 56.0

    double bodyHeight =
        totalHeight - statusBarHeight - appBarHeight - bottomNavBarHeight;

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(
              controller,
            ),
          ),
          ...displayBoxesAroundRecognizedObjects(Size(MediaQuery.of(context).size.width, bodyHeight)),
        ],
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
      await player.play(
        AssetSource('sounds/iphone-camera-capture-6448.mp3'),
      );
    } catch (e) {
      throw Exception('Error capturing picture: $e');
    } finally {
      isCaptureProcessing = false;
    }

    stopDetection();
    await Navigator.pushNamed(
      context,
      '/preview',
      arguments: {
        'imageFile': image,
        'visionModel': vision,
      },
    );
    startDetection();
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
    await Navigator.of(context).pushNamed(
      '/preview',
      arguments: {
        'imageFile': image,
        'visionModel': vision,
      },
    );
    startDetection();
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