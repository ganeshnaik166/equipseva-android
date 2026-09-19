package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.CloudOff
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme

@Composable
fun EmptyStateView(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    ctaLabel: String? = null,
    onCta: (() -> Unit)? = null,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.surfaceVariant,
        ) {
            Box(
                modifier = Modifier.size(72.dp),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(32.dp),
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )
        if (subtitle != null) {
            Spacer(Modifier.height(6.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        if (ctaLabel != null && onCta != null) {
            Spacer(Modifier.height(20.dp))
            Button(onClick = onCta) { Text(ctaLabel) }
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EmptyStateViewGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Title only", style = MaterialTheme.typography.labelSmall)
        EmptyStateView(
            icon = Icons.Outlined.Inbox,
            title = "No repair jobs yet",
        )
        Text("Title + subtitle", style = MaterialTheme.typography.labelSmall)
        EmptyStateView(
            icon = Icons.Outlined.Search,
            title = "No engineers found",
            subtitle = "Try widening the search radius around Apollo Hospitals, Jubilee Hills.",
        )
        Text("Title + CTA, no subtitle", style = MaterialTheme.typography.labelSmall)
        EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No equipment added",
            ctaLabel = "Add equipment",
            onCta = {},
        )
        Text("Title + subtitle + CTA", style = MaterialTheme.typography.labelSmall)
        EmptyStateView(
            icon = Icons.Outlined.CloudOff,
            title = "You're offline",
            subtitle = "Bids from Rajesh Kumar and 3 other engineers will sync once you reconnect.",
            ctaLabel = "Retry",
            onCta = {},
        )
        Text("CTA label without handler (button hidden)", style = MaterialTheme.typography.labelSmall)
        EmptyStateView(
            icon = Icons.Outlined.Inbox,
            title = "No pending payments",
            subtitle = "Your ₹4,500 invoice to KIMS Hospitals has been settled.",
            ctaLabel = "View history",
        )
        Text("Long wrapping text", style = MaterialTheme.typography.labelSmall)
        EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No ventilator, defibrillator or infusion-pump service requests match these filters right now",
            subtitle = "Requests from Manipal Hospitals (Whitefield), Fortis (Bannerghatta Road) and Narayana Health City appear here once a biomedical engineer within 25 km is assigned. Clear the urgency and equipment-type filters to see everything.",
            ctaLabel = "Clear all filters and show every open request",
            onCta = {},
        )
    }
}

@Preview(name = "EmptyStateView", showBackground = true)
@Composable
private fun EmptyStateViewPreview() {
    EquipSevaTheme(darkTheme = false) { EmptyStateViewGallery() }
}

@Preview(name = "EmptyStateView large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EmptyStateViewPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EmptyStateViewGallery() }
}
