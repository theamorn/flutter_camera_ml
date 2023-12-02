package com.kbtg.face_liveness_detection

import android.graphics.Bitmap
import com.kbtg.face_liveness_detection.objects.FaceLivenessDetectionStartParameters

typealias FaceLivenessDetectionCallback = (image: Bitmap, scores: String) -> Unit
typealias FaceLivenessDetectionStatusUpdateCallback = (state: Int) -> Unit
typealias FaceLivenessDetectionErrorCallback = (error: String) -> Unit
typealias FaceLivenessDetectionStartedCallback = (parameters: FaceLivenessDetectionStartParameters) -> Unit
