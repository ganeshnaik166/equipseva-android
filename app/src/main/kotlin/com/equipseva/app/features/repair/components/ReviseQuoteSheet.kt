package com.equipseva.app.features.repair.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

private const val REASON_MIN = 50
private const val REASON_MAX = 500

/**
 * Engineer-side bottom sheet to propose a revised quote when more
 * issues are discovered on-site than the original bid covered.
 * Server-side `propose_cost_revision` enforces:
 *   - caller is the assigned engineer
 *   - job status in (en_route, in_progress)
 *   - revised > current contracted
 *   - reason length 50-500 chars
 *   - max 3 proposals per job
 * The sheet pre-validates locally so the user gets fast feedback,
 * but the server is the source of truth.
 */
@Composable
fun ReviseQuoteSheet(
    currentContractedRupees: Double,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (revisedRupees: Double, reason: String) -> Unit,
) {
    var amountText by rememberSaveable { mutableStateOf("") }
    var reason by rememberSaveable { mutableStateOf("") }
    val parsedAmount = amountText.trim().toDoubleOrNull()
    val amountValid = parsedAmount != null && parsedAmount > currentContractedRupees
    val reasonTrimmed = reason.trim()
    val reasonLen = reasonTrimmed.length
    val reasonValid = reasonLen in REASON_MIN..REASON_MAX
    val canSubmit = amountValid && reasonValid && !submitting

    EsBottomSheet(onClose = onDismiss, title = "Revise quote") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "Current contracted amount",
                fontSize = 12.sp,
                color = SevaInk500,
            )
            Text(
                text = formatRupees(currentContractedRupees),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            EsField(
                value = amountText,
                onChange = { amountText = it.filter { c -> c in '0'..'9' || c == '.' }.take(10) },
                label = "Revised amount (₹)",
                placeholder = "e.g. 3500",
                type = EsFieldType.Number,
            )
            if (parsedAmount != null && parsedAmount <= currentContractedRupees) {
                Text(
                    text = "Revised amount must exceed the current contracted amount.",
                    fontSize = 11.sp,
                    color = SevaInk500,
                )
            }
            EsField(
                value = reason,
                onChange = { reason = it.take(REASON_MAX + 5) },
                label = "Reason (50-500 chars)",
                placeholder = "Describe the additional issues you found.",
                type = EsFieldType.Multiline,
            )
            Text(
                text = "$reasonLen / $REASON_MAX",
                fontSize = 11.sp,
                color = if (reasonValid || reasonLen == 0) SevaInk500 else SevaInk700,
            )
            EsBtn(
                text = if (submitting) "Submitting…" else "Send to hospital",
                onClick = {
                    val a = parsedAmount ?: return@EsBtn
                    onSubmit(a, reasonTrimmed)
                },
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = !canSubmit,
            )
        }
    }
}
