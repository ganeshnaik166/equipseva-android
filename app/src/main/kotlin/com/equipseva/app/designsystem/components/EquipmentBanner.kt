package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing

// Patterned banner shown above repair/order details. Brand gradient + dot pattern bg.
@Composable
fun EquipmentBanner(
    title: String,
    serialOrSubtitle: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(140.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(BrandGreen, BrandGreenDark),
                ),
            )
            .drawBehind {
                val dotColor = Color.White.copy(alpha = 0.10f)
                val spacingPx = 18.dp.toPx()
                val radius = 1.5.dp.toPx()
                var y = spacingPx / 2f
                while (y < size.height) {
                    var x = spacingPx / 2f
                    while (x < size.width) {
                        drawCircle(color = dotColor, radius = radius, center = Offset(x, y))
                        x += spacingPx
                    }
                    y += spacingPx
                }
            }
            .padding(Spacing.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(36.dp),
                )
            }
            Spacer(Modifier.size(Spacing.md))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    color = Color.White,
                    maxLines = 2,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = serialOrSubtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.80f),
                    maxLines = 1,
                )
            }
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EquipmentBannerGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EquipmentBanner(
            title = "Philips IntelliVue MX450",
            serialOrSubtitle = "S/N DE64512877 · Apollo Hospitals, Jubilee Hills",
            icon = Icons.Filled.MonitorHeart,
        )
        EquipmentBanner(
            title = "Ventilator AMC · Order #EQ-2041",
            serialOrSubtitle = "₹4,500 · Engineer: Ramesh Kulkarni",
            icon = Icons.Filled.Build,
        )
        Text(
            text = "Long title clamps at 2 lines, long subtitle at 1",
            style = MaterialTheme.typography.labelSmall,
        )
        EquipmentBanner(
            title = "GE Healthcare Voluson E10 Ultrasound System with BT20 software and 4D convex probe",
            serialOrSubtitle = "S/N 5678901234 · Manipal Hospital, Old Airport Road, Bengaluru, Karnataka 560017",
            icon = Icons.Filled.MedicalServices,
        )
        Text(
            text = "Empty title and subtitle",
            style = MaterialTheme.typography.labelSmall,
        )
        EquipmentBanner(
            title = "",
            serialOrSubtitle = "",
            icon = Icons.Filled.Build,
        )
    }
}

@Preview(name = "EquipmentBanner", showBackground = true)
@Composable
private fun EquipmentBannerPreview() {
    EquipSevaTheme(darkTheme = false) { EquipmentBannerGallery() }
}

@Preview(name = "EquipmentBanner large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EquipmentBannerPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EquipmentBannerGallery() }
}
