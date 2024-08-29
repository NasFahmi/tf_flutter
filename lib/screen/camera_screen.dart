import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  late Interpreter interpreter;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }
  

  Uint8List resizeImage(
      Uint8List originalImage, int targetWidth, int targetHeight) {
    // Decode the original image
    // print('decode image');
    img.Image? image = img.decodeImage(originalImage);
    print('decoded image ${image}'); //!null
    if (image == null) {
      print('Failed to decode image');
      return Uint8List(0);
    }

    // Resize the image
    img.Image resizedImage = img.copyResize(image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear);

    // Convert to raw byte format (RGB)
    List<int> rawBytes = [];
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        img.Pixel pixel = resizedImage.getPixel(x, y);

        // Extract the RGB components from Pixel object
        rawBytes.add(pixel.r as int);
        rawBytes.add(pixel.g as int);
        rawBytes.add(pixel.b as int);
      }
    }

    return Uint8List.fromList(rawBytes);
  }

  void _initializeCamera() {
    controller = CameraController(widget.cameras[0], ResolutionPreset.low);
    controller.initialize().then((_) {
      if (!mounted) return;

      controller.startImageStream((image) async {
        // Proses frame image di sini
        Uint8List inputImage = _convertYUV420ToImage(image);
        // print('input image ${inputImage}'); //!works 
        _runModel(inputImage);
      });

      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        print(e.description);
      }
    });
  }

  Future<void> _loadModel() async {
    final options = InterpreterOptions()..threads = 4;
    interpreter = await Interpreter.fromAsset('assets/mobilenet_v1.tflite');

    // // Set input shape to [1, 224, 224, 3]
    interpreter.allocateTensors();
    var inputShape = interpreter.getInputTensor(0).shape;
    inputShape[0] = 1;
    inputShape[1] = 224;
    inputShape[2] = 224;
    inputShape[3] = 3;
    interpreter.resizeInputTensor(0, inputShape);

    // Reallocate tensors after resizing
    interpreter.allocateTensors();
  }

  Uint8List _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    // Create Image buffer
    final rgbaBytes = Uint8List(width * height * 4);

    // Fill image buffer
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        // Convert YUV to RGB
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        // Set pixel color
        rgbaBytes[index * 4] = r;
        rgbaBytes[index * 4 + 1] = g;
        rgbaBytes[index * 4 + 2] = b;
        rgbaBytes[index * 4 + 3] = 255;
      }
    }

    return rgbaBytes;
  }

  void _runModel(Uint8List inputImage) async {
    // Resize the image to 224x224
    var resizedImage = resizeImage(inputImage, 224, 224);

    if (resizedImage.length != 224 * 224 * 3) {
      print('Failed to resize image to 224x224x3');
      return;
    }

    // Prepare input data
    List<double> input = resizedImage.map((pixel) => pixel / 255.0).toList();

    // Prepare output tensor
    var output = List.filled(1 * 1001, 0).reshape([1, 1001]);

    // Run inference
    interpreter.run(input, output);

    // Process the output
    var results = output[0] as List<double>;
    var maxScore = results.reduce((a, b) => a > b ? a : b);
    var maxIndex = results.indexOf(maxScore);

    print('Predicted class index: $maxIndex');
    print('Confidence: $maxScore');
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    interpreter.close();
    super.dispose();
  }
}
