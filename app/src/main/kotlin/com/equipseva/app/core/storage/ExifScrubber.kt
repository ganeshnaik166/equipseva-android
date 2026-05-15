package com.equipseva.app.core.storage

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.core.util.MIME_PNG
import com.equipseva.app.core.util.MIME_WEBP
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

/**
 * Strips EXIF metadata (including GPS) from image bytes before upload by decoding and
 * re-encoding the bitmap. The re-encoded stream has no EXIF container. Orientation from the
 * original EXIF is baked into the pixel data so images still display the right way up.
 *
 * Round 237: PNG and WebP also carry EXIF (eXIf chunk + EXIF chunk respectively) plus XMP
 * tEXt chunks that can hold GPS / device id. Re-encode each format to itself — PNG and
 * WebP lossless via Bitmap.CompressFormat so we don't degrade KYC document scans.
 *
 * If decoding fails (corrupt input, unsupported format), the original bytes are returned —
 * the server-side bucket scan remains the authoritative check.
 */
object ExifScrubber {

    private const val JPEG_QUALITY = 90
    // WebP quality is ignored when LOSSLESS is the format on API 30+, but
    // we set it for the deprecated lossy fallback used on older devices.
    private const val WEBP_QUALITY = 90

    fun strip(bytes: ByteArray, contentType: String?): ByteArray {
        if (!UploadValidator.isImage(contentType)) return bytes
        val mime = contentType?.substringBefore(';')?.trim()?.lowercase()

        // Pick the re-encode format. Unrecognised image mimes fall through
        // to bytes-as-is rather than misidentifying the format.
        val format = when (mime) {
            MIME_JPEG -> Bitmap.CompressFormat.JPEG
            MIME_PNG -> Bitmap.CompressFormat.PNG
            MIME_WEBP -> if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                Bitmap.CompressFormat.WEBP_LOSSLESS
            } else {
                @Suppress("DEPRECATION")
                Bitmap.CompressFormat.WEBP
            }
            else -> return bytes
        }
        val quality = when (mime) {
            MIME_JPEG -> JPEG_QUALITY
            MIME_PNG -> 100 // ignored for PNG, but pass valid value
            MIME_WEBP -> WEBP_QUALITY
            else -> 100
        }

        return runCatching {
            // Orientation tag is JPEG/EXIF only — PNG and WebP don't carry
            // it in a place ExifInterface can read, so the bitmap decoder
            // already returns pixels in display order for those formats.
            val orientation = if (mime == MIME_JPEG) {
                ByteArrayInputStream(bytes).use { stream ->
                    ExifInterface(stream).getAttributeInt(
                        ExifInterface.TAG_ORIENTATION,
                        ExifInterface.ORIENTATION_NORMAL,
                    )
                }
            } else {
                ExifInterface.ORIENTATION_NORMAL
            }
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: return@runCatching bytes
            val oriented = applyOrientation(bitmap, orientation)
            val out = ByteArrayOutputStream(bytes.size)
            oriented.compress(format, quality, out)
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
