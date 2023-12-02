import 'package:face_liveness_detection/src/enums/face_liveness_detection_error_code.dart';

/// This class represents an exception thrown by the face liveness detection.
class FaceLivenessDetectionException implements Exception {
  const FaceLivenessDetectionException({
    required this.errorCode,
    this.errorDetails,
  });

  /// The error code of the exception.
  final FaceLivenessDetectionErrorCode errorCode;

  /// The additional error details that came with the [errorCode].
  final FaceLivenessDetectionErrorDetails? errorDetails;

  @override
  String toString() {
    if (errorDetails != null && errorDetails?.message != null) {
      return "FaceLivenessDetectionException: code ${errorCode.name}, message: ${errorDetails?.message}";
    }
    return "FaceLivenessDetectionException: ${errorCode.name}";
  }
}

/// The raw error details for a [FaceLivenessDetectionException].
class FaceLivenessDetectionErrorDetails {
  const FaceLivenessDetectionErrorDetails({
    this.code,
    this.details,
    this.message,
  });

  /// The error code from the [PlatformException].
  final String? code;

  /// The details from the [PlatformException].
  final Object? details;

  /// The error message from the [PlatformException].
  final String? message;
}
