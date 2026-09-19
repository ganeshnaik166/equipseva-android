package com.equipseva.app.features.repair.detail.sections

import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.RepairJobDetailViewModel
import com.equipseva.app.features.repair.equipmentScheduleLine
import com.equipseva.app.features.repair.locationCardPlaceholderCopy
import com.equipseva.app.features.repair.textOrDash

// Equipment, issue and location cards for the repair job detail screen.
// The detail screen used to be a single 3,551-line file; each section now
// lives in its own file so hierarchy and polish work can happen per section
// without touching the screen scaffold or the other sections.

// --- Equipment card ---------------------------------------------------------
@Composable
internal fun EquipmentCard(job: RepairJob) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        EqRow("Brand", textOrDash(job.equipmentBrand))
        Spacer(Modifier.height(8.dp))
        EqRow("Model", textOrDash(job.equipmentModel))
        Spacer(Modifier.height(8.dp))
        EqRow("Category", job.equipmentCategory.displayName)
        Spacer(Modifier.height(8.dp))
        EqRow("Schedule", equipmentScheduleLine(job.scheduledDate, job.scheduledTimeSlot))
    }
}

@Composable
internal fun EqRow(label: String, value: String) {
    Row(verticalAlignment = Alignment.Top) {
        Text(
            text = label,
            fontSize = 13.sp,
            color = SevaInk500,
            modifier = Modifier.width(90.dp),
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = value,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
            modifier = Modifier.weight(1f),
        )
    }
}

// --- Issue card -------------------------------------------------------------
@Composable
internal fun IssueCard(job: RepairJob, issuePhotoUrls: List<String>) {
    val urls = issuePhotoUrls.take(4)
    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                .padding(14.dp),
        ) {
            Text(
                text = job.issueDescription,
                fontSize = 13.sp,
                color = SevaInk700,
                lineHeight = 19.sp,
            )
        }
        if (urls.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp)
                    .fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                urls.forEach { url ->
                    coil3.compose.AsyncImage(
                        model = url,
                        contentDescription = null,
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Paper2),
                    )
                }
            }
        }
    }
}

// --- Location card ----------------------------------------------------------
@Composable
internal fun LocationCard(
    job: RepairJob,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
) {
    val context = LocalContext.current
    val isEngineer = viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    val hasAddressOnFile = !job.siteLocation.isNullOrBlank()
    val canShowAddress = hasAddressOnFile &&
        (isHospital || (isEngineer && job.isAssignedToEngineer))
    val placeholderCopy = locationCardPlaceholderCopy(
        canShowAddress = canShowAddress,
        hasAddressOnFile = hasAddressOnFile,
        isEngineer = isEngineer,
    )

    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        // Render a real map when we have coords; fall back to the placeholder
        // tile when the job row never captured a lat/lng (legacy rows from
        // before PR #219 wired the map picker into RequestService Step 4).
        if (job.siteLatitude != null && job.siteLongitude != null) {
            val target = com.google.android.gms.maps.model.LatLng(job.siteLatitude!!, job.siteLongitude!!)
            val cameraState = com.google.maps.android.compose.rememberCameraPositionState {
                position = com.google.android.gms.maps.model.CameraPosition.fromLatLngZoom(target, 15f)
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(12.dp)),
            ) {
                com.google.maps.android.compose.GoogleMap(
                    cameraPositionState = cameraState,
                    properties = com.google.maps.android.compose.MapProperties(isMyLocationEnabled = false),
                    uiSettings = com.google.maps.android.compose.MapUiSettings(
                        zoomControlsEnabled = false,
                        mapToolbarEnabled = false,
                        scrollGesturesEnabled = true,
                        zoomGesturesEnabled = true,
                        tiltGesturesEnabled = false,
                        rotationGesturesEnabled = false,
                    ),
                ) {
                    val markerState = com.google.maps.android.compose.rememberMarkerState(
                        key = "site-${job.siteLatitude}-${job.siteLongitude}",
                        position = target,
                    )
                    com.google.maps.android.compose.Marker(
                        state = markerState,
                        title = "Service site",
                    )
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Paper3),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.LocationOn,
                        contentDescription = null,
                        tint = SevaGreen700,
                        modifier = Modifier.size(28.dp),
                    )
                    Text(
                        text = placeholderCopy,
                        fontSize = 11.sp,
                        color = SevaInk500,
                    )
                    if (canShowAddress) {
                        Text(
                            text = job.siteLocation!!.lineSequence().firstOrNull().orEmpty(),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = SevaInk900,
                        )
                    }
                }
            }
        }
        if (canShowAddress) {
            Text(
                text = job.siteLocation!!,
                fontSize = 13.sp,
                color = SevaInk900,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(top = 8.dp),
            )
            if (isEngineer) {
                Spacer(Modifier.height(8.dp))
                EsBtn(
                    text = "Navigate to site",
                    onClick = {
                        val encoded = Uri.encode(job.siteLocation)
                        val uri = if (job.siteLatitude != null && job.siteLongitude != null) {
                            val label = Uri.encode("Service site")
                            "geo:${job.siteLatitude},${job.siteLongitude}?q=${job.siteLatitude},${job.siteLongitude}($label)".toUri()
                        } else {
                            "geo:0,0?q=$encoded".toUri()
                        }
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uri)
                        try {
                            context.startActivity(intent)
                        } catch (_: android.content.ActivityNotFoundException) {
                            val fallbackUrl = if (job.siteLatitude != null && job.siteLongitude != null) {
                                "https://www.google.com/maps/dir/?api=1&destination=${job.siteLatitude},${job.siteLongitude}"
                            } else {
                                "https://www.google.com/maps/dir/?api=1&destination=$encoded"
                            }
                            val fallback = android.content.Intent(
                                android.content.Intent.ACTION_VIEW,
                                fallbackUrl.toUri(),
                            )
                            try {
                                context.startActivity(fallback)
                            } catch (_: android.content.ActivityNotFoundException) {
                                // No maps app AND no browser — extremely rare,
                                // but silently dropping the tap was confusing.
                                android.widget.Toast.makeText(
                                    context,
                                    "No app available to open this location",
                                    android.widget.Toast.LENGTH_SHORT,
                                ).show()
                            }
                        }
                    },
                    kind = EsBtnKind.Secondary,
                    leading = {
                        Icon(
                            imageVector = Icons.Outlined.LocationOn,
                            contentDescription = null,
                            tint = SevaGreen700,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                )
            }
        } else {
            Text(
                text = if (isEngineer)
                    stringResource(R.string.repair_location_address_hidden_engineer)
                else
                    stringResource(R.string.repair_location_address_hidden_hospital),
                fontSize = 12.sp,
                color = SevaInk500,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}
