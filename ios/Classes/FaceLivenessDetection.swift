import AVFoundation
import Flutter

class FaceLivenessDetection: NSObject, FlutterTexture {
    /// Capture session of the camera
    private var captureSession: AVCaptureSession?
    
    /// The selected camera
    private var device: AVCaptureDevice?
    
    /// If provided, the Flutter registry will be used to send the output of the CaptureOutput to a Flutter texture.
    private let registry: FlutterTextureRegistry?
    
    /// Image to be sent to the texture
    private var latestBuffer: CVImageBuffer?
    
    /// Texture id of the camera preview for Flutter
    private var textureId: Int64?
    
    /// optional window to limit scan search
    private var scanWindow: [CGFloat]?
    
    private var isProcessing = false
    
    private let backgroundQueue = DispatchQueue(label: "camera-handling")
    
    private let callback: FaceLivenessDetectionCallback
    
    private let statusUpdateCallback: FaceLivenessDetectionStatusUpdateCallback
    
    private let errorCallback: FaceLivenessDetectionErrorCallback
    
    private var activeMode = true
    
    private var timeout = 40000
    
    private var isAlreadySetup = false
    
    private var isStarted = false
        
    init(
        registry: FlutterTextureRegistry?,
        callback: @escaping FaceLivenessDetectionCallback,
        statusUpdateCallback: @escaping FaceLivenessDetectionStatusUpdateCallback,
        errorCallback: @escaping FaceLivenessDetectionErrorCallback
    ) {
        self.registry = registry
        self.callback = callback
        self.statusUpdateCallback = statusUpdateCallback
        self.errorCallback = errorCallback
        super.init()
    }
    
    func setScanWindow(_ scanWindow: [CGFloat]?) {
        self.scanWindow = scanWindow
    }
    
    func checkPermission() -> Int {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            return 0
        case .authorized:
            return 1
        default:
            return 2
        }
    }
    
    func start(
        activeMode: Bool,
        cameraPosition: AVCaptureDevice.Position,
        timeout: Int?,
        completion: @escaping (FaceLivenessDetectionStartParameters) -> ()) throws {
            
            self.activeMode = activeMode
            self.timeout = timeout ?? self.timeout
            
            if device != nil {
                throw FaceLivenessDetectionError.alreadyStarted
            }
            
            captureSession = AVCaptureSession()
            textureId = registry?.register(self)
            
            // Open the camera device
            if #available(iOS 13.0, *) {
                device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: cameraPosition).devices.first
            } else {
                device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: cameraPosition).devices.first
            }
            
            guard let device = device else {
                throw FaceLivenessDetectionError.noCamera
            }
            
            guard let captureSession = captureSession else {
                return
            }
            
            guard let textureId = textureId else {
                return
            }
            
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if #available(iOS 15.4, *) , device.isFocusModeSupported(.autoFocus) {
                    device.automaticallyAdjustsFaceDrivenAutoFocusEnabled = false
                }
                device.unlockForConfiguration()
            } catch { }
            
            captureSession.beginConfiguration()
            
            // Add device input
            do {
                let input = try AVCaptureDeviceInput(device: device)
                captureSession.addInput(input)
            } catch {
                throw FaceLivenessDetectionError.cameraError(error)
            }
            
            captureSession.sessionPreset = .photo;
            
            // Add video output.
            let videoOutput = AVCaptureVideoDataOutput()
            
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            // calls captureOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
            
            captureSession.addOutput(videoOutput)
            
            for connection in videoOutput.connections {
                connection.videoOrientation = .portrait
                if cameraPosition == .front && connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            
            captureSession.commitConfiguration()
            
            backgroundQueue.async {
                captureSession.startRunning()
                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                DispatchQueue.main.async {
                    completion(
                        FaceLivenessDetectionStartParameters(
                            width: Double(dimensions.height),
                            height: Double(dimensions.width),
                            textureId: textureId
                        )
                    )
                }
            }
        }
    
    func stop() throws {
        if device == nil {
            throw FaceLivenessDetectionError.alreadyStopped
        }
        captureSession?.stopRunning()
        for input in captureSession?.inputs ?? [] {
            captureSession?.removeInput(input)
        }
        for output in captureSession?.outputs ?? [] {
            captureSession?.removeOutput(output)
        }
        latestBuffer = nil
        if let textureId = textureId {
            registry?.unregisterTexture(textureId)
        }
        textureId = nil
        captureSession = nil
        device = nil
        isAlreadySetup = false;
        isStarted = false;
    }
    
    func pause() {
        isStarted = false
    }
    
    func restart() {
        isAlreadySetup = false
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let latestBuffer = latestBuffer else {
            return nil
        }
        return Unmanaged<CVPixelBuffer>.passRetained(latestBuffer)
    }

    func version() -> String {
        return "N/A"
    }
    
}

extension FaceLivenessDetection: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private func setUpLivenessSDK(_ rectCamera: CGRect, _ rectMask: CGRect) {
        // TODO: Add initial setup for your ML here
        
        isAlreadySetup = true
    }
    
    private func getCenterRect(_ inputImage: UIImage) -> CGRect {
        let halfX = inputImage.size.width / 2
        let halfY = inputImage.size.height / 2
        let frameX = inputImage.size.width * 0.55 / 2
        let frameY = inputImage.size.height * 0.55 / 2
     
        return CGRect(
            x: halfX - frameX,
            y: halfY - frameY,
            width: frameX * 2,
            height: frameY * 2
        )
    }
    
    private func convertScanWindowArrayToRect(_ scanWindow: [CGFloat]?, _ inputImage: UIImage) -> CGRect {
        guard let scanWindow = scanWindow, !scanWindow.isEmpty else {
            return getCenterRect(inputImage)
        }
        let imageWidth = inputImage.size.width
        let imageHeight = inputImage.size.height
        
        let minX = scanWindow[0] * imageWidth
        let minY = scanWindow[1] * imageHeight
        let width = scanWindow[2] * imageWidth - minX
        let height = scanWindow[3] * imageHeight - minY
        
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    private func convertCIImageToUIImage(ciImage: CIImage) -> UIImage? {
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = UIImage(cgImage: cgImage!)
        return image
    }
    
    private func isReadyToSetup() -> Bool {
        return !isAlreadySetup && !isStarted && scanWindow != nil
    }
    
    private func isReadyToProcess() -> Bool {
        return isAlreadySetup && isStarted
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let textureId = textureId else {
            return
        }
        
        latestBuffer = imageBuffer
        registry?.textureFrameAvailable(textureId)
        
        guard !self.isProcessing else { return }
        self.isProcessing = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            guard let image = self.convertCIImageToUIImage(ciImage: ciImage) else {
                self.isProcessing = false
                return
            }
            
            if self.isReadyToSetup() {
                let rectCamera = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                let rectMask = self.convertScanWindowArrayToRect(self.scanWindow, image)
                self.setUpLivenessSDK(rectCamera, rectMask)
                self.isStarted = true
            } else if self.isReadyToProcess() {
                // TODO: Add your ML processing here
            }
            
            self.isProcessing = false
        }
    }
}
