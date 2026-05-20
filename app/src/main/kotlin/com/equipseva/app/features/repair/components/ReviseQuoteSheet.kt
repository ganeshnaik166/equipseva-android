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

/**
 * Min/max bounds for the reason field. Mirrors the server-side check in
 * `propose_cost_revision` — keep these in sync if the SQL ever changes.
 */
internal const val REVISE_QUOTE_REASON_MIN = 50
internal const val REVISE_QUOTE_REASON_MAX = 500

/**
 * Pure validity-snapshot of the engineer's revised-quote draft. Computed
 * from raw text inputs + the contracted baseline so the same rules can
 * be pinned in unit tests without standing up a Composable runtime.
 *
 * @property parsedAmount The parsed rupee amount, or null when the
 *   amount field is empty / unparseable. Used by the submit handler.
 * @property reasonTrimmed The trimmed reason (matches what server sees).
 * @property reasonLen Character count of [reasonTrimmed]; surfaced as
 *   the "$reasonLen / max" hint.
 * @property amountValid True when the amount parses and strictly
 *   exceeds the contracted baseline.
 * @property amountTooLow True when the amount parses but is <= baseline.
 *   Lets the UI show the "must exceed contracted" hint only when the
 *   user has typed something parseable (no scolding for an empty field).
 * @property reasonValid True when the trimmed length is in [REVISE_QUOTE_REASON_MIN]..[REVISE_QUOTE_REASON_MAX].
 * @property canSubmit True only when amount + reason are both valid AND
 *   we aren't already mid-flight on a submission.
 */
internal data class ReviseQuoteValidation(
    val parsedAmount: Double?,
    val reasonTrimmed: String,
    val reasonLen: Int,
    val amountValid: Boolean,
    val amountTooLow: Boolean,
    val reasonValid: Boolean,
    val canSubmit: Boolean,
)

/**
 * Build a [ReviseQuoteValidation] from the raw text inputs. Pulled out of
 * the Composable so the boundary rules (parse, > baseline, reason length
 * 50..500, submitting gate) are testable in isolation.
 */
internal fun validateReviseQuote(
    amountText: String,
    reason: String,
    currentContractedRupees: Double,
    submitting: Boolean,
): ReviseQuoteValidation {
    val parsedAmount = amountText.trim().toDoubleOrNull()
    val amountValid = parsedAmount != null && parsedAmount > currentContractedRupees
    val amountTooLow = parsedAmount != null && parsedAmount <= currentContractedRupees
    val reasonTrimmed = reason.trim()
    val reasonLen = reasonTrimmed.length
    val reasonValid = reasonLen in REVISE_QUOTE_REASON_MIN..REVISE_QUOTE_REASON_MAX
    val canSubmit = amountValid && reasonValid && !submitting
    return ReviseQuoteValidation(
        parsedAmount = parsedAmount,
        reasonTrimmed = reasonTrimmed,
        reasonLen = reasonLen,
        amountValid = amountValid,
        amountTooLow = amountTooLow,
        reasonValid = reasonValid,
        canSubmit = canSubmit,
    )
}

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
    val validation = validateReviseQuote(
        amountText = amountText,
        reason = reason,
        currentContractedRupees = currentContractedRupees,
        submitting = submitting,
    )
    val parsedAmount = validation.parsedAmount
    val reasonTrimmed = validation.reasonTrimmed
    val reasonLen = validation.reasonLen
    val reasonValid = validation.reasonValid
    val canSubmit = validation.canSubmit

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
                onChange = { amountText = it.filter { c -> c.isDigit() || c == '.' }.take(10) },
                label = "Revised amount (₹)",
                placeholder = "e.g. 3500",
                type = EsFieldType.Number,
            )
            if (validation.amountTooLow) {
                Text(
                    text = "Revised amount must exceed the current contracted amount.",
                    fontSize = 11.sp,
                    color = SevaInk500,
                )
            }
            EsField(
                value = reason,
                onChange = { reason = it.take(REVISE_QUOTE_REASON_MAX + 5) },
                label = "Reason (50-500 chars)",
                placeholder = "Describe the additional issues you found.",
                type = EsFieldType.Multiline,
            )
            Text(
                text = "$reasonLen / $REVISE_QUOTE_REASON_MAX",
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
