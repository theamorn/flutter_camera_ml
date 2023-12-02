typealias FaceLivenessDetectionCallback = (UIImage, String) -> Void

typealias FaceLivenessDetectionStatusUpdateCallback = (Int) -> Void

typealias FaceLivenessDetectionErrorCallback = (String) -> Void

typealias FaceLivenessDetectionStartedCallback = (FaceLivenessDetectionStartParameters) -> Void


struct FaceLivenessDetectionStartParameters {
    var width: Double = 0.0
    var height: Double = 0.0
    var textureId: Int64 = 0
}
