import 'package:face_liveness_detection/face_liveness_detection.dart';
import 'package:face_liveness_detection_example/scanner_error_widget.dart';
import 'package:flutter/material.dart';

class FaceLivenessDetectionControllerDemo extends StatefulWidget {
  const FaceLivenessDetectionControllerDemo({super.key});

  @override
  createState() => _FaceLivenessDetectionControllerDemoState();
}

class _FaceLivenessDetectionControllerDemoState
    extends State<FaceLivenessDetectionControllerDemo>
    with SingleTickerProviderStateMixin {
  late final FaceLivenessDetectionController controller;

  @override
  void initState() {
    controller = FaceLivenessDetectionController(
      activeMode: true,
      facing: CameraFacing.front,
      detectionTimeoutMs: 20000,
      cameraResolution: const Size(1280, 720),
    );
    initPlatformState();
    super.initState();
  }

  Future<void> initPlatformState() async {
    final version = await controller.getSdkVersion() ?? 'Unknown sdk version';
  }

  bool isStarted = true;
  final ValueNotifier<String> state = ValueNotifier("");

  void _startOrStop() {
    try {
      if (isStarted) {
        controller.stop();
      } else {
        controller.start();
      }
      setState(() {
        isStarted = !isStarted;
      });
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong! $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String getLivenessMessage(int statusCode) {
    switch (statusCode) {
      case -1:
        return '';
      case 0:
        return 'Look Straight';
      case 1:
        return 'Face not found';
      case 2:
        return 'Look Straight';
      case 3:
        return 'Too dark';
      case 4:
        return 'Too bright';
      case 5:
        return 'Too close';
      case 6:
        return 'Too far';
      case 7:
        return 'No mouth';
      case 8:
        return 'No left eyes';
      case 9:
        return 'No right eyes';
      case 10:
        return 'No eyes';
      case 11:
        return 'Multiple faces';
      case 12:
        return 'Background is bright';
      case 13:
        return 'Turn left';
      case 14:
        return 'Turn right';
      case 15:
        return 'Blink';
      case 16:
        return 'Smile';
      case 17:
        return 'Nod';
      case 18:
        return 'Close mouth';
      case 19:
        return 'Change background';
      case 20:
        return 'Face not center';
      default:
        return 'N/A';
    }
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Popup Dialog'),
          content: Text('This is a simple popup dialog!'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // Close the dialog when "Close" is pressed
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: size.width * 0.5,
      height: size.width * 0.5,
    );

    return Scaffold(
      // appBar: AppBar(title: const Text('With ValueListenableBuilder')),
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          return Stack(
            children: [
              FaceLivenessDetection(
                controller: controller,
                scanWindow: scanWindow,
                onError: (error) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Popup Dialog'),
                        content: Text('This is a simple popup dialog!'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              controller.restart();
                              Navigator.of(context).pop();
                            },
                            child: Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   SnackBar(
                  //     content: Text(
                  //         'Something went wrong! ${error.errorDetails?.message}'),
                  //     backgroundColor: Colors.red,
                  //   ),
                  // );
                },
                errorBuilder: (context, error, child) {
                  return ScannerErrorWidget(error: error);
                },
                fit: BoxFit.contain,
                onDetect: (LivenessState livenessState) async {
                  state.value = getLivenessMessage(livenessState.value);
                },
                onSuccess: (data) async {
                  final byte = data.image.lengthInBytes;
                  final kb = byte / 1024;
                  final mb = kb / 1024;

                  // ImageGallerySaver.saveImage(
                  //         Uint8List.fromList(data.image),
                  //         quality: 60,
                  //         name: "hello")
                  //     .then((value) => print(value));

                  // ImageGallerySaver.saveImage(
                  //         Uint8List.fromList(data.image),
                  //         quality: 60,
                  //         name: "hello")
                  //     .then((value) => print(value));

                  // final result = await ImageGallerySaver.saveImage(
                  //     Uint8List.fromList(response.data),
                  //     quality: 60,
                  //     name: "hello");

                  await showDialog(
                    context: context,
                    builder: (ctx) {
                      return Dialog(
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: MemoryImage(data.image),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                  _startOrStop();
                },
                onScannerStarted: (arguments) {
                  // print(
                  //     "===== onScannerStarted: ${(arguments as FaceLivenessDetectionArguments).size}");
                  // Do something with arguments.
                },
              ),
              CustomPaint(
                painter: ScannerOverlay(scanWindow),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  alignment: Alignment.bottomCenter,
                  height: 100,
                  color: Colors.black.withOpacity(0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: isStarted
                            ? const Icon(Icons.stop)
                            : const Icon(Icons.play_arrow),
                        iconSize: 32.0,
                        onPressed: _startOrStop,
                      ),
                      Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 200,
                          height: 50,
                          child: FittedBox(
                            child: ValueListenableBuilder(
                                valueListenable: state,
                                builder: (context, state, child) {
                                  return Text(
                                    state,
                                    overflow: TextOverflow.fade,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium!
                                        .copyWith(color: Colors.white),
                                  );
                                }),
                          ),
                        ),
                      ),
                      IconButton(
                        color: Colors.white,
                        icon: ValueListenableBuilder(
                          valueListenable: controller.cameraFacingState,
                          builder: (context, state, child) {
                            if (state == null) {
                              return const Icon(Icons.camera_front);
                            }
                            switch (state as CameraFacing) {
                              case CameraFacing.front:
                                return const Icon(Icons.camera_front);
                              case CameraFacing.back:
                                return const Icon(Icons.camera_rear);
                            }
                          },
                        ),
                        iconSize: 32.0,
                        onPressed: () => controller.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;
  final double borderRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    // Create a Paint object for the white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0; // Adjust the border width as needed

    // Calculate the border rectangle with rounded corners
// Adjust the radius as needed
    final borderRect = RRect.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    // Draw the white border
    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
