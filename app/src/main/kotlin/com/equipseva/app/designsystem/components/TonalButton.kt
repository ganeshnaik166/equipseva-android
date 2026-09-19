package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Pill button with a brand-tonal palette — soft mint background, deep-green label.
 * Mirrors the design's `tonal` variant (`bg: var(--brand-50)`, `c: var(--brand-700)`).
 */
@Composable
fun TonalButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(Spacing.MinTouchTarget),
        shape = RoundedCornerShape(percent = 50),
        colors = ButtonDefaults.buttonColors(
            containerColor = BrandGreen50,
            contentColor = BrandGreenDark,
        ),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp),
    ) {
        Text(label)
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun TonalButtonGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TonalButton(label = "Request quote", onClick = {})
        TonalButton(label = "Request quote", onClick = {}, enabled = false)
        TonalButton(label = "", onClick = {})
        TonalButton(
            label = "Approve ₹4,500 estimate from Rajesh Kumar for Apollo Hospitals Chennai ventilator repair",
            onClick = {},
        )
    }
}

@Preview(name = "TonalButton", showBackground = true)
@Composable
private fun TonalButtonPreview() {
    EquipSevaTheme(darkTheme = false) { TonalButtonGallery() }
}

@Preview(name = "TonalButton large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun TonalButtonPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { TonalButtonGallery() }
}
