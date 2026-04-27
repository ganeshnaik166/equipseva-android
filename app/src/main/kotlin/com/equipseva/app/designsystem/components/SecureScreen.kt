package com.equipseva.app.designsystem.components

import android.app.Activity
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
 */
@Composable
fun SecureScreen() {
    if (BuildConfig.DEBUG) return
    val context = LocalContext.current
    DisposableEffect(context) {
        val window = (context as? Activity)?.window
        window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        onDispose {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
