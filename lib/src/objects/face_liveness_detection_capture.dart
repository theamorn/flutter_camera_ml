import 'dart:typed_data';

import 'package:face_liveness_detection/src/enums/liveness_state.dart';

/// The return object after a frame is scanned.
///
/// [image] If enabled, an image of the scanned frame.
class FaceLivenessDetectionCapture {
  final LivenessState state;
  final Uint8List? image;
  final String? scores;

  FaceLivenessDetectionCapture({
    required this.state,
    this.image,
    this.scores,
  });
}
