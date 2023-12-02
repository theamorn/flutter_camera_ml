import Flutter
import UIKit
import AVFoundation

public class FaceLivenessDetectionPlugin: NSObject, FlutterPlugin {
    
    private let liveness: FaceLivenessDetection
    
    private let handler: FaceLivenessHandler
    
    init(handler: FaceLivenessHandler, register: FlutterTextureRegistry) {
        self.handler = handler
        self.liveness = FaceLivenessDetection(
            registry: register,
            callback: { image, scores in
                handler.publishEvent([
                    "name": "success",
                    "image": FlutterStandardTypedData(bytes: image.jpegData(compressionQuality: 0.4)!),
                    "scores": scores
                ])
            },
            statusUpdateCallback: { state in
                handler.publishEvent(["name": "state", "data": state])
            },
            errorCallback: { error in
                handler.publishEvent(["name": "error", "data": error])
            }
        )
        super.init()
    }


    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FaceLivenessDetectionPlugin(handler: FaceLivenessHandler(registrar: registrar), register: registrar.textures())
        let channel = FlutterMethodChannel(name: "com.kbtg.face_liveness_detector/liveness/method", binaryMessenger: registrar.messenger())
        
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermission":
            checkPermission(result)
        case "requestPermission":
            requestPermission(result)
        case "start": start(call, result)
        case "stop": stop(result)
        case "restart": restart(result)
        case "pause": pause(result)
        case "updateScanWindow":
            updateScanWindow(call, result)
        case "getSdkVersion":
            getSdkVersion(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    
    private func start(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let params = call.arguments as! Dictionary<String, Any?>
        let activeMode: Bool = params["activeMode"] as? Bool ?? false
        let facing: Int = params["facing"] as? Int ?? 0
        let timeout: Int? = params["timeout"] as? Int
        let position = facing == 0 ? AVCaptureDevice.Position.front : .back
        
        do {
            try liveness.start(
                activeMode: activeMode,
                cameraPosition: position,
                timeout: timeout
            ) { parameters in
                result([
                    "textureId": parameters.textureId,
                    "size": [
                        "width": parameters.width,
                        "height": parameters.height
                    ]
                ] as [String : Any])
            }     
        } catch FaceLivenessDetectionError.alreadyStarted {
            result(FlutterError(code: "FaceLivenessDetection",
                                message: "Called start() while already started!",
                                details: nil))
        } catch FaceLivenessDetectionError.noCamera {
            result(FlutterError(code: "FaceLivenessDetection",
                                message: "No camera found or failed to open camera!",
                                details: nil))
        } catch FaceLivenessDetectionError.cameraError(let error) {
            result(FlutterError(code: "FaceLivenessDetection",
                                message: "Error occured when setting up camera!",
                                details: error))
        } catch {
            result(FlutterError(code: "FaceLivenessDetection",
                                message: "Unknown error occured..",
                                details: nil))
        }
    }
    
    
    private func checkPermission( _ result: @escaping FlutterResult) {
        result(liveness.checkPermission())
    }
    
    private func requestPermission(_ result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { result($0) })
    }
    
    /// Stops the liveness and closes the texture
    private func stop(_ result: @escaping FlutterResult) {
        do {
            try liveness.stop()
        } catch {}
        result(nil)
    }
    
    /// Restart the liveness
    private func restart(_ result: @escaping FlutterResult) {
        liveness.restart()
        result(nil)
    }
    
    /// Pause the liveness
    private func pause(_ result: @escaping FlutterResult) {
        liveness.pause()
        result(nil)
    }
    
    /// Updates the scan window rectangle.
    private func updateScanWindow(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let scanWindowData: Array? = (call.arguments as? [String: Any])?["rect"] as? [CGFloat] ?? []
        liveness.setScanWindow(scanWindowData)
        result(nil)
    }
    
    private func getSdkVersion(_ result: @escaping FlutterResult) {
        result(liveness.version())
    }
}
