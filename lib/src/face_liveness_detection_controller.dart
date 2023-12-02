import 'dart:async';
import 'package:face_liveness_detection/src/enums/liveness_state.dart';
import 'package:face_liveness_detection/src/enums/camera_facing.dart';
import 'package:face_liveness_detection/src/enums/face_liveness_detection_error_code.dart';
import 'package:face_liveness_detection/src/enums/face_liveness_detection_state.dart';
import 'package:face_liveness_detection/src/face_liveness_detection_exception.dart';
import 'package:face_liveness_detection/src/objects/face_liveness_detection_arguments.dart';
import 'package:face_liveness_detection/src/objects/face_liveness_detection_capture.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The [FaceLivenessDetectionController] holds all the logic of this plugin,
/// where as the [FaceLivenessDetection] class is the frontend of this plugin.
class FaceLivenessDetectionController {
  FaceLivenessDetectionController({
    this.activeMode = true,
    this.autoStart = true,
    this.facing = CameraFacing.front,
    this.detectionTimeoutMs = 40000,
    this.cameraResolution,
  });

  /// Toggle between ActiveMode and PassiveMode
  final bool activeMode;

  /// Automatically start the faceLivenessDetection on initialization.
  final bool autoStart;

  /// The desired resolution for the camera.
  ///
  /// When this value is provided, the camera will try to match this resolution,
  /// or fallback to the closest available resolution.
  /// When this is null, Android defaults to a resolution of 640x480.
  ///
  /// Bear in mind that changing the resolution has an effect on the aspect ratio.
  ///
  /// When the camera orientation changes,
  /// the resolution will be flipped to match the new dimensions of the display.
  ///
  /// Currently only supported on Android.
  final Size? cameraResolution;

  /// Select which camera should be used.
  ///
  /// Default: CameraFacing.front
  final CameraFacing facing;

  /// Sets the timeout of detector.
  /// The timeout is set in milliseconds.
  final int detectionTimeoutMs;

  /// Sets the face liveness stream
  final StreamController<FaceLivenessDetectionCapture> _livenessController =
      StreamController.broadcast();
  Stream<FaceLivenessDetectionCapture> get liveness =>
      _livenessController.stream;

  static const MethodChannel _methodChannel =
      MethodChannel('com.kbtg.face_liveness_detector/liveness/method');

  static const EventChannel _eventChannel =
      EventChannel('com.kbtg.face_liveness_detector/liveness/event');

  /// Listen to events from the platform specific code
  StreamSubscription? events;

  /// A notifier that provides several arguments about the FaceLivenessDetection
  final ValueNotifier<FaceLivenessDetectionArguments?> startArguments =
      ValueNotifier(null);

  /// A notifier that provides the state of which camera is being used
  late final ValueNotifier<CameraFacing> cameraFacingState =
      ValueNotifier(facing);

  /// A notifier that provides zoomScale.
  final ValueNotifier<double> zoomScaleState = ValueNotifier(0.0);

  bool isStarting = false;

  /// Set the starting arguments for the camera
  Map<String, dynamic> _argumentsToMap({CameraFacing? cameraFacingOverride}) {
    final Map<String, dynamic> arguments = {};

    cameraFacingState.value = cameraFacingOverride ?? facing;
    arguments['activeMode'] = activeMode;
    arguments['facing'] = cameraFacingState.value.index;
    arguments['timeout'] = detectionTimeoutMs;

    if (cameraResolution != null) {
      arguments['cameraResolution'] = <int>[
        cameraResolution!.width.toInt(),
        cameraResolution!.height.toInt(),
      ];
    }

    return arguments;
  }

  /// Start liveness.
  /// Upon calling this method, the necessary camera permission will be requested.
  ///
  /// Returns an instance of [FaceLivenessDetectionArguments]
  /// when the scanner was successfully started.
  /// Returns null if the scanner is currently starting.
  ///
  /// Throws a [FaceLivenessDetectionException] if starting the scanner failed.
  Future<FaceLivenessDetectionArguments?> start({
    CameraFacing? cameraFacingOverride,
  }) async {
    if (isStarting) {
      debugPrint("Called start() while starting.");
      return null;
    }

    events ??= _eventChannel
        .receiveBroadcastStream()
        .listen((data) => _handleEvent(data as Map));

    isStarting = true;

    // Check authorization status
    if (!kIsWeb) {
      final FaceLivenessDetectionState state;

      try {
        state = FaceLivenessDetectionState.values[
            await _methodChannel.invokeMethod('checkPermission') as int? ?? 0];
      } on PlatformException catch (error) {
        isStarting = false;

        throw FaceLivenessDetectionException(
          errorCode: FaceLivenessDetectionErrorCode.genericError,
          errorDetails: FaceLivenessDetectionErrorDetails(
            code: error.code,
            details: error.details as Object?,
            message: error.message,
          ),
        );
      }

      switch (state) {
        case FaceLivenessDetectionState.undetermined:
          bool result = false;

          try {
            result = await _methodChannel.invokeMethod('requestPermission')
                    as bool? ??
                false;
          } catch (error) {
            isStarting = false;
            throw const FaceLivenessDetectionException(
              errorCode: FaceLivenessDetectionErrorCode.genericError,
            );
          }

          if (!result) {
            isStarting = false;
            throw const FaceLivenessDetectionException(
              errorCode: FaceLivenessDetectionErrorCode.permissionDenied,
            );
          }

          break;
        case FaceLivenessDetectionState.denied:
          isStarting = false;
          throw const FaceLivenessDetectionException(
            errorCode: FaceLivenessDetectionErrorCode.permissionDenied,
          );
        case FaceLivenessDetectionState.authorized:
          break;
      }
    }

    // Start the camera and liveness with arguments
    Map<String, dynamic>? startResult = {};
    try {
      startResult = await _methodChannel.invokeMapMethod<String, dynamic>(
        'start',
        _argumentsToMap(cameraFacingOverride: cameraFacingOverride),
      );
    } on PlatformException catch (error) {
      FaceLivenessDetectionErrorCode errorCode =
          FaceLivenessDetectionErrorCode.genericError;

      final String? errorMessage = error.message;

      if (kIsWeb) {
        if (errorMessage == null) {
          errorCode = FaceLivenessDetectionErrorCode.genericError;
        } else if (errorMessage.contains('NotFoundError') ||
            errorMessage.contains('NotSupportedError')) {
          errorCode = FaceLivenessDetectionErrorCode.unsupported;
        } else if (errorMessage.contains('NotAllowedError')) {
          errorCode = FaceLivenessDetectionErrorCode.permissionDenied;
        } else {
          errorCode = FaceLivenessDetectionErrorCode.genericError;
        }
      }

      isStarting = false;

      throw FaceLivenessDetectionException(
        errorCode: errorCode,
        errorDetails: FaceLivenessDetectionErrorDetails(
          code: error.code,
          details: error.details as Object?,
          message: error.message,
        ),
      );
    }

    if (startResult == null) {
      isStarting = false;
      throw const FaceLivenessDetectionException(
        errorCode: FaceLivenessDetectionErrorCode.genericError,
      );
    }

    final Size size;

    if (kIsWeb) {
      size = Size(
        startResult['videoWidth'] as double? ?? 0,
        startResult['videoHeight'] as double? ?? 0,
      );
    } else {
      final Map<Object?, Object?>? sizeInfo =
          startResult['size'] as Map<Object?, Object?>?;

      size = Size(
        sizeInfo?['width'] as double? ?? 0,
        sizeInfo?['height'] as double? ?? 0,
      );
    }

    isStarting = false;
    return startArguments.value = FaceLivenessDetectionArguments(
      size: size,
      textureId: kIsWeb ? null : startResult['textureId'] as int?,
      webId: kIsWeb ? startResult['ViewID'] as String? : null,
    );
  }

  /// Stops the camera and liveness, but does not dispose this controller.
  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stop');
    } catch (e) {
      debugPrint('$e');
    }
  }

  /// Restart the liveness
  Future<void> restart() async {
    try {
      await _methodChannel.invokeMethod('restart');
    } catch (e) {
      debugPrint('$e');
    }
  }

  /// Pause the liveness
  Future<void> pause() async {
    try {
      await _methodChannel.invokeMethod('pause');
    } catch (e) {
      debugPrint('$e');
    }
  }

  /// Changes the state of the camera (front or back).
  ///
  /// Does nothing if the device has no front camera.
  Future<void> switchCamera() async {
    await _methodChannel.invokeMethod('stop');
    final CameraFacing facingToUse =
        cameraFacingState.value == CameraFacing.back
            ? CameraFacing.front
            : CameraFacing.back;
    await start(cameraFacingOverride: facingToUse);
  }

  /// Disposes the FaceLivenessDetectionController and closes all listeners.
  ///
  /// If you call this, you cannot use this controller object anymore.
  void dispose() {
    stop();
    events?.cancel();
    _livenessController.close();
  }

  /// Handles a returning event from the platform side
  void _handleEvent(Map event) {
    final name = event['name'];
    final data = event['data'];

    switch (name) {
      case 'state':
        final event = FaceLivenessDetectionCapture(
          state: LivenessState.mapIntToLivenessState(data as int),
        );
        _livenessController.add(event);
        break;
      case 'success':
        final image = event['image'] as List<int>;
        final scores = event['scores'] as String?;
        final livenessData = FaceLivenessDetectionCapture(
          state: LivenessState.notStart,
          image: Uint8List.fromList(image),
          scores: scores,
        );
        _livenessController.add(livenessData);
        pause();
        break;
      case 'error':
        _livenessController.addError(
          FaceLivenessDetectionException(
            errorCode: FaceLivenessDetectionErrorCode.genericError,
            errorDetails:
                FaceLivenessDetectionErrorDetails(message: data as String?),
          ),
        );
        pause();
      default:
        _livenessController.addError(UnimplementedError(name as String?));
    }
  }

  /// updates the native ScanWindow
  Future<void> updateScanWindow(Rect? window) async {
    List? data;
    if (window != null) {
      data = [window.left, window.top, window.right, window.bottom];
    }
    await _methodChannel.invokeMethod('updateScanWindow', {'rect': data});
  }

  Future<String?> getSdkVersion() async {
    final String? version = await _methodChannel.invokeMethod('getSdkVersion');
    return version;
  }
}
