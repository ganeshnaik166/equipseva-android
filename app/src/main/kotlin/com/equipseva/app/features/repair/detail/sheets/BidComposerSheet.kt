package com.equipseva.app.features.repair.detail.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.bidComposerAmountValid
import com.equipseva.app.features.repair.bidComposerEtaValid

// Engineer-side bid composer for the repair job detail screen (place / update
// a quote). Split out of the detail screen, which had grown into a 3,551-line
// monolith, so each section and sheet lives in its own file and hierarchy work
// can happen per section without touching the rest of the screen.

// Upper bound on the engineer's bid note. 500 chars keeps the payload
// small and the hospital-side card readable without an "expand" gesture.
private const val NOTE_MAX_LEN = 500

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BidComposerSheet(
    existingBid: RepairBid?,
    placingBid: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (amountRupees: Double, etaHours: Int?, note: String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var amount by rememberSaveable(existingBid?.id) {
        // Pre-fill with Locale.US so the dot-decimal form round-trips
        // through toDoubleOrNull() regardless of device locale. On a
        // device set to a comma-decimal locale (e.g. de_DE), the bare
        // "%.0f".format would render "1.001" for 1000.5 and re-parse
        // as 1001.0, silently corrupting the bid.
        mutableStateOf(existingBid?.amountRupees?.let { String.format(java.util.Locale.US, "%.0f", it) } ?: "")
    }
    var eta by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.etaHours?.toString() ?: "")
    }
    var note by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.note.orEmpty())
    }

    var amountTouched by rememberSaveable { mutableStateOf(false) }
    var etaTouched by rememberSaveable { mutableStateOf(false) }
    // Persist focus across config-change. The two touched flags above
    // already use rememberSaveable; if focus drops to its default after
    // rotation while the touched flag remains true, the error / helper
    // text logic for these fields renders an inconsistent state.
    var amountFocused by rememberSaveable { mutableStateOf(false) }
    var etaFocused by rememberSaveable { mutableStateOf(false) }

    val parsedAmount = amount.toDoubleOrNull()
    val amountValid = bidComposerAmountValid(amount)
    val parsedEta = eta.trim().takeIf { it.isNotEmpty() }?.toIntOrNull()
    val etaValid = bidComposerEtaValid(eta)

    val amountError by remember(amount, amountTouched) {
        derivedStateOf { amountTouched && !amountValid }
    }
    val etaError by remember(eta, etaTouched) {
        derivedStateOf { etaTouched && !etaValid }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = if (existingBid != null) stringResource(R.string.repair_bidcomposer_update_title) else stringResource(R.string.repair_bidcomposer_place_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Price field
            Column {
                Text(
                    text = stringResource(R.string.repair_bidcomposer_price_label),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk700,
                    modifier = Modifier.padding(bottom = 6.dp),
                )
                OutlinedTextField(
                    value = amount,
                    // ASCII-only digits — Char.isDigit() also accepts
                    // Devanagari / Arabic codepoints which break
                    // toDoubleOrNull() downstream and leave amountValid
                    // false with no user-visible hint.
                    onValueChange = { amount = it.filter { ch -> ch in '0'..'9' || ch == '.' } },
                    placeholder = { Text("0") },
                    leadingIcon = { Text("₹", color = SevaInk500, fontSize = 16.sp) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    isError = amountError,
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = SevaGreen700,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .onFocusChanged { focusState ->
                            if (!focusState.isFocused && amountFocused) amountTouched = true
                            amountFocused = focusState.isFocused
                        },
                )
                if (amountError) {
                    Text(
                        text = stringResource(R.string.repair_bidcomposer_amount_error),
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(start = 4.dp, top = 4.dp),
                    )
                }
            }
            // ETA field
            EsField(
                value = eta,
                // ASCII-only digits — same trap as the amount field.
                onChange = { eta = it.filter { ch -> ch in '0'..'9' } },
                // The old "When can you arrive? (hours)" was ambiguous —
                // engineers couldn't tell if it meant clock-hour, travel
                // time, or total job duration. Hospital-side rendering
                // ("ETA Nh") suggests *travel time from now*, so make
                // that explicit in both the label and the hint.
                label = "Travel time to site (hours from now)",
                placeholder = "e.g. 4",
                hint = "How long until you arrive — don't include the repair itself.",
                type = EsFieldType.Number,
                error = if (etaError) "Enter hours as a positive whole number" else null,
                modifier = Modifier.onFocusChanged { focusState ->
                    if (!focusState.isFocused && etaFocused) etaTouched = true
                    etaFocused = focusState.isFocused
                },
            )
            // Note field — cap at 500 chars to keep payload small and
            // the on-screen surface readable. The server side has no
            // hard limit today; without this the user can paste a wall
            // of text and the hospital UI clips it without warning.
            EsField(
                value = note,
                onChange = { note = it.take(NOTE_MAX_LEN) },
                label = "Note to hospital",
                placeholder = "Mention spare parts, prior work…",
                type = EsFieldType.Multiline,
            )
            // Info banner
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(SevaInfo50)
                    .padding(10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(
                    imageVector = Icons.Outlined.Shield,
                    contentDescription = null,
                    tint = SevaInfo500,
                    modifier = Modifier.size(14.dp),
                )
                Text(
                    // "Locked once submitted" wasn't true — the same sheet
                    // re-opens as "Update your bid" when an existingBid is
                    // present, and there's a withdrawBid flow on YourBidCard.
                    // Tell engineers what they can actually do.
                    text = stringResource(R.string.repair_bidcomposer_info_body),
                    fontSize = 11.sp,
                    color = SevaInfo500,
                )
            }
            EsBtn(
                text = if (placingBid) "Submitting…" else "Submit bid",
                onClick = {
                    amountTouched = true
                    etaTouched = true
                    val value = parsedAmount
                    if (value != null && amountValid && etaValid) {
                        onSubmit(value, parsedEta, note.trim().ifBlank { null })
                    }
                },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = !(amountValid && etaValid) || placingBid,
            )
            EsBtn(
                text = stringResource(R.string.common_cancel),
                onClick = onDismiss,
                kind = EsBtnKind.Ghost,
                full = true,
                disabled = placingBid,
            )
        }
    }
}
