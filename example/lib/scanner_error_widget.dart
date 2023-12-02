import 'package:face_liveness_detection/face_liveness_detection.dart';
import 'package:flutter/material.dart';

class ScannerErrorWidget extends StatelessWidget {
  const ScannerErrorWidget({Key? key, required this.error}) : super(key: key);

  final FaceLivenessDetectionException error;

  @override
  Widget build(BuildContext context) {
    String errorMessage;

    switch (error.errorCode) {
      case FaceLivenessDetectionErrorCode.controllerUninitialized:
        errorMessage = 'Controller not ready.';
        break;
      case FaceLivenessDetectionErrorCode.permissionDenied:
        errorMessage = 'Permission denied';
        break;
      case FaceLivenessDetectionErrorCode.unsupported:
        errorMessage = 'Scanning is unsupported on this device';
        break;
      default:
        errorMessage = 'Generic Error';
        break;
    }

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Icon(Icons.error, color: Colors.white),
            ),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              error.errorDetails?.message ?? '',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
