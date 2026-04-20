package com.equipseva.app.features.marketplace.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.HealthAndSafety
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Radar
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Surface200

/** Category → (icon, hue) mapping for gradient tiles. */
internal fun categoryIcon(category: PartCategory): ImageVector = when (category) {
    PartCategory.Cardiology -> Icons.Filled.MonitorHeart
    PartCategory.ImagingRadiology -> Icons.Filled.Radar
    PartCategory.LifeSupport -> Icons.Filled.Favorite
    PartCategory.PatientMonitoring -> Icons.Filled.MonitorHeart
    PartCategory.Sterilization -> Icons.Filled.HealthAndSafety
    PartCategory.Other -> Icons.Filled.MedicalServices
}

internal fun categoryHue(category: PartCategory): Int = when (category) {
    PartCategory.Cardiology -> 0
    PartCategory.ImagingRadiology -> 200
    PartCategory.LifeSupport -> 150
    PartCategory.PatientMonitoring -> 40
    PartCategory.Sterilization -> 280
    PartCategory.Other -> 330
}

internal fun stockStatus(part: SparePart): Triple<StatusTone, ImageVector?, String> = when {
    !part.inStock -> Triple(StatusTone.Danger, null, "Out of stock")
    part.stockQuantity < 10 -> Triple(StatusTone.Warn, null, "Low stock")
    else -> Triple(StatusTone.Success, null, "In stock")
}

@Composable
fun PartCard(
    part: SparePart,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(5.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val primary = part.primaryImageUrl?.takeIf { it.isNotBlank() }
            if (primary != null) {
                AsyncImage(
                    model = primary,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(72.dp)
                        .clip(RoundedCornerShape(5.dp)),
                )
            } else {
                GradientTile(
                    icon = categoryIcon(part.category),
                    hue = categoryHue(part.category),
                    size = 72.dp,
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                val brand = part.compatibleBrands.firstOrNull().orEmpty()
                if (brand.isNotBlank()) {
                    Text(
                        text = brand,
                        fontSize = 11.sp,
                        lineHeight = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Ink500,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Text(
                    text = part.name,
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.padding(top = 4.dp),
                ) {
                    Text(
                        text = formatRupees(part.priceRupees),
                        fontSize = 15.sp,
                        lineHeight = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = BrandGreenDark,
                    )
                    val mrp = part.mrpRupees
                    if (mrp != null && mrp > part.priceRupees) {
                        Text(
                            text = formatRupees(mrp),
                            fontSize = 11.sp,
                            lineHeight = 14.sp,
                            color = Ink500,
                            textDecoration = TextDecoration.LineThrough,
                        )
                    }
                    if (part.discountPercent > 0) {
                        StatusChip(
                            label = "${part.discountPercent}% OFF",
                            tone = StatusTone.Success,
                        )
                    }
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 4.dp),
                ) {
                    val (tone, icon, label) = stockStatus(part)
                    StatusChip(label = label, tone = tone, icon = icon)
                }
            }
        }
    }
}

