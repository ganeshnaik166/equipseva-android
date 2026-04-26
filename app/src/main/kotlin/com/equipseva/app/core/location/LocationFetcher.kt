package com.equipseva.app.core.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Wraps FusedLocationProviderClient + the on-device Geocoder so the
 * AddressForm can offer a "Use my current location" button. Falls back
 * gracefully on devices without Play Services or with Geocoder disabled.
 */
@Singleton
class LocationFetcher @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    data class Coords(val lat: Double, val lng: Double)

    data class Resolved(
        val coords: Coords,
        val line1: String? = null,
        val line2: String? = null,
        val landmark: String? = null,
        val city: String? = null,
        val state: String? = null,
        val pincode: String? = null,
    )

    fun hasPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED ||
            coarse == PackageManager.PERMISSION_GRANTED
    }

    /** Pulls the current device position; null if Play Services / GPS unavailable. */
    suspend fun currentCoords(): Coords? {
        if (!hasPermission()) return null
        val client = LocationServices.getFusedLocationProviderClient(context)
        return suspendCancellableCoroutine { cont ->
            try {
                client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, null)
                    .addOnSuccessListener { loc ->
                        if (loc != null) cont.resume(Coords(loc.latitude, loc.longitude))
                        else cont.resume(null)
                    }
                    .addOnFailureListener { _ -> cont.resume(null) }
            } catch (se: SecurityException) {
                cont.resumeWithException(se)
            }
        }
    }

    /**
     * Reverse-geocodes [coords] using Android's on-device Geocoder. Returns
     * null on devices where Geocoder isn't present or the call fails — the
     * AddressForm then leaves manual fields untouched and the user types in.
     */
    suspend fun reverseGeocode(coords: Coords): Resolved? {
        if (!Geocoder.isPresent()) return null
        val geocoder = Geocoder(context)
        val addr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            suspendCoroutine<List<android.location.Address>?> { cont ->
                try {
                    geocoder.getFromLocation(coords.lat, coords.lng, 1) { results ->
                        cont.resume(results)
                    }
                } catch (t: Throwable) {
                    cont.resumeWithException(t)
                }
            }?.firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            try {
                geocoder.getFromLocation(coords.lat, coords.lng, 1)?.firstOrNull()
            } catch (_: Throwable) {
                null
            }
        } ?: return Resolved(coords = coords)

        val line1 = listOfNotNull(addr.subThoroughfare, addr.thoroughfare).joinToString(" ").ifBlank { null }
            ?: addr.featureName
        val line2 = listOfNotNull(addr.subLocality, addr.locality)
            .filter { it != line1 }
            .joinToString(", ").ifBlank { null }
        val landmark = addr.premises ?: addr.subAdminArea
        val city = addr.locality ?: addr.subAdminArea
        val state = addr.adminArea
        val pincode = addr.postalCode

        return Resolved(
            coords = coords,
            line1 = line1,
            line2 = line2,
            landmark = landmark,
            city = city,
            state = state,
            pincode = pincode,
        )
    }
}
