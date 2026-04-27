package com.equipseva.app.features.repair.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Spacing
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.Circle
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState

/**
 * Read-only map that previews where a verified engineer operates: pin at their
 * base coords + a translucent circle covering their service radius. Hospital
 * uses this on the public profile to judge whether the engineer covers them.
 *
 * Falls back to a small instructional surface when the engineer hasn't pinned
 * a base yet (legacy rows from before KYC asked for coords).
 */
@Composable
fun ServiceAreaMap(
    baseLatitude: Double?,
    baseLongitude: Double?,
    serviceRadiusKm: Int?,
    engineerName: String?,
    modifier: Modifier = Modifier,
) {
    if (baseLatitude == null || baseLongitude == null) {
        Surface(
            modifier = modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
            shape = RoundedCornerShape(12.dp),
            tonalElevation = 1.dp,
        ) {
            Text(
                text = "No service-area pin yet — ask the engineer to add their base location.",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(Spacing.md),
            )
        }
        return
    }

    val centre = LatLng(baseLatitude, baseLongitude)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(centre, zoomFor(serviceRadiusKm))
    }
    GoogleMap(
        modifier = modifier
            .fillMaxWidth()
            .height(180.dp)
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(12.dp)),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(isMyLocationEnabled = false),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false,
            scrollGesturesEnabled = true,
            zoomGesturesEnabled = true,
            // Tilt + rotate are noise on a small preview — disable.
            tiltGesturesEnabled = false,
            rotationGesturesEnabled = false,
        ),
    ) {
        Marker(
            state = MarkerState(position = centre),
            title = engineerName ?: "Engineer",
        )
        serviceRadiusKm?.let { km ->
            Circle(
                center = centre,
                radius = km.toDouble() * 1000.0,
                strokeColor = BrandGreen,
                strokeWidth = 2f,
                fillColor = BrandGreen.copy(alpha = 0.10f),
            )
        }
    }
}

private fun zoomFor(radiusKm: Int?): Float = when {
    radiusKm == null -> 10f
    radiusKm <= 10 -> 12f
    radiusKm <= 25 -> 11f
    radiusKm <= 50 -> 10f
    else -> 9f
}
