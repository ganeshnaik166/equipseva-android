package com.equipseva.app.core.util

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.core.net.toUri

// equipseva.com is bound to MainActivity via App Links (autoVerify=true),
// so an in-app `Intent.ACTION_VIEW` on a bound path would be routed back
// into the app instead of a browser. When the device has exactly one
// browser we pin the intent to it; with several installed we hand the URL
// to the system so the user picks (the manifest's App Links paths are
// restricted to routes DeepLinkRouter handles, so legal / help pages are
// not captured by us either way). Non-http schemes (mailto:, tel:, etc.)
// must NOT be pinned to a browser — the browser can't resolve them and
// the intent silently no-ops.
fun openExternalUrl(ctx: Context, url: String) {
    val uri = url.toUri()
    val isHttp = uri.scheme.equals("http", true) || uri.scheme.equals("https", true)
    val pm = ctx.packageManager
    val browserPkg = if (isHttp) {
        val probe = Intent(Intent.ACTION_VIEW, "https://www.google.com".toUri())
        val handlers: List<String> = runCatching {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(probe, PackageManager.MATCH_DEFAULT_ONLY)
                .mapNotNull { it.activityInfo?.packageName }
        }.getOrDefault(emptyList())
        soleBrowserPackage(handlers, ctx.packageName)
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

/**
 * The single browser an http(s) intent may safely be pinned to, or null
 * when the choice belongs to the system.
 *
 * `resolveActivity` answers with the system resolver's own package when
 * several browsers are installed and none is the default; pinning the
 * intent to that package resolves nothing, so the link died with a "No
 * browser found" toast on every multi-browser device. Our own package is
 * dropped too — pinning to ourselves would re-enter the App Links route
 * the caller is trying to leave.
 */
internal fun soleBrowserPackage(handlerPackages: List<String>, selfPackage: String): String? =
    handlerPackages
        .filter { it != selfPackage && it != SYSTEM_RESOLVER_PACKAGE }
        .distinct()
        .singleOrNull()

/** Package reported for `ResolverActivity`, the system's own disambiguation dialog. */
private const val SYSTEM_RESOLVER_PACKAGE = "android"
