package com.equipseva.app.features.repair.detail.sheets

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

// Hospital-side "cancel this job" bottom sheet for the repair job detail
// screen. Sheets live in their own files so each can be reworked on its own
// instead of inside one multi-thousand-line screen file.

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CancelSheet(
    updating: Boolean,
    jobStatus: RepairJobStatus?,
    escrowHeldRupees: Int?,
    onDismiss: () -> Unit,
    onConfirm: (String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    // Reason is now plumbed through cancelJob → updateStatus → the new
    // repair_jobs.cancellation_reason column (PR #614 migration). Empty
    // reason is allowed for `requested` (no engineer to inform), but
    // required once an engineer has been assigned / is en route / has
    // started — they deserve to know why the job vanished.
    var reason by androidx.compose.runtime.saveable.rememberSaveable { androidx.compose.runtime.mutableStateOf("") }
    val isAssignedOrLater = jobStatus in setOf(
        RepairJobStatus.Assigned,
        RepairJobStatus.EnRoute,
        RepairJobStatus.InProgress,
    )
    val reasonRequired = isAssignedOrLater
    val reasonOk = !reasonRequired || reason.trim().length >= 10
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.repair_cancel_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Status-aware warning. After accept_repair_bid the engineer
            // may already be traveling — be honest about that. If money
            // is in escrow, surface the refund expectation in the same
            // breath so the hospital doesn't have to chase support.
            Text(
                text = when {
                    isAssignedOrLater ->
                        stringResource(R.string.repair_cancel_body_assigned)
                    else ->
                        stringResource(R.string.repair_cancel_body_default)
                },
                fontSize = 13.sp,
                color = SevaInk600,
            )
            if (escrowHeldRupees != null) {
                Text(
                    text = stringResource(R.string.repair_cancel_escrow_refund, escrowHeldRupees),
                    fontSize = 12.sp,
                    color = SevaInk700,
                )
            }
            androidx.compose.material3.OutlinedTextField(
                value = reason,
                onValueChange = { reason = it.take(500) },
                label = {
                    Text(if (reasonRequired) stringResource(R.string.repair_cancel_reason_required_label) else stringResource(R.string.delete_account_sheet_reason_label))
                },
                placeholder = { Text(stringResource(R.string.repair_cancel_reason_placeholder)) },
                isError = reasonRequired && reason.isNotEmpty() && !reasonOk,
                minLines = 2,
                maxLines = 5,
                enabled = !updating,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                EsBtn(
                    text = "Keep job",
                    onClick = onDismiss,
                    kind = EsBtnKind.Secondary,
                    full = true,
                    disabled = updating,
                    modifier = Modifier.weight(1f),
                )
                EsBtn(
                    text = if (updating) "Cancelling…" else "Cancel job",
                    onClick = { onConfirm(reason.trim().ifBlank { null }) },
                    kind = EsBtnKind.Danger,
                    full = true,
                    disabled = updating || !reasonOk,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}
