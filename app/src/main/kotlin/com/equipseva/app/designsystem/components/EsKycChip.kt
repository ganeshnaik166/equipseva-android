package com.equipseva.app.designsystem.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.core.data.engineers.VerificationStatus

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
