package com.equipseva.app.core.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

data class FusedLatLng(val latitude: Double, val longitude: Double)

/**
 * Returns the device's current location via the Fused Location Provider, or
 * null when the caller doesn't have permission, when no fix arrives within
 * the timeout (default 8 seconds), or when both GPS and network are off.
 *
 * Uses BALANCED_POWER_ACCURACY rather than HIGH_ACCURACY so Fused will fall
 * back to network/Wi-Fi positioning when GPS hardware is off — accuracy is
 * 10–100m which is plenty for a service-area pin the user can drag to
 * refine. HIGH_ACCURACY would just return null indoors with GPS off.
 *
 * If `getCurrentLocation` returns null (no recent fix), falls back to
 * `lastLocation` which often has a stale-but-usable fix from another app.
 */
suspend fun fetchCurrentLocation(
    context: Context,
    timeoutMs: Long = 8_000,
): FusedLatLng? {
    val granted = ContextCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_FINE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    if (!granted) return null

    val client = LocationServices.getFusedLocationProviderClient(context)
    val cts = CancellationTokenSource()
    val fresh = withTimeoutOrNull(timeoutMs) {
        suspendCancellableCoroutine { cont ->
            val task = try {
                client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, cts.token)
            } catch (se: SecurityException) {
                cont.resume(null)
                return@suspendCancellableCoroutine
            }
            task.addOnSuccessListener { loc ->
                cont.resume(loc?.let { FusedLatLng(it.latitude, it.longitude) })
            }
            task.addOnFailureListener { cont.resume(null) }
            cont.invokeOnCancellation { cts.cancel() }
        }
    }
    if (fresh != null) return fresh

    // Fallback: stale fix from another app's most recent request. Better than
    // nothing — the engineer drags the pin to the actual spot anyway.
    return runCatching {
        suspendCancellableCoroutine<FusedLatLng?> { cont ->
            val last = try {
                client.lastLocation
            } catch (se: SecurityException) {
                cont.resume(null)
                return@suspendCancellableCoroutine
            }
            last.addOnSuccessListener { loc ->
                cont.resume(loc?.let { FusedLatLng(it.latitude, it.longitude) })
            }
            last.addOnFailureListener { cont.resume(null) }
        }
    }.getOrNull()
}
