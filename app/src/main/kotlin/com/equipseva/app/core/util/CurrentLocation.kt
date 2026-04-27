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
 * the timeout (default 5 seconds), or when GPS is off. Callers should fall
 * back to a manual map pin when this returns null.
 */
suspend fun fetchCurrentLocation(
    context: Context,
    timeoutMs: Long = 5_000,
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
    return withTimeoutOrNull(timeoutMs) {
        suspendCancellableCoroutine { cont ->
            val task = try {
                client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, cts.token)
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
}
