package com.kbtg.face_liveness_detection

import android.app.Activity
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Build
import android.util.Size
import android.view.Surface
import android.view.WindowManager
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.core.resolutionselector.ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.kbtg.face_liveness_detection.objects.FaceLivenessDetectionStartParameters
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

class FaceLivenessDetection(
    private val activity: Activity,
    private val textureRegistry: TextureRegistry,
    private val callback: FaceLivenessDetectionCallback,
    private val statusUpdateCallback: FaceLivenessDetectionStatusUpdateCallback,
    private val errorCallback: FaceLivenessDetectionErrorCallback
) {
    /// Internal variables
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var displayListener: DisplayManager.DisplayListener? = null
    private var liveness: SilentLivenessApi? = null

    /// Configurable variables
    private var scanWindow: List<Float>? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Default)
    private var activeMode = true
    private var timeout = 40000
    private var isAlreadySetup = false
    private var isStarted = false

    fun setScanWindow(scanWindow: List<Float>) {
        this.scanWindow = scanWindow
    }

    // Return the best resolution for the actual device orientation.
    //
    // By default the resolution is 480x640, which is too low for ML Kit.
    // If the given resolution is not supported by the display,
    // the closest available resolution is used.
    //
    // The resolution should be adjusted for the display rotation, to preserve the aspect ratio.
    @Suppress("deprecation")
    private fun getResolution(cameraResolution: Size): Size {
        val rotation = if (Build.VERSION.SDK_INT >= 30) {
            activity.display!!.rotation
        } else {
            val windowManager =
                activity.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            windowManager.defaultDisplay.rotation
        }

        val widthMaxRes = cameraResolution.width
        val heightMaxRes = cameraResolution.height

        val targetResolution =
            if (rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_180) {
                Size(widthMaxRes, heightMaxRes) // Portrait mode
            } else {
                Size(heightMaxRes, widthMaxRes) // Landscape mode
            }
        return targetResolution
    }

    /**
     * Start face liveness detection by initializing the camera and liveness.
     */
    @ExperimentalGetImage
    fun start(
        activeMode: Boolean,
        cameraPosition: CameraSelector,
        timeout: Int?,
        startedCallback: FaceLivenessDetectionStartedCallback,
        errorCallback: (exception: Exception) -> Unit,
        cameraResolution: Size?
    ) {
        this.activeMode = activeMode
        this.timeout = timeout ?: this.timeout

        if (camera?.cameraInfo != null && preview != null && textureEntry != null) {
            errorCallback(AlreadyStarted())
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        val executor = ContextCompat.getMainExecutor(activity)

        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            if (cameraProvider == null) {
                errorCallback(CameraError())
                return@addListener
            }
            cameraProvider?.unbindAll()
            textureEntry = textureRegistry.createSurfaceTexture()

            // Preview
            val surfaceProvider = Preview.SurfaceProvider { request ->
                if (isStopped()) {
                    return@SurfaceProvider
                }
                val texture = textureEntry?.surfaceTexture()
                texture?.setDefaultBufferSize(
                    request.resolution.width, request.resolution.height
                )
                val surface = Surface(texture)
                request.provideSurface(surface, executor) { }
            }

            // Build the preview to be shown on the Flutter texture
            val previewBuilder = Preview.Builder()
            preview = previewBuilder.build().apply { setSurfaceProvider(surfaceProvider) }

            // Build the analyzer to be passed on to MLKit
            val analysisBuilder = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            val displayManager =
                activity.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

            if (cameraResolution != null) {
                val selector = ResolutionSelector.Builder().setResolutionStrategy(
                    ResolutionStrategy(
                        getResolution(cameraResolution), FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
                    )
                )
                analysisBuilder.setResolutionSelector(selector.build())

                if (displayListener == null) {
                    displayListener = object : DisplayManager.DisplayListener {
                        override fun onDisplayAdded(displayId: Int) {}

                        override fun onDisplayRemoved(displayId: Int) {}

                        override fun onDisplayChanged(displayId: Int) {
                            analysisBuilder.setResolutionSelector(selector.build())
                        }
                    }

                    displayManager.registerDisplayListener(
                        displayListener, null,
                    )
                }
            }

            val analysis = analysisBuilder.build().apply { setAnalyzer(executor, captureOutput) }

            try {
                camera = cameraProvider?.bindToLifecycle(
                    activity as LifecycleOwner, cameraPosition, preview, analysis
                )
            } catch (exception: Exception) {
                errorCallback(NoCamera())

                return@addListener
            }

            val resolution = analysis.resolutionInfo!!.resolution
            val width = resolution.width.toDouble()
            val height = resolution.height.toDouble()
            val portrait = (camera?.cameraInfo?.sensorRotationDegrees ?: 0) % 180 == 0

            startedCallback(
                FaceLivenessDetectionStartParameters(
                    if (portrait) width else height,
                    if (portrait) height else width,
                    textureEntry!!.id()
                )
            )
        }, executor)

    }

    /**
     * Stop face liveness detection.
     */
    fun stop() {
        if (isStopped()) {
            throw AlreadyStopped()
        }

        if (displayListener != null) {
            val displayManager =
                activity.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

            displayManager.unregisterDisplayListener(displayListener)
            displayListener = null
        }

        cameraProvider?.unbindAll()
        textureEntry?.release()
        camera = null
        preview = null
        textureEntry = null
        cameraProvider = null
        isAlreadySetup = false
        isStarted = false
    }

    fun pause() {
        isStarted = false
    }

    fun restart() {
        isAlreadySetup = false
    }

    fun version(): String {
        return "N/A"
    }

    private fun isStopped() = camera == null && preview == null

    private fun setUpLivenessSDK(
        rectCamera: Rect,
        rectMask: Rect,
    ) {
        // TODO: Add initial setup for your ML here

        isAlreadySetup = true;
    }

    private fun getCenterRect(inputImage: ImageProxy): Rect {
        val halfX = inputImage.height / 2
        val halfY = inputImage.width / 2
        val frameX = (inputImage.height * 0.55 / 2).roundToInt()
        val frameY = (inputImage.width * 0.55 / 2).roundToInt()

        return Rect(
            halfX - frameX,
            halfY - frameY,
            halfX + frameX,
            halfY + frameY,
        )
    }

    // scales the scanWindow to the provided inputImage and checks if that scaled
    private fun convertScanWindowArrayToRect(
        scanWindow: List<Float>?, inputImage: ImageProxy
    ): Rect {
        if (scanWindow.isNullOrEmpty()) return getCenterRect(inputImage)
        val imageWidth = inputImage.height
        val imageHeight = inputImage.width
        val left = (scanWindow[0] * imageWidth).roundToInt()
        val top = (scanWindow[1] * imageHeight).roundToInt()
        val right = (scanWindow[2] * imageWidth).roundToInt()
        val bottom = (scanWindow[3] * imageHeight).roundToInt()
        return Rect(left, top, right, bottom)
    }

    private fun isReadyToSetup(): Boolean {
        return !isAlreadySetup && !isStarted && scanWindow != null
    }

    private fun isReadyToProcess(): Boolean {
        return isAlreadySetup && isStarted
    }

    /**
     * callback for the camera. Every frame is passed through this function.
     */
    @ExperimentalGetImage
    val captureOutput = ImageAnalysis.Analyzer { imageProxy -> // YUV_420_888 format
        coroutineScope.launch {
            if (imageProxy.format == ImageFormat.YUV_420_888) {
                val rotation = imageProxy.imageInfo.rotationDegrees
                val imageByteArray = imageProxy.toByteArrayYUV420()
                if (imageByteArray != null) {
                    if (isReadyToSetup()) {
                        val rectCamera = Rect(0, 0, imageProxy.height, imageProxy.width)
                        val rectMask = convertScanWindowArrayToRect(scanWindow, imageProxy)
                        setUpLivenessSDK(rectCamera, rectMask)
                        isStarted = true
                    } else if (isReadyToProcess()) {
                        // TODO: Add your ML processing here
                    }
                }
                imageProxy.close()
            }
        }
    }
}
