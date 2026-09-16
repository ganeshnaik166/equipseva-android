package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.theme.EquipSevaTheme

// Five visible states across the app — null engineer row, draft (no
// docs), in-review (docs uploaded, awaiting admin), verified, rejected.
// `engineerStatus` null when the user has no engineers row yet.
// `hasDocs` distinguishes Pending without docs (Draft) from Pending
// with docs (In review) — same backend state, different UX label.
@Composable
fun KycChip(
    engineerStatus: VerificationStatus?,
    hasDocs: Boolean,
    modifier: Modifier = Modifier,
) {
    val (text, kind) = when (engineerStatus) {
        null -> "Start" to PillKind.Warn
        VerificationStatus.Pending ->
            if (hasDocs) "In review" to PillKind.Info
            else "Draft" to PillKind.Warn
        VerificationStatus.Verified -> "Verified" to PillKind.Success
        VerificationStatus.Rejected -> "Rejected" to PillKind.Danger
    }
    Pill(text = text, kind = kind, modifier = modifier)
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsKycChipGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        KycChip(engineerStatus = null, hasDocs = false)
        // Pending splits on hasDocs: Draft vs In review.
        KycChip(engineerStatus = VerificationStatus.Pending, hasDocs = false)
        KycChip(engineerStatus = VerificationStatus.Pending, hasDocs = true)
        KycChip(engineerStatus = VerificationStatus.Verified, hasDocs = true)
        KycChip(engineerStatus = VerificationStatus.Rejected, hasDocs = true)
    }
}

@Preview(name = "EsKycChip", showBackground = true)
@Composable
private fun EsKycChipPreview() {
    EquipSevaTheme(darkTheme = false) { EsKycChipGallery() }
}

@Preview(name = "EsKycChip large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsKycChipPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsKycChipGallery() }
}
