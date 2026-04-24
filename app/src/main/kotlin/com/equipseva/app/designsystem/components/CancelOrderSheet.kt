package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import kotlinx.coroutines.launch

/**
 * Bottom sheet that gates the "Cancel order" action. Collects an OPTIONAL free-text reason
 * (capped at 500 chars to match the server-side `spare_part_orders_cancel_reason_len`
 * constraint) and surfaces a primary "Confirm cancellation" button.
 *
 * Mirrors the pattern used by [DeleteAccountSheet]: parent owns the text state so that
 * orientation changes / recompositions don't drop the reason mid-flow.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CancelOrderSheet(
    reason: String,
    cancelling: Boolean,
    onReasonChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = { if (!cancelling) onDismiss() },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = "Cancel this order?",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = "This cannot be undone. Any payment will be refunded per supplier policy. " +
                    "Letting us know why is optional but helps us improve.",
                style = MaterialTheme.typography.bodyMedium,
                color = Ink700,
            )
            OutlinedTextField(
                value = reason,
                onValueChange = { next ->
                    // Hard-cap client-side to mirror the server check (500 chars).
                    onReasonChange(if (next.length <= MAX_REASON_LEN) next else next.take(MAX_REASON_LEN))
                },
                label = { Text("Reason (optional)") },
                supportingText = { Text("${reason.length}/$MAX_REASON_LEN") },
                enabled = !cancelling,
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
                maxLines = 4,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                TextButton(
                    onClick = {
                        scope.launch {
                            sheetState.hide()
                            onDismiss()
                        }
                    },
                    enabled = !cancelling,
                    modifier = Modifier.weight(1f),
                ) { Text("Keep order") }
                PrimaryButton(
                    label = if (cancelling) "Cancelling…" else "Confirm cancellation",
                    onClick = onConfirm,
                    enabled = !cancelling,
                    loading = cancelling,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

private const val MAX_REASON_LEN = 500
