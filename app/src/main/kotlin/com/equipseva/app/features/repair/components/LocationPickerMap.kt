package com.equipseva.app.features.repair.components

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
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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

/**
 * Hospital-side location picker. Renders a GoogleMap with a single
 * draggable marker; whenever the user finishes a drag we forward the new
 * `LatLng` via [onLocationPicked]. Re-centers the camera to follow the
 * marker when the parent re-supplies coords (e.g. from "Use my current
 * location"). Map height fixed at 220.dp so it doesn't blow up the
 * scrollable form it lives in.
 *
 * If `selected` is null we show a grey placeholder hint instead of an
 * empty map — keeps the form readable when location permission was
 * denied.
 */
@Composable
fun LocationPickerMap(
    selected: LatLng?,
    onLocationPicked: (LatLng) -> Unit,
    onUseMyLocation: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    if (selected == null) {
        Surface(
            modifier = modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
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
                    "Drop a pin so the engineer can navigate straight to your gate / ward / building. Tap below to start.",
                    fontSize = 12.sp,
                    color = Ink500,
                )
                onUseMyLocation?.let {
                    TextButton(onClick = it) {
                        Icon(
                            imageVector = Icons.Filled.MyLocation,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                        )
                        Text("  Use my current location", fontSize = 13.sp)
                    }
                }
            }
        }
        return
    }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(selected, 16f)
    }
    // Re-center the camera when the parent updates the selected LatLng
    // (e.g. user just tapped "Use my current location" → fused-location
    // returns coords → parent state changes → we follow it here).
    LaunchedEffect(selected) {
        cameraPositionState.position = CameraPosition.fromLatLngZoom(selected, 16f)
    }
    val markerState = remember(selected) { MarkerState(position = selected) }
    LaunchedEffect(markerState.position) {
        // The marker object is the source of truth while the user drags.
        // Fire the callback whenever it lands on a new spot — including
        // the initial position from the parent.
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
            onUseMyLocation?.let {
                TextButton(onClick = it) {
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
}

