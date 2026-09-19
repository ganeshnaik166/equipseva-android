package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import com.equipseva.app.R

import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing

@Composable
fun ErrorBanner(
    message: String?,
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null,
) {
    if (message.isNullOrBlank()) return
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Spacing.sm))
            .background(MaterialTheme.colorScheme.errorContainer)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm)
            .semantics { liveRegion = LiveRegionMode.Polite },
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Outlined.ErrorOutline,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onErrorContainer,
        )
        Text(
            text = message,
            color = MaterialTheme.colorScheme.onErrorContainer,
            style = MaterialTheme.typography.bodyMedium,
            // Server-derived errors can be long; cap to four lines so the
            // banner doesn't dominate the screen on small phones.
            maxLines = 4,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (onDismiss != null) {
            IconButton(onClick = onDismiss) {
                Icon(
                    imageVector = Icons.Outlined.Close,
                    contentDescription = stringResource(R.string.common_dismiss_error),
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
        }
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun ErrorBannerGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ErrorBanner(message = "Couldn't load repair jobs. Check your connection and try again.")
        ErrorBanner(
            message = "Bid of ₹4,500 was not submitted. Please retry.",
            onDismiss = {},
        )
        ErrorBanner(
            message = "Payment to engineer Ramesh Kulkarni for the Philips HeartStart " +
                "defibrillator service at Apollo Hospitals, Hyderabad failed because the " +
                "UPI collect request expired before it was approved. No amount was debited " +
                "from your account. Retry the payment or choose a different method to keep " +
                "the job on schedule.",
            onDismiss = {},
        )
        Text(
            text = "Below: null and blank messages render nothing",
            style = MaterialTheme.typography.labelSmall,
        )
        ErrorBanner(message = null)
        ErrorBanner(message = "   ")
    }
}

@Preview(name = "ErrorBanner", showBackground = true)
@Composable
private fun ErrorBannerPreview() {
    EquipSevaTheme(darkTheme = false) { ErrorBannerGallery() }
}

@Preview(name = "ErrorBanner large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun ErrorBannerPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { ErrorBannerGallery() }
}
