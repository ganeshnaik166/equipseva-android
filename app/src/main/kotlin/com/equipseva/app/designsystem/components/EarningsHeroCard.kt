package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Spacing

// Gradient hero card for engineer earnings. Uses PremiumGradientSurfaceDark.
@Composable
fun EarningsHeroCard(
    totalRupees: Double,
    paidRupees: Double,
    pendingRupees: Double,
    onWithdraw: () -> Unit,
    modifier: Modifier = Modifier,
) {
    PremiumGradientSurfaceDark(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
        ) {
            Text(
                text = "This month",
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.70f),
            )
            Spacer(Modifier.height(Spacing.xs))
            Text(
                text = "₹" + formatRupees(totalRupees),
                style = MaterialTheme.typography.displayMedium.copy(
                    fontSize = 28.sp,
                    fontWeight = FontWeight.SemiBold,
                ),
                color = Color.White,
            )
            Spacer(Modifier.height(Spacing.md))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
            ) {
                EarningsSplit(label = "Paid", valueRupees = paidRupees, modifier = Modifier.weight(1f))
                EarningsSplit(label = "Pending", valueRupees = pendingRupees, modifier = Modifier.weight(1f))
            }
            Spacer(Modifier.height(Spacing.md))
            // Withdraw pill — white-on-brand-700, TonalButton-style
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(percent = 50))
                    .background(Color.White)
                    .clickable(onClick = onWithdraw)
                    .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Withdraw",
                    style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = BrandGreenDark,
                )
            }
        }
    }
}

@Composable
private fun EarningsSplit(
    label: String,
    valueRupees: Double,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = Color.White.copy(alpha = 0.70f),
        )
        Text(
            text = "₹" + formatRupees(valueRupees),
            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
            color = Color.White,
        )
    }
}

private fun formatRupees(v: Double): String = String.format("%,.0f", v)
