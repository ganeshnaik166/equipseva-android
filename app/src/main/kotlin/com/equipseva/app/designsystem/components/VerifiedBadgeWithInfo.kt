package com.equipseva.app.designsystem.components

import com.equipseva.app.R
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.Spacing

import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700

/**
 * Verified-badge cluster: green checkmark + "Verified" label + tappable
 * info icon (?). Tapping the info icon opens an [EsBottomSheet]
 * explaining EquipSeva's KYC criteria. If [verifiedAt] is non-null, the
 * sheet renders a "Verified on <date>" line at the bottom.
 *
 * v0.3.4 needle-mover #3 — round 471. Replaces the old InlineVerifiedBadge
 * on the engineer directory card + public profile hero. The info sheet
 * builds hospital trust by surfacing what "Verified" actually means.
 */
@Composable
fun VerifiedBadgeWithInfo(
    verifiedAt: String?,
    small: Boolean = false,
) {
    var showInfoSheet by remember { mutableStateOf(false) }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            Icons.Filled.Verified,
            // The "Verified" label sits immediately to the right, so naming the
            // glyph too made TalkBack say it twice.
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(if (small) 11.dp else 13.dp),
        )
        Text(
            stringResource(R.string.verified_badge_label),
            color = SevaGreen700,
            fontSize = if (small) 10.sp else 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Icon(
            Icons.Outlined.Info,
            contentDescription = stringResource(R.string.verified_badge_info_title),
            tint = SevaInk500,
            modifier = Modifier
                // A 12-14 dp glyph is the only way into the "how we verify"
                // sheet; reserving the interactive minimum around it makes it
                // reachable without changing the glyph's own size.
                .sizeIn(minWidth = Spacing.MinTouchTarget, minHeight = Spacing.MinTouchTarget)
                .clickable(role = Role.Button) { showInfoSheet = true }
                .size(if (small) 12.dp else 14.dp),
        )
    }

    if (showInfoSheet) {
        VerificationInfoSheet(
            verifiedAt = verifiedAt,
            onClose = { showInfoSheet = false },
        )
    }
}

@Composable
private fun VerificationInfoSheet(
    verifiedAt: String?,
    onClose: () -> Unit,
) {
    EsBottomSheet(
        onClose = onClose,
        title = stringResource(R.string.verified_badge_info_title),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            VerificationCriterion(text = "Government photo ID match")
            VerificationCriterion(text = "Live selfie (liveness check)")
            VerificationCriterion(text = "Phone & email verified")
            VerificationCriterion(text = "KYC reviewed by EquipSeva team within 24h")

            // "Verified on <date>" — only shown when server provides
            // verified_at. Graceful no-op if backend RPC has not yet
            // started populating the column (kotlinx.serialization
            // defaults missing fields to null).
            verifiedAt?.let { dateStr ->
                Spacer(Modifier.height(8.dp))
                Text(
                    text = stringResource(R.string.verified_badge_info_verified_on_date, dateStr),
                    color = SevaInk500,
                    fontSize = 12.sp,
                )
            }
        }
    }
}

@Composable
private fun VerificationCriterion(text: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            "•",
            color = SevaGreen700,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            text = text,
            color = SevaInk700,
            fontSize = 13.sp,
            modifier = Modifier.weight(1f),
        )
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun VerifiedBadgeWithInfoGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Default size (profile hero)", color = SevaInk500, fontSize = 11.sp)
        VerifiedBadgeWithInfo(verifiedAt = "12 Mar 2026")
        VerifiedBadgeWithInfo(verifiedAt = null)

        Text("Small (directory card)", color = SevaInk500, fontSize = 11.sp)
        VerifiedBadgeWithInfo(verifiedAt = "12 Mar 2026", small = true)
        VerifiedBadgeWithInfo(verifiedAt = null, small = true)

        // The info sheet is a ModalBottomSheet and never renders inline, so
        // only its criterion rows can get a screenshot guard here.
        Text("Info sheet criterion rows", color = SevaInk500, fontSize = 11.sp)
        Surface {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                VerificationCriterion(text = "Government photo ID match")
                VerificationCriterion(
                    text = "KYC reviewed by EquipSeva team within 24h, including a callback to the last hospital served (Apollo Hospitals, Hyderabad) to confirm on-site ventilator and dialysis work history",
                )
            }
        }
    }
}

@Preview(name = "VerifiedBadgeWithInfo", showBackground = true)
@Composable
private fun VerifiedBadgeWithInfoPreview() {
    EquipSevaTheme(darkTheme = false) { VerifiedBadgeWithInfoGallery() }
}

@Preview(name = "VerifiedBadgeWithInfo large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun VerifiedBadgeWithInfoPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { VerifiedBadgeWithInfoGallery() }
}
