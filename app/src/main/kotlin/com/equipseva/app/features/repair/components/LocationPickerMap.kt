package com.equipseva.app.features.repair.components

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.compose.material3.CircularProgressIndicator
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

private fun isSystemLocationEnabled(context: android.content.Context): Boolean {
    val lm = context.getSystemService(android.content.Context.LOCATION_SERVICE) as? android.location.LocationManager
        ?: return false
    return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
        lm.isLocationEnabled
    } else {
        @Suppress("DEPRECATION")
        lm.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) ||
            lm.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)
    }
}

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
    var fetching by remember { mutableStateOf(false) }
    var feedback by remember { mutableStateOf<String?>(null) }

    // rememberUpdatedState keeps the latest callback alive across recompositions
    // — critical because `tryFetch` runs in a coroutine that may complete after
    // the parent re-composed with a fresh `onLocationPicked` lambda. The old
    // `remember { { ... } }` block captured the *first* callback ref forever
    // and silently dropped fixes when the parent re-composed.
    val onLocationPickedRef by rememberUpdatedState(onLocationPicked)
    // userInitiated = true → user tapped the My location button (or granted
    // permission via the system dialog they kicked off): show feedback + open
    // Settings if location toggle is off. userInitiated = false → silent
    // initial auto-fetch on first composition; never popup or open Settings.
    val tryFetch: (userInitiated: Boolean) -> Unit = { userInitiated ->
        if (!fetching) {
            fetching = true
            feedback = null
            scope.launch {
                val fix = fetchCurrentLocation(context)
                fetching = false
                if (fix != null) {
                    onLocationPickedRef(LatLng(fix.latitude, fix.longitude))
                    if (userInitiated) feedback = "Pin set to your location"
                } else if (userInitiated) {
                    // Permission granted but no fix arrived. Distinguish the
                    // most common cause — system location toggle is OFF — so
                    // the user knows to fix it instead of just dragging a pin.
                    val locationOn = isSystemLocationEnabled(context)
                    if (!locationOn) {
                        feedback = "Turn on Location in Quick Settings to use this"
                        try {
                            context.startActivity(
                                android.content.Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                                    .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        } catch (_: Exception) { /* device with no settings app — ignore */ }
                    } else {
                        feedback = "Couldn't get a GPS fix — drag pin to refine"
                    }
                }
                // Hyderabad fallback only seeds the initial pin so the form
                // isn't stuck pin-less. Re-fetches that fail leave the
                // existing pin alone — never clobber a user-set location.
                if (fix == null && selected == null) {
                    onLocationPickedRef(HYDERABAD_FALLBACK)
                }
            }
        }
        Unit
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { granted ->
        val anyGranted = granted[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            granted[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (anyGranted) {
            tryFetch(true)
        } else {
            permissionDenied = true
            // Defensive fallback so the form isn't stuck pin-less when the
            // user denies location entirely.
            onLocationPickedRef(HYDERABAD_FALLBACK)
        }
    }

    LaunchedEffect(Unit) {
        if (selected != null) return@LaunchedEffect
        val granted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            tryFetch(false)
        }
    }

    if (selected == null) {
        Surface(
            modifier = modifier
                .fillMaxWidth()
                .padding(vertical = Spacing.sm),
            shape = RoundedCornerShape(12.dp),
            tonalElevation = 1.dp,
        ) {
            Column(
                modifier = Modifier.padding(Spacing.md),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    "Pin the exact spot",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                Text(
                    text = if (permissionDenied) {
                        "Location permission denied. Drag the pin once it loads, or grant location access in Settings."
                    } else {
                        "Tap below to pin your current location, then drag to refine."
                    },
                    fontSize = 12.sp,
                    color = Ink500,
                )
                TextButton(
                    onClick = {
                        permissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                            ),
                        )
                    },
                ) {
                    Icon(
                        imageVector = Icons.Filled.MyLocation,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                    )
                    Text("  Use my current location", fontSize = 13.sp)
                }
            }
        }
        return
    }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(selected, 16f)
    }
    LaunchedEffect(selected) {
        // Animate so the user sees something happen even if the new fix is
        // close to the old one (common when "My location" returns the same
        // GPS coords as the existing pin).
        cameraPositionState.animate(
            update = com.google.android.gms.maps.CameraUpdateFactory.newCameraPosition(
                CameraPosition.fromLatLngZoom(selected, 16f),
            ),
            durationMs = 400,
        )
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
                .padding(vertical = Spacing.sm),
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
                enabled = !fetching,
                onClick = {
                    val granted = ContextCompat.checkSelfPermission(
                        context, Manifest.permission.ACCESS_FINE_LOCATION,
                    ) == PackageManager.PERMISSION_GRANTED ||
                        ContextCompat.checkSelfPermission(
                            context, Manifest.permission.ACCESS_COARSE_LOCATION,
                        ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        tryFetch(true)
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
                if (fetching) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(12.dp),
                        strokeWidth = 1.5.dp,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Text("  Locating…", fontSize = 11.sp)
                } else {
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
        feedback?.let { msg ->
            Text(
                text = msg,
                fontSize = 11.sp,
                color = Ink500,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg, vertical = 2.dp),
            )
        }
    }
}
