package com.kbtg.face_liveness_detection

import android.graphics.Bitmap
import com.kbtg.liveness.OnLivenessListener
import android.graphics.BitmapFactory

class FaceLivenessListener(
    private val onSuccess: FaceLivenessDetectionCallback,
    private val onUpdate: FaceLivenessDetectionStatusUpdateCallback,
    private val onError: FaceLivenessDetectionErrorCallback
) : YourSDKDelegate {

    private fun mapResultIntToString(input: Int): String {
        return when (input) {
            0 -> "OK"
            1 -> "STID_E_TIMEOUT"
            2 -> "STID_E_FAIL"
            3 -> "STID_E_KEY_NOT_FOUND"
            4 -> "STID_E_NETWORK"
            5 -> "STID_E_INVALID_REQUEST"
            6 -> "STID_E_SESSION_NOT_FOUND"
            7 -> "STID_E_SESSION_INVALID"
            8 -> "STID_E_PARTNER_NOT_FOUND"
            9 -> "STID_E_LICENSE_INVALID"
            10 -> "STID_E_UNAUTHORIZED"
            11 -> "STID_E_NOT_SET_ENVIRONMENT"
            else -> "UNKNOWN"
        }
    }

    override fun onDetectOver(resultCode: Int, image: ByteArray, scores: String) {
        if (resultCode == 0) {
            val bitmap = BitmapFactory.decodeByteArray(image, 0, image.size)
            onSuccess(bitmap, scores)
        } else {
            onError(mapResultIntToString(resultCode))
        }
    }

    override fun onStatusUpdate(livenessState: Int) {
        onUpdate(livenessState)
    }
}

