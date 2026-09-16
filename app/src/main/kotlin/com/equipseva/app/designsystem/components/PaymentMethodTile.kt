package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material.icons.outlined.QrCode2
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

// Selectable payment method row — leading icon + title/subtitle + trailing radio.
@Composable
fun PaymentMethodTile(
    icon: ImageVector,
    title: String,
    selected: Boolean,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
) {
    val source = rememberTapInteractionSource()
    val borderColor = if (selected) BrandGreen else Surface200
    val bg = if (selected) BrandGreen50 else Surface0
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(bg)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = borderColor,
                shape = MaterialTheme.shapes.medium,
            )
            // Round 461: selectable + Role.RadioButton so TalkBack
            // announces "Radio button, selected/not selected" instead
            // of "Button". The visible custom radio dot stays
            // unchanged; only the semantics change.
            .selectable(
                selected = selected,
                onClick = onSelect,
                role = androidx.compose.ui.semantics.Role.RadioButton,
                interactionSource = source,
                indication = null,
            )
            .tapScale(source)
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (selected) BrandGreen else Ink900,
            modifier = Modifier.size(32.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                color = Ink900,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = Ink500,
                )
            }
        }
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape)
                .border(
                    width = 2.dp,
                    color = if (selected) BrandGreen else Surface200,
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(BrandGreen),
                )
            }
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun PaymentMethodTileGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PaymentMethodTile(
            icon = Icons.Outlined.QrCode2,
            title = "UPI",
            selected = true,
            onSelect = {},
        )
        PaymentMethodTile(
            icon = Icons.Outlined.CreditCard,
            title = "Debit / credit card",
            selected = false,
            onSelect = {},
        )
        PaymentMethodTile(
            icon = Icons.Outlined.QrCode2,
            title = "UPI",
            selected = true,
            onSelect = {},
            subtitle = "GPay, PhonePe, Paytm — pay ₹4,500 instantly",
        )
        PaymentMethodTile(
            icon = Icons.Outlined.AccountBalance,
            title = "Bank transfer",
            selected = false,
            onSelect = {},
            subtitle = "NEFT / IMPS to EquipSeva escrow, settles in 2 hours",
        )
        PaymentMethodTile(
            icon = Icons.Outlined.CurrencyRupee,
            title = "Cash on completion — hand ₹4,500 to engineer Rajesh Kumar once the ventilator at Apollo Hospitals Jubilee Hills is signed off",
            selected = true,
            onSelect = {},
            subtitle = "Only for jobs under ₹10,000; the engineer issues an in-app receipt after the hospital biomedical head approves the service report",
        )
        PaymentMethodTile(
            icon = Icons.Outlined.CreditCard,
            title = "",
            selected = false,
            onSelect = {},
            subtitle = "Saved card ending 4821",
        )
    }
}

@Preview(name = "PaymentMethodTile", showBackground = true)
@Composable
private fun PaymentMethodTilePreview() {
    EquipSevaTheme(darkTheme = false) { PaymentMethodTileGallery() }
}

@Preview(name = "PaymentMethodTile large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun PaymentMethodTilePreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { PaymentMethodTileGallery() }
}
