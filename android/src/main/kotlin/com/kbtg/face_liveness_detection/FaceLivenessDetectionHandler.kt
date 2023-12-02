package com.kbtg.face_liveness_detection

import android.app.Activity
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import com.kbtg.liveness.SilentLivenessApi
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream

class FaceLivenessDetectionHandler(
    private val activity: Activity,
    private val faceLivenessHandler: FaceLivenessHandler,
    binaryMessenger: BinaryMessenger,
    private val permissions: FaceLivenessDetectionPermissions,
    private val addPermissionListener: (RequestPermissionsResultListener) -> Unit,
    textureRegistry: TextureRegistry
) : MethodChannel.MethodCallHandler {


    private fun convertBitmapToByteArray(bitmap: Bitmap): ByteArray {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 40, outputStream)
        return outputStream.toByteArray()
    }

    private val callback: FaceLivenessDetectionCallback = { image, scores ->
        faceLivenessHandler.publishEvent(
            mapOf(
                "name" to "success", "image" to convertBitmapToByteArray(image), "scores" to scores
            )
        )
    }

    private val statusUpdateCallback: FaceLivenessDetectionStatusUpdateCallback = { state ->
        faceLivenessHandler.publishEvent(mapOf("name" to "state", "data" to state))
    }

    private val errorCallback: FaceLivenessDetectionErrorCallback = { error: String ->
        faceLivenessHandler.publishEvent(mapOf("name" to "error", "data" to error))
    }

    private var methodChannel: MethodChannel? = null

    private var faceLivenessDetection: FaceLivenessDetection? = null

    init {
        methodChannel = MethodChannel(
            binaryMessenger, "com.kbtg.face_liveness_detector/liveness/method"
        )
        methodChannel?.setMethodCallHandler(this)
        faceLivenessDetection = FaceLivenessDetection(
            activity, textureRegistry, callback, statusUpdateCallback, errorCallback
        )
    }

    fun dispose(activityPluginBinding: ActivityPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        faceLivenessDetection = null

        val listener: RequestPermissionsResultListener? = permissions.getPermissionListener()

        if (listener != null) {
            activityPluginBinding.removeRequestPermissionsResultListener(listener)
        }

    }

    @ExperimentalGetImage
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (faceLivenessDetection == null) {
            result.error(
                "FaceLivenessDetection", "Called ${call.method} before initializing.", null
            )
            return
        }
        when (call.method) {
            "checkPermission" -> result.success(permissions.hasCameraPermission(activity))
            "requestPermission" -> permissions.requestPermission(activity,
                addPermissionListener,
                object : FaceLivenessDetectionPermissions.ResultCallback {
                    override fun onResult(errorCode: String?, errorDescription: String?) {
                        when (errorCode) {
                            null -> result.success(true)
                            FaceLivenessDetectionPermissions.CAMERA_ACCESS_DENIED -> result.success(
                                false
                            )

                            else -> result.error(errorCode, errorDescription, null)
                        }
                    }
                })

            "start" -> start(call, result)
            "stop" -> stop(result)
            "restart" -> restart(result)
            "pause" -> pause(result)
            "updateScanWindow" -> updateScanWindow(call, result)
            "getSdkVersion" -> getSdkVersion(result)
            else -> result.notImplemented()
        }
    }

    @ExperimentalGetImage
    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val activeMode: Boolean = call.argument<Boolean>("activeMode") ?: false
        val facing: Int? = call.argument<Int>("facing")
        val timeout: Int? = call.argument<Int>("timeout")
        val cameraResolutionValues: List<Int>? = call.argument<List<Int>>("cameraResolution")
        val cameraResolution: Size? = if (cameraResolutionValues != null) {
            Size(cameraResolutionValues[0], cameraResolutionValues[1])
        } else {
            null
        }

        val position =
            if (facing == 0) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
        faceLivenessDetection?.start(
            activeMode, position, timeout, startedCallback = {
                result.success(
                    mapOf(
                        "textureId" to it.id,
                        "size" to mapOf(
                            "width" to it.width, "height" to it.height
                        ),
                    )
                )
            }, errorCallback = {
                Handler(Looper.getMainLooper()).post {
                    when (it) {
                        is AlreadyStarted -> {
                            result.error(
                                "FaceLivenessDetection",
                                "Called start() while already started",
                                null
                            )
                        }

                        is CameraError -> {
                            result.error(
                                "FaceLivenessDetection",
                                "Error occurred when setting up camera!",
                                null
                            )
                        }

                        is NoCamera -> {
                            result.error(
                                "FaceLivenessDetection",
                                "No camera found or failed to open camera!",
                                null
                            )
                        }

                        else -> {
                            result.error(
                                "FaceLivenessDetection", "Unknown error occurred.", null
                            )
                        }
                    }
                }
            }, cameraResolution
        )
    }


    private fun stop(result: MethodChannel.Result) {
        try {
            faceLivenessDetection?.stop()
            result.success(null)
        } catch (e: AlreadyStopped) {
            result.success(null)
        }
    }

    private fun restart(result: MethodChannel.Result) {
        faceLivenessDetection?.restart()
        result.success(null)
    }
    private fun pause(result: MethodChannel.Result) {
        faceLivenessDetection?.pause()
        result.success(null)
    }

    private fun updateScanWindow(call: MethodCall, result: MethodChannel.Result) {
        faceLivenessDetection?.setScanWindow(call.argument<List<Float>?>("rect") ?: listOf())
        result.success(null)
    }

    private fun getSdkVersion(result: MethodChannel.Result) {
        result.success(faceLivenessDetection?.version())
    }
}

