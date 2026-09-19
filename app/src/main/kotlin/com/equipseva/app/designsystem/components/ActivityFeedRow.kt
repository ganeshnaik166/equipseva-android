package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CurrencyRupee
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing

// Single row in the hospital home activity feed — name + action verb + dot + time.
@Composable
fun ActivityFeedRow(
    icon: ImageVector,
    name: String,
    action: String,
    time: String,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(BrandGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(18.dp),
            )
        }
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = name,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = Ink900,
                maxLines = 1,
            )
            Text(
                text = action,
                style = MaterialTheme.typography.bodyMedium,
                color = Ink700,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Text(
                text = "·",
                style = MaterialTheme.typography.bodyMedium,
                color = Ink500,
            )
            Text(
                text = time,
                style = MaterialTheme.typography.bodySmall,
                color = Ink500,
                maxLines = 1,
            )
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun ActivityFeedRowGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ActivityFeedRow(
            icon = Icons.Filled.Build,
            name = "Ravi Kumar",
            action = "accepted your repair request",
            time = "2 min ago",
        )
        ActivityFeedRow(
            icon = Icons.Filled.CheckCircle,
            name = "Dr. Meena Iyer",
            action = "marked ventilator repair complete",
            time = "1 hr ago",
        )
        ActivityFeedRow(
            icon = Icons.Filled.CurrencyRupee,
            name = "Apollo Hospitals",
            action = "paid ₹4,500 for ECG service",
            time = "Yesterday",
        )
        ActivityFeedRow(
            icon = Icons.Outlined.Schedule,
            name = "Suresh Patel",
            action = "scheduled a site visit",
            time = "12 Sep",
        )
        Text(
            text = "Long action (ellipsis)",
            style = MaterialTheme.typography.labelSmall,
            color = Ink500,
        )
        ActivityFeedRow(
            icon = Icons.Filled.Engineering,
            name = "Anil Sharma",
            action = "submitted a bid on the Philips HeartStart defibrillator calibration and preventive maintenance job",
            time = "5 min ago",
        )
        Text(
            text = "Long name",
            style = MaterialTheme.typography.labelSmall,
            color = Ink500,
        )
        ActivityFeedRow(
            icon = Icons.Filled.Build,
            name = "Sri Venkateswara Institute of Medical Sciences",
            action = "posted a job",
            time = "just now",
        )
        Text(
            text = "Empty action",
            style = MaterialTheme.typography.labelSmall,
            color = Ink500,
        )
        ActivityFeedRow(
            icon = Icons.Filled.CheckCircle,
            name = "Kavya Nair",
            action = "",
            time = "3 days ago",
        )
    }
}

@Preview(name = "ActivityFeedRow", showBackground = true)
@Composable
private fun ActivityFeedRowPreview() {
    EquipSevaTheme(darkTheme = false) { ActivityFeedRowGallery() }
}

@Preview(name = "ActivityFeedRow large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun ActivityFeedRowPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { ActivityFeedRowGallery() }
}
