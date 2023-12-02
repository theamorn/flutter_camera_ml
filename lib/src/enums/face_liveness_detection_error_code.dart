/// This enum defines the different error codes for the face liveness detection.
enum FaceLivenessDetectionErrorCode {
  /// The controller was used
  /// while it was not yet initialized using [FaceLivenessDetectionController.start].
  controllerUninitialized,

  /// A generic error occurred.
  ///
  /// This error code is used for all errors that do not have a specific error code.
  genericError,

  /// The permission to use the camera was denied.
  permissionDenied,

  /// Scanning is unsupported on the current device.
  unsupported,
}
