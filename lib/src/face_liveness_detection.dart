import 'dart:async';

import 'package:face_liveness_detection/src/enums/liveness_state.dart';
import 'package:face_liveness_detection/src/face_liveness_detection_controller.dart';
import 'package:face_liveness_detection/src/face_liveness_detection_exception.dart';
import 'package:face_liveness_detection/src/objects/face_liveness_detection_arguments.dart';
import 'package:face_liveness_detection/src/objects/face_liveness_detection_capture.dart';
import 'package:face_liveness_detection/src/objects/face_liveness_detection_success.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The function signature for the error builder.
typedef FaceLivenessDetectionErrorBuilder = Widget Function(
  BuildContext,
  FaceLivenessDetectionException,
  Widget?,
);

/// The [FaceLivenessDetection] widget displays a live camera preview.
class FaceLivenessDetection extends StatefulWidget {
  /// The controller that manages the face liveness scanner.
  ///
  /// If this is null, the scanner will manage its own controller.
  final FaceLivenessDetectionController? controller;

  /// The function that builds an error widget when the scanner
  /// could not be started.
  ///
  /// If this is null, defaults to a black [ColoredBox]
  /// with a centered white [Icons.error] icon.
  final FaceLivenessDetectionErrorBuilder? errorBuilder;

  /// The [BoxFit] for the camera preview.
  ///
  /// Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// The function that signals when new codes were detected by the [controller].
  final void Function(LivenessState livenessState) onDetect;

  /// The function that signals when face liveness success.
  final void Function(FaceLivenessDetectionSuccess data) onSuccess;

  /// The function that signals when face liveness error.
  final void Function(FaceLivenessDetectionException error)? onError;

  /// The function that signals when the face liveness detection is started.
  final void Function(FaceLivenessDetectionArguments? arguments)?
      onScannerStarted;

  /// The function that builds a placeholder widget when the scanner
  /// is not yet displaying its camera preview.
  ///
  /// If this is null, a black [ColoredBox] is used as placeholder.
  final Widget Function(BuildContext, Widget?)? placeholderBuilder;

  /// if set barcodes will only be scanned if they fall within this [Rect]
  /// useful for having a cut-out overlay for example. these [Rect]
  /// coordinates are relative to the widget size, so by how much your
  /// rectangle overlays the actual image can depend on things like the
  /// [BoxFit]
  final Rect? scanWindow;

  /// Only set this to true if you are starting another instance of mobile_scanner
  /// right after disposing the first one, like in a PageView.
  ///
  /// Default: false
  final bool startDelay;

  /// The overlay which will be painted above the scanner when has started successful.
  /// Will no be pointed when an error occurs or the scanner hasn't be started yet.
  final Widget? overlay;

  /// Create a new [FaceLivenessDetection] using the provided [controller]
  /// and [onBarcodeDetected] callback.
  const FaceLivenessDetection({
    this.controller,
    this.errorBuilder,
    this.fit = BoxFit.cover,
    required this.onDetect,
    required this.onSuccess,
    this.onError,
    this.onScannerStarted,
    this.placeholderBuilder,
    this.scanWindow,
    this.startDelay = false,
    this.overlay,
    super.key,
  });

  @override
  State<FaceLivenessDetection> createState() => _FaceLivenessDetectionState();
}

class _FaceLivenessDetectionState extends State<FaceLivenessDetection>
    with WidgetsBindingObserver {
  /// The subscription that listens to barcode detection.
  StreamSubscription<FaceLivenessDetectionCapture>? _livenessSubscription;

  /// The internally managed controller.
  late FaceLivenessDetectionController _controller;

  /// Whether the controller should resume
  /// when the application comes back to the foreground.
  bool _resumeFromBackground = false;

  FaceLivenessDetectionException? _startException;

  Rect? _scanWindow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? FaceLivenessDetectionController();
    if (widget.scanWindow == null) _controller.updateScanWindow(_scanWindow);
    _startScanner();
  }

  /// Start the given [scanner].
  Future<void> _startScanner() async {
    if (widget.startDelay) {
      await Future.delayed(const Duration(seconds: 1, milliseconds: 500));
    }

    _livenessSubscription ??= _controller.liveness.listen(
      (liveness) {
        final state = liveness.state;
        final image = liveness.image;
        final scores = liveness.scores;
        if (image != null && scores != null) {
          widget.onSuccess(
            FaceLivenessDetectionSuccess(
              image: image,
              scores: scores,
            ),
          );
        } else {
          widget.onDetect(state);
        }
      },
      onError: (error) {
        widget.onError?.call(error);
      },
    );

    if (!_controller.autoStart) {
      debugPrint(
        'face_liveness_detection: not starting automatically because autoStart is set to false in the controller.',
      );
      return;
    }

    _controller.start().then((arguments) {
      widget.onScannerStarted?.call(arguments);
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _startException = error as FaceLivenessDetectionException;
        });
      }
    });
  }

  /// the [scanWindow] rect will be relative and scaled to the [widgetSize] not the texture. so it is possible,
  /// depending on the [fit], for the [scanWindow] to partially or not at all overlap the [textureSize]
  ///
  /// since when using a [BoxFit] the content will always be centered on its parent. we can convert the rect
  /// to be relative to the texture.
  ///
  /// since the textures size and the actual image (on the texture size) might not be the same, we also need to
  /// calculate the scanWindow in terms of percentages of the texture, not pixels.
  Rect _calculateScanWindowRelativeToTextureInPercentage(
    BoxFit fit,
    Rect scanWindow,
    Size textureSize,
    Size widgetSize,
  ) {
    double fittedTextureWidth;
    double fittedTextureHeight;

    switch (fit) {
      case BoxFit.contain:
        final widthRatio = widgetSize.width / textureSize.width;
        final heightRatio = widgetSize.height / textureSize.height;
        final scale = widthRatio < heightRatio ? widthRatio : heightRatio;
        fittedTextureWidth = textureSize.width * scale;
        fittedTextureHeight = textureSize.height * scale;
        break;

      case BoxFit.cover:
        final widthRatio = widgetSize.width / textureSize.width;
        final heightRatio = widgetSize.height / textureSize.height;
        final scale = widthRatio > heightRatio ? widthRatio : heightRatio;
        fittedTextureWidth = textureSize.width * scale;
        fittedTextureHeight = textureSize.height * scale;
        break;

      case BoxFit.fill:
        fittedTextureWidth = widgetSize.width;
        fittedTextureHeight = widgetSize.height;
        break;

      case BoxFit.fitHeight:
        final ratio = widgetSize.height / textureSize.height;
        fittedTextureWidth = textureSize.width * ratio;
        fittedTextureHeight = widgetSize.height;
        break;

      case BoxFit.fitWidth:
        final ratio = widgetSize.width / textureSize.width;
        fittedTextureWidth = widgetSize.width;
        fittedTextureHeight = textureSize.height * ratio;
        break;

      case BoxFit.none:
      case BoxFit.scaleDown:
        fittedTextureWidth = textureSize.width;
        fittedTextureHeight = textureSize.height;
        break;
    }

    final offsetX = (widgetSize.width - fittedTextureWidth) / 2;
    final offsetY = (widgetSize.height - fittedTextureHeight) / 2;

    final left = (scanWindow.left - offsetX) / fittedTextureWidth;
    final top = (scanWindow.top - offsetY) / fittedTextureHeight;
    final right = (scanWindow.right - offsetX) / fittedTextureWidth;
    final bottom = (scanWindow.bottom - offsetY) / fittedTextureHeight;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Widget _buildPlaceholderOrError(BuildContext context, Widget? child) {
    final error = _startException;

    if (error != null) {
      return widget.errorBuilder?.call(context, error, child) ??
          const ColoredBox(
            color: Colors.black,
            child: Center(child: Icon(Icons.error, color: Colors.white)),
          );
    }

    return widget.placeholderBuilder?.call(context, child) ??
        const ColoredBox(color: Colors.black);
  }

  Widget _buildScanner(Size size, String? webId, int? textureId) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (_, constraints) {
          return SizedBox.fromSize(
            size: constraints.biggest,
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: kIsWeb
                    ? HtmlElementView(viewType: webId!)
                    : Texture(textureId: textureId!),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before the controller was initialized.
    if (_controller.isStarting) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_resumeFromBackground) _startScanner();
        break;
      case AppLifecycleState.inactive:
        _resumeFromBackground = true;
        _controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _controller.updateScanWindow(null);
    WidgetsBinding.instance.removeObserver(this);
    _livenessSubscription?.cancel();
    _livenessSubscription = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    return ValueListenableBuilder<FaceLivenessDetectionArguments?>(
      valueListenable: _controller.startArguments,
      builder: (context, value, child) {
        if (value == null) {
          return _buildPlaceholderOrError(context, child);
        }
        final scanWindow = widget.scanWindow;
        if (scanWindow != null && _scanWindow == null) {
          _scanWindow = _calculateScanWindowRelativeToTextureInPercentage(
            widget.fit,
            scanWindow,
            value.size,
            size,
          );
          _controller.updateScanWindow(_scanWindow);
        }
        final overlay = widget.overlay;
        if (overlay != null) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildScanner(value.size, value.webId, value.textureId),
              overlay,
            ],
          );
        } else {
          return _buildScanner(value.size, value.webId, value.textureId);
        }
      },
    );
  }
}
