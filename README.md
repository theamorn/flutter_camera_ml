# Camera ML Example

This template serves as a starting point for implementing a Camera and connecting it to a Native SDK, sending the results back to Flutter.

## Getting Started

This project is associated with the article available at:
[Implementing Face Liveness Detection in Flutter with High Performance](https://medium.com/kbtg-life/implementing-face-liveness-detection-in-flutter-with-high-performance-6997edd28b29)

To use this template, follow these steps:

### iOS
1. Change `FaceLivenessDelegate.swift`: Implement your own callback or delegate from the SDK. Adjust the interface based on your SDK.
2. `FaceLivenessDetection.swift`: Add the initial setup for your ML to replace our initial SDK.
3. `FaceLivenessDetection.swift`: Add your ML processing here and replace it with our feeding logic.
4. You can change the camera resolution with this line: `captureSession.sessionPreset = .photo`. Currently, it's set to the maximum.

### Android
1. Change `FaceLivenessListener.kt` and replace `YourSDKDelegate` with your callback.
2. Change `FaceLivenessDetection.kt`: Add the initial setup for your ML and your ML processing.
3. You can change the camera resolution at `ResolutionStrategy` on line 45. I added a parameter from Dart to adjust the resolution based on the controller from Flutter.

Please note that this template is not a one-size-fits-all solution, but it provides a solid starting point (around 70-80% completion). You will need to implement the remaining functionality and customize it to meet your specific requirements.

Enjoy coding!
