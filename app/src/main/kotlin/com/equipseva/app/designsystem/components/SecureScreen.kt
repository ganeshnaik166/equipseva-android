package com.equipseva.app.designsystem.components

import android.app.Activity
import android.view.View
import android.view.WindowManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import com.equipseva.app.BuildConfig

/**
 * Applies FLAG_SECURE to the hosting window while this composable is in
 * composition. Prevents screenshots + screen recording + Recents thumbnails
 * on screens that display payment info, KYC captures, phone/email, or
 * payout history. No-op in debug builds so QA tooling can capture frames.
 *
 * Round 453 — reference-counted hold so two concurrent secure surfaces
 * (e.g. KYC → AddPhone sheet) don't race on the shared Activity window.
 * Without the counter, the first secure surface to leave composition
 * would clearFlags() and expose the still-mounted second secure surface
 * for one frame — long enough for the Recents thumbnail to capture
 * un-redacted content. Counter is stored on the window's decorView via
 * setTag so it survives across composables sharing the same window
 * without needing a singleton or Hilt-scoped holder.
 */
@Composable
fun SecureScreen() {
    if (BuildConfig.DEBUG) return
    val context = LocalContext.current
    DisposableEffect(context) {
        val window = (context as? Activity)?.window
        val decor: View? = window?.decorView
        if (window != null && decor != null) {
            synchronized(decor) {
                val prev = (decor.getTag(SECURE_FLAG_COUNTER_TAG) as? Int) ?: 0
                if (prev == 0) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                decor.setTag(SECURE_FLAG_COUNTER_TAG, prev + 1)
            }
        }
        onDispose {
            if (window != null && decor != null) {
                synchronized(decor) {
                    val prev = (decor.getTag(SECURE_FLAG_COUNTER_TAG) as? Int) ?: 1
                    val next = (prev - 1).coerceAtLeast(0)
                    decor.setTag(SECURE_FLAG_COUNTER_TAG, next)
                    if (next == 0) {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
            }
        }
    }
}

// Unique tag id for the FLAG_SECURE reference counter attached to the
// Activity window's decorView. Picked from a domain we control
// (R.id namespace would collide if reused elsewhere).
private const val SECURE_FLAG_COUNTER_TAG: Int = 0x73_65_63_75 // "secu"
