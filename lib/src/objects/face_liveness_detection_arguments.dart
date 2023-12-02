import 'package:flutter/material.dart';

/// The start arguments of the scanner.
class FaceLivenessDetectionArguments {
  /// The output size of the camera.
  /// This value can be used to draw a box in the image.
  final Size size;

  /// The texture id of the capture used internally.
  final int? textureId;

  /// The texture id of the capture used internally if device is web.
  final String? webId;

  FaceLivenessDetectionArguments({
    required this.size,
    this.textureId,
    this.webId,
  });
}
