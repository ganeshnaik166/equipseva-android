package com.equipseva.app.core.storage

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

/**
 * Strips EXIF metadata (including GPS) from image bytes before upload by decoding and
 * re-encoding the bitmap. The re-encoded stream has no EXIF container. Orientation from the
 * original EXIF is baked into the pixel data so images still display the right way up.
 *
 * PNG and WebP are returned as-is when the caller wants to preserve lossless-ness; for JPEG
 * (by far the common case from the system camera / gallery) we always re-encode.
 *
 * If decoding fails (corrupt input, unsupported format), the original bytes are returned —
 * the server-side bucket scan remains the authoritative check.
 */
object ExifScrubber {

    private const val JPEG_QUALITY = 90

    fun strip(bytes: ByteArray, contentType: String?): ByteArray {
        if (!UploadValidator.isImage(contentType)) return bytes
        val mime = contentType?.substringBefore(';')?.trim()?.lowercase()
        // Only re-encode JPEG. PNG has no EXIF container in the strict sense; WebP's EXIF
        // handling is stream-fragile — for those we keep the bytes and let the bucket-side
        // scan handle residuals.
        if (mime != "image/jpeg") return bytes

        return runCatching {
            val orientation = ByteArrayInputStream(bytes).use { stream ->
                ExifInterface(stream).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )
            }
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: return@runCatching bytes
            val oriented = applyOrientation(bitmap, orientation)
            val out = ByteArrayOutputStream(bytes.size)
            oriented.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
            if (oriented !== bitmap) bitmap.recycle()
            oriented.recycle()
            out.toByteArray()
        }.getOrElse { bytes }
    }

    private fun applyOrientation(src: Bitmap, orientation: Int): Bitmap {
        if (orientation == ExifInterface.ORIENTATION_NORMAL ||
            orientation == ExifInterface.ORIENTATION_UNDEFINED
        ) return src
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(270f); m.postScale(-1f, 1f) }
            else -> return src
        }
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    }
}
