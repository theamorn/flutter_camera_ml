package com.kbtg.face_liveness_detection

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** FaceLivenessDetectionPlugin */
class FaceLivenessDetectionPlugin : FlutterPlugin, ActivityAware {
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var methodCallHandler: FaceLivenessDetectionHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = null
    }

    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        val binaryMessenger = this.flutterPluginBinding!!.binaryMessenger

        methodCallHandler = FaceLivenessDetectionHandler(
            activityPluginBinding.activity,
            FaceLivenessHandler(binaryMessenger),
            binaryMessenger,
            FaceLivenessDetectionPermissions(),
            activityPluginBinding::addRequestPermissionsResultListener,
            this.flutterPluginBinding!!.textureRegistry,
        )

        this.activityPluginBinding = activityPluginBinding
    }

    override fun onDetachedFromActivity() {
        methodCallHandler?.dispose(this.activityPluginBinding!!)
        methodCallHandler = null
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}
