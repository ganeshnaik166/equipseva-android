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
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
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

/**
 * Forces a child to span its parent's content area PLUS the parent's
 * horizontal padding — so the child reaches the actual screen edges even
 * when its parent column applies horizontal padding to all siblings. The
 * child still reports its size as the parent's content width so siblings
 * don't shift around it. Use for full-bleed maps, hero images, and other
 * media that should ignore the form-style horizontal gutter.
 */
fun Modifier.fullBleedHorizontal(parentHorizontalPadding: Dp): Modifier =
    this.layout { measurable, constraints ->
        val pad = parentHorizontalPadding.roundToPx()
        val widened = constraints.copy(
            minWidth = constraints.maxWidth + 2 * pad,
            maxWidth = constraints.maxWidth + 2 * pad,
        )
        val placeable = measurable.measure(widened)
        layout(placeable.width - 2 * pad, placeable.height) {
            placeable.place(-pad, 0)
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

    // rememberUpdatedState keeps the latest callback alive across recompositions
    // — critical because `tryFetch` runs in a coroutine that may complete after
    // the parent re-composed with a fresh `onLocationPicked` lambda. The old
    // `remember { { ... } }` block captured the *first* callback ref forever
    // and silently dropped fixes when the parent re-composed.
    val onLocationPickedRef by rememberUpdatedState(onLocationPicked)
    val tryFetch: () -> Unit = {
        scope.launch {
            val fix = fetchCurrentLocation(context)
            if (fix != null) {
                onLocationPickedRef(LatLng(fix.latitude, fix.longitude))
            } else {
                // Permission granted but GPS off / no network fix / no last
                // location. Drop a Hyderabad fallback so the user still has a
                // draggable marker to start from.
                onLocationPickedRef(HYDERABAD_FALLBACK)
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
            tryFetch()
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
            tryFetch()
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
