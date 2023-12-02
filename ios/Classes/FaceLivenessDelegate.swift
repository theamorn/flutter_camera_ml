import UIKit

// TODO: Implement your own Delegate here
class FaceLivenessDelegate: YourSDKDelegate {
    private let onSuccess: (UIImage, String) -> Void
    private let onUpdate: (Int) -> Void
    private let onError: (String) -> Void
    
    init(
        onSuccess: @escaping (UIImage, String) -> Void,
        onUpdate: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onSuccess = onSuccess
        self.onUpdate = onUpdate
        self.onError = onError
    }
    
    func onDetectOver(resultCode: LivenessKBTG.ResultCode, image: UIImage?, scores: String) {
        if resultCode == .OK {
            if let image = image {
                onSuccess(image, scores)
            } else {
                onError("STID_E_NO_IMAGE")
            }
        } else {
            onError(String(describing: resultCode))
        }
    }
    
    func onStatusUpdate(livenessState: LivenessKBTG.LivenessState) {
        let state: Int
        switch livenessState {
        case .NOTSTART:
            state = -1
        case .NORMAL:
            state = 0
        case .FACE_NOT_FOUND:
            state = 1
        case .FACE_NOT_FORWARD:
            state = 2
        case .TOO_LITTLE_BRIGHT:
            state = 3
        case .TOO_BRIGHT:
            state = 4
        case .TOO_CLOSE:
            state = 5
        case .TOO_FAR:
            state = 6
        case .NO_MOUTH:
            state = 7
        case .NO_EYE_LEFT:
            state = 8
        case .NO_EYE_RIGHT:
            state = 9
        case .NO_EYE:
            state = 10
        case .MULTIPLE_FACE:
            state = 11
        case .BACKGROUND_BRIGHT:
            state = 12
        case .TURN_FACE_LEFT:
            state = 13
        case .TURN_FACE_RIGHT:
            state = 14
        case .BLINK:
            state = 15
        case .SMILE:
            state = 16
        case .FACE_NOD:
            state = 17
        case .MOUTH_NOT_CLOSE:
            state = 18
        // case .CHANGE_ENVIRONMENT:
        //     state = 19
        // case .NOT_CENTER:
        //     state = 20
        default:
            state = 100
        }
        onUpdate(state)
    }
}
