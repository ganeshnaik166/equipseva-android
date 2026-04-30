package com.equipseva.app.features.repair.components

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.equipseva.app.core.util.fetchCurrentLocation
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import kotlinx.coroutines.launch

private val HYDERABAD_FALLBACK = LatLng(17.385, 78.4867)

/**
 * Map picker shared by hospital RequestService Step 3 and engineer KYC
 * Step 1. On first composition we attempt to auto-fetch the device's
 * current location via FusedLocation; if permission isn't granted yet, the
 * user can tap "Use my location" to trigger the runtime permission prompt.
 *
 * The marker is draggable so the user can refine the auto-pinned spot.
 * Whenever the marker lands on a new position we forward the new LatLng
 * via [onLocationPicked]. Falls back to a Hyderabad city-centre default
 * if permission is denied or no fix arrives within the helper's timeout.
 */
@Composable
fun LocationPickerMap(
    selected: LatLng?,
    onLocationPicked: (LatLng) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var permissionDenied by remember { mutableStateOf(false) }

    val onLocationPickedRef by rememberUpdatedState(onLocationPicked)
    val tryFetch: () -> Unit = {
        scope.launch {
            val fix = fetchCurrentLocation(context)
            if (fix != null) {
                onLocationPickedRef(LatLng(fix.latitude, fix.longitude))
            } else {
                onLocationPickedRef(HYDERABAD_FALLBACK)
            }
        }
        Unit
    }

    // Resolves the "Turn on location services" system dialog. Fires when the
    // user taps OK on Google's dialog after we detected GPS is off. On RESULT_OK
    // we re-fetch; on cancel we still drop a fallback so the form isn't stuck.
    val locationSettingsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartIntentSenderForResult(),
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            tryFetch()
        } else {
            // User declined the dialog — fall back to Hyderabad pin.
            onLocationPickedRef(HYDERABAD_FALLBACK)
        }
    }

    /**
     * Verifies device location services are ON before attempting a fix.
     * If they're off, fires Google's "Turn on location services" dialog
     * via SettingsClient + IntentSenderForResult. On success, calls
     * [tryFetch]. On no-resolution failure, falls back to a stale fix.
     */
    val ensureLocationOnAndFetch: () -> Unit = {
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY, 0L,
        ).build()
        val settingsRequest = LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest)
            .setAlwaysShow(true)
            .build()
        val client = LocationServices.getSettingsClient(context)
        client.checkLocationSettings(settingsRequest)
            .addOnSuccessListener { tryFetch() }
            .addOnFailureListener { ex ->
                if (ex is ResolvableApiException) {
                    val intentSender = IntentSenderRequest.Builder(ex.resolution).build()
                    locationSettingsLauncher.launch(intentSender)
                } else {
                    // No resolution path — try fetch anyway; falls back to
                    // Hyderabad if it returns null.
                    tryFetch()
                }
            }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { granted ->
        val anyGranted = granted[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            granted[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (anyGranted) {
            ensureLocationOnAndFetch()
        } else {
            permissionDenied = true
            onLocationPickedRef(HYDERABAD_FALLBACK)
        }
    }

    if (selected == null) {
        // Empty placeholder — no auto-fetch on screen open. The caller is
        // expected to render a separate `MyLocationButton` below this map
        // surface so the user explicitly opts in to a location lookup.
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(140.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            contentAlignment = androidx.compose.ui.Alignment.Center,
        ) {
            Text(
                "Tap “Use my current location” below to drop a pin",
                fontSize = 12.sp,
                color = Ink500,
            )
        }
        return
    }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(selected, 16f)
    }
    LaunchedEffect(selected) {
        cameraPositionState.position = CameraPosition.fromLatLngZoom(selected, 16f)
    }
    val markerState = remember(selected) { MarkerState(position = selected) }
    LaunchedEffect(markerState.position) {
        if (markerState.position != selected) {
            onLocationPicked(markerState.position)
        }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        GoogleMap(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
                .clip(RoundedCornerShape(12.dp)),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(isMyLocationEnabled = false),
            uiSettings = MapUiSettings(
                zoomControlsEnabled = false,
                mapToolbarEnabled = false,
                scrollGesturesEnabled = true,
                zoomGesturesEnabled = true,
                tiltGesturesEnabled = false,
                rotationGesturesEnabled = false,
            ),
        ) {
            Marker(
                state = markerState,
                draggable = true,
                title = "Service site",
                snippet = "Drag to pin the exact spot",
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg, vertical = 4.dp),
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(BrandGreen),
            )
            Text(
                text = "  ${"%.5f".format(selected.latitude)}, ${"%.5f".format(selected.longitude)}",
                fontSize = 11.sp,
                color = Ink500,
                fontWeight = FontWeight.SemiBold,
            )
            androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
            TextButton(
                onClick = {
                    val granted = ContextCompat.checkSelfPermission(
                        context, Manifest.permission.ACCESS_FINE_LOCATION,
                    ) == PackageManager.PERMISSION_GRANTED ||
                        ContextCompat.checkSelfPermission(
                            context, Manifest.permission.ACCESS_COARSE_LOCATION,
                        ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        tryFetch()
                    } else {
                        permissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                            ),
                        )
                    }
                },
            ) {
                Icon(
                    imageVector = Icons.Filled.MyLocation,
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
                Text("  My location", fontSize = 11.sp)
            }
        }
    }
}

/**
 * Standalone "Use my current location" trigger. Handles permission grant +
 * the system "Turn on location services" dialog. Place this composable
 * below a [LocationPickerMap] so users explicitly opt in to a location
 * lookup (no auto-prompt on screen open).
 */
@Composable
fun MyLocationButton(
    onLocationPicked: (LatLng) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val onPickedRef by rememberUpdatedState(onLocationPicked)

    val tryFetch: () -> Unit = {
        scope.launch {
            val fix = fetchCurrentLocation(context)
            if (fix != null) {
                onPickedRef(LatLng(fix.latitude, fix.longitude))
            } else {
                onPickedRef(HYDERABAD_FALLBACK)
            }
        }
        Unit
    }

    val settingsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartIntentSenderForResult(),
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            tryFetch()
        } else {
            onPickedRef(HYDERABAD_FALLBACK)
        }
    }

    val ensureOnAndFetch: () -> Unit = {
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY, 0L,
        ).build()
        val settingsRequest = LocationSettingsRequest.Builder()
            .addLocationRequest(locationRequest)
            .setAlwaysShow(true)
            .build()
        LocationServices.getSettingsClient(context)
            .checkLocationSettings(settingsRequest)
            .addOnSuccessListener { tryFetch() }
            .addOnFailureListener { ex ->
                if (ex is ResolvableApiException) {
                    settingsLauncher.launch(
                        IntentSenderRequest.Builder(ex.resolution).build(),
                    )
                } else {
                    tryFetch()
                }
            }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { granted ->
        val ok = granted[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            granted[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (ok) ensureOnAndFetch()
        else onPickedRef(HYDERABAD_FALLBACK)
    }

    com.equipseva.app.designsystem.components.EsBtn(
        text = "Use my current location",
        onClick = {
            val granted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_COARSE_LOCATION,
                ) == PackageManager.PERMISSION_GRANTED
            if (granted) {
                ensureOnAndFetch()
            } else {
                permissionLauncher.launch(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                    ),
                )
            }
        },
        kind = com.equipseva.app.designsystem.components.EsBtnKind.Secondary,
        full = true,
        leading = {
            Icon(
                imageVector = Icons.Filled.MyLocation,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(16.dp),
            )
        },
        modifier = modifier,
    )
}
