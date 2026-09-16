package com.equipseva.app.features.repair.detail.sheets

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.RepairJobDetailViewModel
import com.equipseva.app.features.repair.WarnGold

// Post-completion rating bottom sheet for the repair job detail screen.
// The detail screen grew into a 3,551-line monolith; each section and sheet
// now lives in its own file so hierarchy work can happen per section.

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun RateSheet(
    job: RepairJob,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (Int, String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val existing = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalRating
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerRating
        RepairJobDetailViewModel.ViewerRole.Other -> null
    }
    var rating by rememberSaveable(existing) { mutableIntStateOf(existing ?: 0) }
    var note by rememberSaveable { mutableStateOf("") }
    val labels = listOf("Poor", "Fair", "Good", "Great", "Excellent")
    val sheetTitle = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Engineer -> "Rate hospital"
        else -> "Rate engineer"
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = sheetTitle,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                (1..5).forEach { n ->
                    val filled = n <= rating
                    Box(
                        // Round 448 — onClickLabel + Role.Button so TalkBack
                        // announces "Rate $n stars, button" instead of just
                        // "$n star" + a system "double-tap to activate"
                        // hint. The icon's contentDescription still carries
                        // the filled / outline visual; the click semantics
                        // describe the action.
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .clickable(
                                enabled = existing == null && !submitting,
                                onClickLabel = "Rate $n out of 5 stars",
                                role = androidx.compose.ui.semantics.Role.Button,
                            ) {
                                rating = n
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
                            contentDescription = "$n star",
                            tint = if (filled) WarnGold else SevaInk300,
                            modifier = Modifier.size(36.dp),
                        )
                    }
                }
            }
            Text(
                text = if (rating == 0) stringResource(R.string.repair_rate_tap_to_rate) else labels[rating - 1],
                fontSize = 13.sp,
                color = SevaInk500,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            EsField(
                value = note,
                // 500 char cap mirrors the cancellation-reason field
                // bound (round 234) — keeps a paste-bomb from writing
                // an unbounded essay to job_ratings.notes.
                onChange = { v -> note = if (v.length > 500) v.take(500) else v },
                label = "Notes (optional)",
                placeholder = "What stood out?",
                type = EsFieldType.Multiline,
            )
            EsBtn(
                text = if (submitting) "Submitting…" else "Submit rating",
                onClick = { onSubmit(rating, note.trim().ifBlank { null }) },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = rating == 0 || submitting,
            )
        }
    }
}
