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
import androidx.compose.ui.graphics.Color
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
import com.google.maps.android.compose.rememberMarkerState
import com.google.maps.android.compose.rememberCameraPositionState

/**
 * Engineer-feed map widget. Centres on the engineer's registered base coords
 * and draws a translucent circle showing the active radius filter, plus
 * markers for each nearby job whose hospital coords were resolved by the
 * proximity RPC.
 *
 * Requires `MAPS_API_KEY` to be set; without it the SDK shows blank tiles
 * but the rest of the screen keeps working. When the engineer has no base
 * coords yet, we render a small instructional card instead of an empty map.
 */
@Composable
fun NearbyJobsMap(
    baseLatitude: Double?,
    baseLongitude: Double?,
    radiusKm: Int?,
    jobs: List<MapJob>,
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
                text = "Add your service base location in KYC to see jobs on the map.",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(Spacing.md),
            )
        }
        return
    }

    val centre = LatLng(baseLatitude, baseLongitude)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(centre, zoomFor(radiusKm))
    }
    GoogleMap(
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp)
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(12.dp)),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(isMyLocationEnabled = false),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false,
            scrollGesturesEnabled = true,
            zoomGesturesEnabled = true,
        ),
    ) {
        Marker(
            state = rememberMarkerState(position = centre),
            title = "Your base",
        )
        radiusKm?.let { km ->
            Circle(
                center = centre,
                radius = km.toDouble() * 1000.0, // km → metres
                strokeColor = BrandGreen,
                strokeWidth = 2f,
                fillColor = BrandGreen.copy(alpha = 0.10f),
            )
        }
        jobs.forEach { job ->
            val pos = LatLng(job.latitude, job.longitude)
            Marker(
                state = rememberMarkerState(key = job.id, position = pos),
                title = job.title,
                snippet = "%.1f km away".format(job.distanceKm),
            )
        }
    }
}

/** Subset of [com.equipseva.app.core.data.repair.RepairJob] the map needs. */
data class MapJob(
    val id: String,
    val title: String,
    val latitude: Double,
    val longitude: Double,
    val distanceKm: Double,
)

/**
 * Pick a sensible zoom that fits the radius circle. Numbers are tuned so the
 * circle takes up roughly two-thirds of the viewport height at 200dp.
 */
private fun zoomFor(radiusKm: Int?): Float = when {
    radiusKm == null -> 10f
    radiusKm <= 10 -> 12f
    radiusKm <= 25 -> 11f
    radiusKm <= 50 -> 10f
    else -> 9f
}
