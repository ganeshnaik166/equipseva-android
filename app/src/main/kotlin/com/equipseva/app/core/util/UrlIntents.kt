package com.equipseva.app.core.util

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.net.toUri

// equipseva.com is bound to MainActivity via App Links (autoVerify=true).
// Any in-app `Intent.ACTION_VIEW` on that host gets routed back to the
// app instead of a browser, and silently no-ops if NavGraph has no match.
// Force the intent to the default browser package so legal pages and
// other web links actually open.
fun openExternalUrl(ctx: Context, url: String) {
    val uri = url.toUri()
    val pm = ctx.packageManager
    val probe = Intent(Intent.ACTION_VIEW, "https://www.google.com".toUri())
    val browserPkg = pm.resolveActivity(probe, PackageManager.MATCH_DEFAULT_ONLY)
        ?.activityInfo?.packageName
    val view = Intent(Intent.ACTION_VIEW, uri).apply {
        if (browserPkg != null && browserPkg != ctx.packageName) setPackage(browserPkg)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    runCatching { ctx.startActivity(view) }
}
