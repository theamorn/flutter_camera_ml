import 'dart:typed_data';

class FaceLivenessDetectionSuccess {
  final Uint8List image;
  final String scores;

  FaceLivenessDetectionSuccess({
    required this.image,
    required this.scores,
  });
}
