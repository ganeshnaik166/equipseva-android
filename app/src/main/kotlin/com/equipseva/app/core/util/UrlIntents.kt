package com.equipseva.app.core.util

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.core.net.toUri

// equipseva.com is bound to MainActivity via App Links (autoVerify=true).
// Any in-app `Intent.ACTION_VIEW` on that host gets routed back to the
// app instead of a browser, and silently no-ops if NavGraph has no match.
// Force the intent to the default browser package for http(s) so legal
// pages and other web links actually open. Non-http schemes (mailto:,
// tel:, etc.) must NOT be pinned to the browser — the browser can't
// resolve them and the intent silently no-ops.
fun openExternalUrl(ctx: Context, url: String) {
    val uri = url.toUri()
    val isHttp = uri.scheme.equals("http", true) || uri.scheme.equals("https", true)
    val pm = ctx.packageManager
    val browserPkg = if (isHttp) {
        val probe = Intent(Intent.ACTION_VIEW, "https://www.google.com".toUri())
        pm.resolveActivity(probe, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName
            ?.takeIf { it != ctx.packageName }
    } else null

    val view = Intent(Intent.ACTION_VIEW, uri).apply {
        if (browserPkg != null) setPackage(browserPkg)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    try {
        ctx.startActivity(view)
    } catch (_: ActivityNotFoundException) {
        val msg = if (isHttp) "No browser found to open this link"
        else "No app found to handle this action"
        Toast.makeText(ctx, msg, Toast.LENGTH_SHORT).show()
    }
}
