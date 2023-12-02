package com.kbtg.face_liveness_detection

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.camera.core.ImageProxy
import java.io.ByteArrayOutputStream


fun ImageProxy.toByteArrayYUV420(): ByteArray? {
    val nv21 = yuv420888ToNv21(this)
    val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
    return yuvImage.toByteArray()
}

private fun yuv420888ToNv21(image: ImageProxy): ByteArray {
    val pixelCount = image.cropRect.width() * image.cropRect.height()
    val pixelSizeBits = ImageFormat.getBitsPerPixel(ImageFormat.YUV_420_888)
    val outputBuffer = ByteArray(pixelCount * pixelSizeBits / 8)
    imageToByteBuffer(image, outputBuffer, pixelCount)
    return outputBuffer
}

private fun YuvImage.toByteArray(): ByteArray? {
    val out = ByteArrayOutputStream()
    if (!compressToJpeg(Rect(0, 0, width, height), 100, out)) return null
    return out.toByteArray()
}

private fun imageToByteBuffer(image: ImageProxy, outputBuffer: ByteArray, pixelCount: Int) {
    assert(image.format == ImageFormat.YUV_420_888)
    val imageCrop = image.cropRect
    val imagePlanes = image.planes
    imagePlanes.forEachIndexed { planeIndex, plane ->
        val outputStride: Int
        var outputOffset: Int
        when (planeIndex) {
            0 -> {
                outputStride = 1
                outputOffset = 0
            }

            1 -> {
                outputStride = 2
                // For NV21 format, U is in odd-numbered indices
                outputOffset = pixelCount + 1
            }

            2 -> {
                outputStride = 2
                // For NV21 format, V is in even-numbered indices
                outputOffset = pixelCount
            }

            else -> {
                // Image contains more than 3 planes, something strange is going on
                return@forEachIndexed
            }
        }
        val planeBuffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        // We have to divide the width and height by two if it's not the Y plane
        val planeCrop = if (planeIndex == 0) {
            imageCrop
        } else {
            Rect(
                imageCrop.left / 2, imageCrop.top / 2, imageCrop.right / 2, imageCrop.bottom / 2
            )
        }
        val planeWidth = planeCrop.width()
        val planeHeight = planeCrop.height()
        // Intermediate buffer used to store the bytes of each row
        val rowBuffer = ByteArray(plane.rowStride)
        // Size of each row in bytes
        val rowLength = if (pixelStride == 1 && outputStride == 1) {
            planeWidth
        } else {
            (planeWidth - 1) * pixelStride + 1
        }
        for (row in 0 until planeHeight) {
            planeBuffer.position(
                (row + planeCrop.top) * rowStride + planeCrop.left * pixelStride
            )
            if (pixelStride == 1 && outputStride == 1) {
                planeBuffer.get(outputBuffer, outputOffset, rowLength)
                outputOffset += rowLength
            } else {
                planeBuffer.get(rowBuffer, 0, rowLength)
                for (col in 0 until planeWidth) {
                    outputBuffer[outputOffset] = rowBuffer[col * pixelStride]
                    outputOffset += outputStride
                }
            }
        }
    }
}

