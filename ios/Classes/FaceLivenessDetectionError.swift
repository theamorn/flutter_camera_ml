//
//  FaceLivenessDetectionError.swift
//  face_liveness_detection
//
import Foundation

enum FaceLivenessDetectionError: Error {
    case noCamera
    case alreadyStarted
    case alreadyStopped
    case cameraError(_ error: Error)
    case zoomWhenStopped
    case zoomError(_ error: Error)
    case analyzerError(_ error: Error)
}
