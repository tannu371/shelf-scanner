import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Platform-agnostic (iOS + Android) wrapper around the YOLOv8/v11 TFLite model.
class YoloService {
  Interpreter? _interpreter;
  List<int>? _outputShape;

  static const int _inputSize = 640;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> loadModel({
    String modelPath = 'assets/models/yolov11-2.tflite',
    int numThreads = 2,
    bool useGpu = false,
  }) async {
    try {
      final options = InterpreterOptions()..threads = numThreads;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      final inShape = _interpreter!.getInputTensor(0).shape;
      final outTensor = _interpreter!.getOutputTensor(0);
      _outputShape = outTensor.shape;
      debugPrint('[YoloService] ✅ Model loaded');
      debugPrint('[YoloService] Input  shape: $inShape');
      debugPrint('[YoloService] Output shape: $_outputShape  type: ${outTensor.type}');
    } catch (e, st) {
      debugPrint('[YoloService] ❌ Model load failed: $e\n$st');
      _interpreter = null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  bool get isLoaded => _interpreter != null;

  // ── Public inference API ────────────────────────────────────────────────────

  /// Run inference on a live YUV420 / NV12 [CameraImage] frame.
  ///
  /// Pass [bytesPerRow] (plane.bytesPerRow for each plane) so that iOS's
  /// padded NV12 planes are read correctly. Without this, every image row
  /// after the first is offset, producing a sheared/corrupted input.
  Future<List<Map<String, dynamic>>> runOnFrame({
    required List<Uint8List> bytesList,
    required int imageHeight,
    required int imageWidth,
    List<int>? bytesPerRow, // iOS CameraImage plane strides (may be padded)
    double iouThreshold = 0.3,
    // Model already exports sigmoid-activated values in [0,1] — compare directly.
    // 0.5 cuts background (model outputs ~0.4-0.5 for empty areas).
    double confThreshold = 0.25, // same as preview — diagnose first, tune later
    double classThreshold = 0.5,
  }) async {
    if (_interpreter == null) return [];
    final imgRgb = _yuv420ToRgb(
      bytesList,
      imageWidth,
      imageHeight,
      strides: bytesPerRow,
    );
    return _runInference(
      imgRgb,
      imageWidth,
      imageHeight,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
    );
  }

  /// Run inference on a still JPEG/PNG image.
  Future<List<Map<String, dynamic>>> runOnImage({
    required Uint8List bytesList,
    required int imageHeight,
    required int imageWidth,
    double iouThreshold = 0.5,
    double confThreshold = 0.25,
    double classThreshold = 0.5,
  }) async {
    if (_interpreter == null) return [];
    final decoded = img.decodeImage(bytesList);
    if (decoded == null) return [];
    return _runInference(
      decoded,
      imageWidth,
      imageHeight,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
    );
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _runInference(
    img.Image source,
    int origW,
    int origH, {
    required double confThreshold,
    required double iouThreshold,
  }) {
    if (_interpreter == null || _outputShape == null) return [];

    final resized = img.copyResize(source, width: _inputSize, height: _inputSize);

    // Build [1, 640, 640, 3] normalised float input.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );

    final s = _outputShape!;
    final outputData = List.generate(
      s[0],
      (_) => List.generate(s[1], (_) => List.filled(s[2], 0.0)),
    );

    _interpreter!.run(input, outputData);

    // Detect output layout:
    // Transposed [1, 4+cls, N] → s[1] < s[2]
    // Standard   [1, N, 4+cls] → s[1] > s[2]
    final isTransposed = s[1] < s[2];
    debugPrint(
        '[YoloService] shape=$s transposed=$isTransposed conf_thresh=$confThreshold');

    final detections = isTransposed
        ? _parseTransposed(
            outputData[0], origW.toDouble(), origH.toDouble(), confThreshold)
        : _parseStandard(
            outputData[0], origW.toDouble(), origH.toDouble(), confThreshold);

    debugPrint(
        '[YoloService] raw=${detections.length} → NMS result=${_nms(detections, iouThreshold).length}');
    return _nms(detections, iouThreshold);
  }

  // Standard [N, 5+cls]: each row = [cx, cy, w, h, conf, ...]
  List<Map<String, dynamic>> _parseStandard(
    List<List<double>> rows,
    double origW,
    double origH,
    double confThreshold,
  ) {
    final det = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row.length < 5) continue;
      final conf = row[4]; // already sigmoid-activated by the model
      if (conf < confThreshold) continue;
      final d = _makeDetection(row[0], row[1], row[2], row[3], conf, origW, origH);
      if (d != null) det.add(d);
    }
    return det;
  }

  // Transposed [5+cls, N]: each column = one anchor
  List<Map<String, dynamic>> _parseTransposed(
    List<List<double>> cols,
    double origW,
    double origH,
    double confThreshold,
  ) {
    if (cols.length < 5) return [];
    final numAnchors = cols[0].length;
    final det = <Map<String, dynamic>>[];
    for (int i = 0; i < numAnchors; i++) {
      final conf = cols[4][i]; // already sigmoid-activated by the model
      if (conf < confThreshold) continue;
      final d = _makeDetection(
          cols[0][i], cols[1][i], cols[2][i], cols[3][i], conf, origW, origH);
      if (d != null) det.add(d);
    }
    return det;
  }

  /// Build a detection map and reject degenerate boxes (too thin, too small).
  Map<String, dynamic>? _makeDetection(
    double cx,
    double cy,
    double w,
    double h,
    double conf, // already sigmoid-normalised
    double origW,
    double origH,
  ) {
    final x1 = ((cx - w / 2) * origW).clamp(0.0, origW);
    final y1 = ((cy - h / 2) * origH).clamp(0.0, origH);
    final x2 = ((cx + w / 2) * origW).clamp(0.0, origW);
    final y2 = ((cy + h / 2) * origH).clamp(0.0, origH);

    final bw = x2 - x1;
    final bh = y2 - y1;

    // Reject degenerate boxes: too small or extreme aspect ratio.
    if (bw < 5 || bh < 5) return null;
    final ar = bw / bh;
    if (ar < 0.05 || ar > 20) return null; // not book-shaped

    return {
      'class': 'book',
      'box': [x1, y1, x2, y2, conf],
    };
  }

  List<Map<String, dynamic>> _nms(
      List<Map<String, dynamic>> dets, double thresh) {
    dets.sort(
        (a, b) => (b['box'][4] as double).compareTo(a['box'][4] as double));
    final keep = <Map<String, dynamic>>[];
    for (final det in dets) {
      if (keep
          .every((k) => _iou(det['box'] as List, k['box'] as List) <= thresh)) {
        keep.add(det);
      }
    }
    return keep;
  }

  double _iou(List a, List b) {
    final ix1 = math.max(a[0] as double, b[0] as double);
    final iy1 = math.max(a[1] as double, b[1] as double);
    final ix2 = math.min(a[2] as double, b[2] as double);
    final iy2 = math.min(a[3] as double, b[3] as double);
    final inter =
        math.max(0.0, ix2 - ix1) * math.max(0.0, iy2 - iy1);
    if (inter == 0) return 0;
    return inter /
        ((a[2] - a[0]) * (a[3] - a[1]) +
            (b[2] - b[0]) * (b[3] - b[1]) -
            inter);
  }

  // ── Camera frame → RGB ─────────────────────────────────────────────────────

  /// Convert a CameraImage frame to an [img.Image] for YOLO inference.
  ///
  /// Handles three formats iOS/Android cameras can send:
  ///   - BGRA8888   (1 plane, 4 bytes/px)  — iOS default
  ///   - NV12       (2 planes, Y + UV interleaved) — iOS YUV mode
  ///   - YUV420p    (3 planes, Y + U + V separate) — Android
  img.Image _yuv420ToRgb(
    List<Uint8List> planes,
    int width,
    int height, {
    List<int>? strides,
  }) {
    final rowStride0 = (strides != null && strides.isNotEmpty) ? strides[0] : width;
    final out = img.Image(width: width, height: height);

    // ── BGRA8888: planes=1, rowStride = width × 4 ──────────────────────────
    // iOS camera_avfoundation sends this format by default.
    if (planes.length == 1 && rowStride0 >= width * 4) {
      debugPrint('[YoloService] Format: BGRA8888 ${width}x$height stride=$rowStride0');
      final bgra = planes[0];
      for (int j = 0; j < height; j++) {
        final rowStart = j * rowStride0;
        for (int i = 0; i < width; i++) {
          final px = rowStart + i * 4;
          if (px + 2 >= bgra.length) continue;
          out.setPixelRgb(
            i, j,
            bgra[px + 2] & 0xFF, // R (index 2 in BGRA)
            bgra[px + 1] & 0xFF, // G
            bgra[px + 0] & 0xFF, // B
          );
        }
      }
    }
    // ── NV12: planes=2, Y + UV interleaved ─────────────────────────────────
    else if (planes.length == 2) {
      final yStride  = rowStride0;
      final uvStride = (strides != null && strides.length > 1) ? strides[1] : width;
      debugPrint('[YoloService] Format: NV12 ${width}x$height y_stride=$yStride uv_stride=$uvStride');
      final yPlane  = planes[0];
      final uvPlane = planes[1];
      for (int j = 0; j < height; j++) {
        final yRow  = j * yStride;
        final uvRow = (j ~/ 2) * uvStride;
        for (int i = 0; i < width; i++) {
          final yIdx  = yRow + i;
          if (yIdx >= yPlane.length) continue;
          final y = yPlane[yIdx] & 0xFF;
          final uvIdx = uvRow + (i ~/ 2) * 2;
          int cb = 0, cr = 0;
          if (uvIdx + 1 < uvPlane.length) {
            cb = (uvPlane[uvIdx]     & 0xFF) - 128;
            cr = (uvPlane[uvIdx + 1] & 0xFF) - 128;
          }
          out.setPixelRgb(i, j,
            (y + 1.402 * cr).clamp(0, 255).toInt(),
            (y - 0.344136 * cb - 0.714136 * cr).clamp(0, 255).toInt(),
            (y + 1.772 * cb).clamp(0, 255).toInt(),
          );
        }
      }
    }
    // ── YUV420p: planes=3, separate Y / U / V ──────────────────────────────
    else {
      final yStride  = rowStride0;
      final uStride  = (strides != null && strides.length > 1) ? strides[1] : width ~/ 2;
      final vStride  = (strides != null && strides.length > 2) ? strides[2] : width ~/ 2;
      debugPrint('[YoloService] Format: YUV420p ${width}x$height y_stride=$yStride');
      final yPlane = planes[0];
      final uPlane = planes.length > 1 ? planes[1] : Uint8List(0);
      final vPlane = planes.length > 2 ? planes[2] : Uint8List(0);
      for (int j = 0; j < height; j++) {
        final yRow = j * yStride;
        final uRow = (j ~/ 2) * uStride;
        final vRow = (j ~/ 2) * vStride;
        for (int i = 0; i < width; i++) {
          final yIdx = yRow + i;
          if (yIdx >= yPlane.length) continue;
          final y  = yPlane[yIdx] & 0xFF;
          final uIdx = uRow + i ~/ 2;
          final vIdx = vRow + i ~/ 2;
          final cb = uPlane.isNotEmpty && uIdx < uPlane.length ? (uPlane[uIdx] & 0xFF) - 128 : 0;
          final cr = vPlane.isNotEmpty && vIdx < vPlane.length ? (vPlane[vIdx] & 0xFF) - 128 : 0;
          out.setPixelRgb(i, j,
            (y + 1.402 * cr).clamp(0, 255).toInt(),
            (y - 0.344136 * cb - 0.714136 * cr).clamp(0, 255).toInt(),
            (y + 1.772 * cb).clamp(0, 255).toInt(),
          );
        }
      }
    }

    final cp = out.getPixel(width ~/ 2, height ~/ 2);
    debugPrint('[YoloService] Center px: R=${cp.r.toInt()} G=${cp.g.toInt()} B=${cp.b.toInt()}');
    return out;
  }
}


