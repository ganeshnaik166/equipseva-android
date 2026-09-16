package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing

@Composable
fun PrimaryButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier
            .fillMaxWidth()
            .height(Spacing.MinTouchTarget)
            .semantics { contentDescription = if (loading) "$label, loading" else label },
        colors = ButtonDefaults.buttonColors(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            if (loading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                )
            }
            Text(label)
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun PrimaryButtonGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        PrimaryButton(label = "Book engineer visit", onClick = {})
        PrimaryButton(label = "Pay ₹4,500 advance", onClick = {}, enabled = false)
        PrimaryButton(label = "Submitting bid", onClick = {}, loading = true)
        PrimaryButton(label = "Submitting bid", onClick = {}, enabled = false, loading = true)
        PrimaryButton(label = "", onClick = {})
        PrimaryButton(
            label = "Assign Ramesh Iyer to ventilator calibration at Apollo Hospitals, Chennai",
            onClick = {},
        )
    }
}

@Preview(name = "PrimaryButton", showBackground = true)
@Composable
private fun PrimaryButtonPreview() {
    EquipSevaTheme(darkTheme = false) { PrimaryButtonGallery() }
}

@Preview(name = "PrimaryButton large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun PrimaryButtonPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { PrimaryButtonGallery() }
}
