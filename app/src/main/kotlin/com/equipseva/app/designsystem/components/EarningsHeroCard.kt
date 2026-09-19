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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing
import java.util.Locale

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
                text = stringResource(R.string.earnings_hero_this_month),
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
                EarningsSplit(label = stringResource(R.string.earnings_hero_paid_label), valueRupees = paidRupees, modifier = Modifier.weight(1f))
                EarningsSplit(label = stringResource(R.string.earnings_hero_pending_label), valueRupees = pendingRupees, modifier = Modifier.weight(1f))
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
                    text = stringResource(R.string.earnings_hero_withdraw),
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

private fun formatRupees(v: Double): String = String.format(Locale.ENGLISH, "%,.0f", v)

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EarningsHeroCardGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("New engineer — nothing earned yet", style = MaterialTheme.typography.labelSmall)
        EarningsHeroCard(
            totalRupees = 0.0,
            paidRupees = 0.0,
            pendingRupees = 0.0,
            onWithdraw = {},
        )
        Text("Typical month", style = MaterialTheme.typography.labelSmall)
        EarningsHeroCard(
            totalRupees = 48_500.0,
            paidRupees = 32_000.0,
            pendingRupees = 16_500.0,
            onWithdraw = {},
        )
        Text("Everything paid out", style = MaterialTheme.typography.labelSmall)
        EarningsHeroCard(
            totalRupees = 4_500.0,
            paidRupees = 4_500.0,
            pendingRupees = 0.0,
            onWithdraw = {},
        )
        Text("Paise rounds to whole rupees", style = MaterialTheme.typography.labelSmall)
        EarningsHeroCard(
            totalRupees = 7_250.75,
            paidRupees = 3_125.25,
            pendingRupees = 4_125.50,
            onWithdraw = {},
        )
        Text("Seven-figure total — wide numerals", style = MaterialTheme.typography.labelSmall)
        EarningsHeroCard(
            totalRupees = 1_245_000.0,
            paidRupees = 980_000.0,
            pendingRupees = 265_000.0,
            onWithdraw = {},
        )
    }
}

@Preview(name = "EarningsHeroCard", showBackground = true)
@Composable
private fun EarningsHeroCardPreview() {
    EquipSevaTheme(darkTheme = false) { EarningsHeroCardGallery() }
}

@Preview(name = "EarningsHeroCard large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EarningsHeroCardPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EarningsHeroCardGallery() }
}
