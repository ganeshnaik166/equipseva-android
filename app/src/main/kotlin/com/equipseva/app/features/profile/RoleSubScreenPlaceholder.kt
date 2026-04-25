package com.equipseva.app.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

/**
 * Generic "coming soon" shell used by per-role profile sub-screens
 * (Bank details, Addresses, Hospital settings, Storefront, Vehicle
 * details, etc.) until each gets its own purpose-built form. Lets the
 * Profile rows route to a real destination today rather than no-op,
 * and gives the user a preview of the planned fields.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoleSubScreenPlaceholder(
    title: String,
    subtitle: String,
    icon: ImageVector,
    plannedFields: List<String>,
    onBack: () -> Unit,
) {
    Scaffold(topBar = { ESBackTopBar(title = title, onBack = onBack) }) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(Surface50)
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Surface0)
                    .border(1.dp, Surface200, RoundedCornerShape(16.dp))
                    .padding(Spacing.lg),
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(BrandGreen.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(imageVector = icon, contentDescription = null, tint = BrandGreen)
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = title,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Ink900,
                    )
                    Text(text = subtitle, fontSize = 13.sp, color = Ink500)
                }
            }
            Text(
                text = "Coming next pass:",
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = Ink700,
            )
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Surface0)
                    .border(1.dp, Surface200, RoundedCornerShape(16.dp)),
            ) {
                plannedFields.forEachIndexed { index, field ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = Spacing.lg, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(BrandGreen),
                        )
                        Text(
                            text = field,
                            fontSize = 14.sp,
                            color = Ink900,
                            modifier = Modifier.padding(start = Spacing.md),
                        )
                    }
                    if (index < plannedFields.lastIndex) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = Spacing.lg)
                                .size(1.dp)
                                .background(MaterialTheme.colorScheme.surfaceVariant),
                        )
                    }
                }
            }
            Text(
                text = "Tap save once the fields land — until then, profile rows are visible so the navigation experience is complete.",
                fontSize = 12.sp,
                color = Ink500,
            )
        }
    }
}
