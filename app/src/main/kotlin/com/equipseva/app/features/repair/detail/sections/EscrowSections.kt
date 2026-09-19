package com.equipseva.app.features.repair.detail.sections

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.LightEsColors
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.features.repair.WarnGold
import com.equipseva.app.features.repair.engineerPayoutSubtitle
import com.equipseva.app.features.repair.engineerPayoutTitle
import com.equipseva.app.features.repair.escrowStatusCardCopy

// Escrow and payment sections of the repair job detail screen: the
// escrow status/pay/release card, its missing-row placeholder, the
// engineer payout status card, and the GST invoice download. Split
// out of the detail screen (a 3,500-line monolith) so each section's
// hierarchy can be worked on in isolation.

/**
 * Defensive placeholder for a job that's logically past the
 * accept-bid step but has NO escrow row to render. PR #1033 restored
 * the per-job escrow INSERT in accept_repair_bid; this card protects
 * against any future regression OR partial-failure race that leaves
 * the row absent. Without it the hospital sees a job stuck at
 * "Assigned" with no Pay button and no signal what to do.
 */
@Composable
internal fun EscrowMissingPlaceholderCard() {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(SevaWarning50)
            .border(width = 1.dp, color = SevaWarning500, shape = shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            stringResource(R.string.repair_escrow_missing_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            stringResource(R.string.repair_escrow_missing_body),
            fontSize = 12.sp,
            color = SevaInk700,
        )
    }
}

@Composable
internal fun EscrowStatusCard(
    escrow: com.equipseva.app.core.data.escrow.RepairJobEscrowRepository.EscrowRow,
    isHospital: Boolean,
    isJobCompleted: Boolean,
    confirmingRelease: Boolean,
    // Round 437 fix #5 — true when the downstream engineer payout
    // has flipped to Failed / Cancelled despite escrow.isReleased.
    // Used to swap the misleading "Released to engineer" copy for
    // a more accurate "Funds released — payout to engineer pending
    // retry" reading. Defaults false so existing call sites
    // (anywhere we don't yet know payout status) behave as before.
    payoutFailed: Boolean = false,
    onPay: () -> Unit,
    onConfirmRelease: () -> Unit,
    onOpenDispute: () -> Unit,
    onOpenEngineerResponse: () -> Unit,
) {
    val copy = escrowStatusCardCopy(escrow, isHospital, payoutFailed)
    val label = copy.label
    val sub = copy.subtitle
    val accent = when {
        escrow.isPending -> WarnGold
        escrow.isHeld -> SevaGreen700
        escrow.isInDispute -> SevaDanger500
        // (#5) When the downstream payout failed, downgrade the
        // escrow card's green to a warning tone so the visual
        // doesn't contradict the copy.
        escrow.isReleased && payoutFailed -> SevaWarning500
        escrow.isReleased -> SevaGreen700
        escrow.isRefunded -> SevaInk700
        else -> SevaInk500
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(text = label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = accent)
        if (sub.isNotBlank()) {
            Text(text = sub, fontSize = 12.sp, color = SevaInk500)
        }
        // Show the dispute reason text + the engineer's response (when set)
        // on both sides — admins, hospitals, and engineers all benefit from
        // seeing the back-and-forth before the resolution lands.
        if (escrow.isInDispute) {
            if (!escrow.disputeReason.isNullOrBlank()) {
                Text(
                    stringResource(R.string.repair_escrow_dispute_hospital_prefix, escrow.disputeReason),
                    color = SevaInk700,
                    fontSize = 13.sp,
                )
            }
            if (!escrow.engineerResponse.isNullOrBlank()) {
                Text(
                    stringResource(R.string.repair_escrow_dispute_engineer_prefix, escrow.engineerResponse),
                    color = SevaInk700,
                    fontSize = 13.sp,
                )
            } else if (!isHospital) {
                // Engineer hasn't responded yet — surface the CTA. One-shot;
                // server rejects a second submission so the UI hides this
                // once `engineer_response` is set.
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White)
                        .border(1.dp, SevaDanger500, RoundedCornerShape(10.dp))
                        .clickable(onClick = onOpenEngineerResponse)
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        stringResource(R.string.repair_escrow_respond_to_dispute),
                        color = SevaDanger500,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
            }
        }
        if (isHospital && escrow.isPending) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(SevaGreen700)
                    .clickable(onClick = onPay)
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(R.string.repair_escrow_pay_amount, formatRupees(escrow.amountRupees)),
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
        }
        if (isHospital && escrow.isHeld && isJobCompleted) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(10.dp))
                        .background(SevaGreen700)
                        .clickable(enabled = !confirmingRelease, onClick = onConfirmRelease)
                        .padding(vertical = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (confirmingRelease) stringResource(R.string.repair_escrow_releasing) else stringResource(R.string.repair_escrow_confirm_release),
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
                if (escrow.isInDisputeWindow) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White)
                            .border(1.dp, SevaDanger500, RoundedCornerShape(10.dp))
                            .clickable(onClick = onOpenDispute)
                            .padding(vertical = 12.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            stringResource(R.string.repair_dispute_open_action),
                            color = SevaDanger500,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun EngineerPayoutStatusCard(
    p: com.equipseva.app.core.data.payouts.JobPayoutStatus,
    isHospital: Boolean,
    // Round 437 fix #2 — engineer-side recovery CTA when status=Failed.
    // Hospital side passes null because they can't fix the engineer's
    // UPI. Default null so existing callers (none beyond this file)
    // get the no-CTA shape.
    onOpenPayoutMethod: (() -> Unit)? = null,
) {
    val rupees = p.amountPaise / 100.0
    val accent = when (p.status) {
        com.equipseva.app.core.data.payouts.PayoutStatus.Processed -> SevaGreen700
        com.equipseva.app.core.data.payouts.PayoutStatus.Failed -> SevaDanger500
        else -> SevaWarning500
    }
    val bg = when (p.status) {
        com.equipseva.app.core.data.payouts.PayoutStatus.Processed -> SevaGreen50
        else -> SevaWarning50
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .border(width = 1.dp, color = accent, shape = RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Text(
            engineerPayoutTitle(p, isHospital),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            stringResource(R.string.repair_payout_amount, String.format(java.util.Locale.ENGLISH, "%.2f", rupees)),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = SevaInk900,
        )
        val sub = engineerPayoutSubtitle(p, isHospital)
        if (sub != null) {
            Spacer(Modifier.height(4.dp))
            Text(sub, fontSize = 13.sp, color = SevaInk500)
        }
        if (!p.utr.isNullOrBlank() && p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Processed) {
            Spacer(Modifier.height(2.dp))
            Text(
                stringResource(R.string.repair_payout_utr, p.utr),
                fontSize = 12.sp,
                color = SevaGreen700,
                fontWeight = FontWeight.Medium,
            )
        }
        if (!p.failureReason.isNullOrBlank() &&
            (p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed ||
                p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Cancelled)
        ) {
            Spacer(Modifier.height(2.dp))
            Text(
                p.failureReason.orEmpty(),
                fontSize = 12.sp,
                color = if (p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed) SevaDanger500 else SevaInk500,
            )
        }
        // Round 437 fix #2 — engineer self-recovery affordance on
        // Failed payout. Hospital side has onOpenPayoutMethod=null
        // and therefore never sees this button.
        if (onOpenPayoutMethod != null &&
            p.status == com.equipseva.app.core.data.payouts.PayoutStatus.Failed
        ) {
            Spacer(Modifier.height(10.dp))
            EsBtn(
                text = "Update payout method",
                onClick = onOpenPayoutMethod,
                kind = EsBtnKind.Primary,
            )
        }
    }
}

@Composable
internal fun InvoiceDownloadCard(
    loading: Boolean,
    onDownload: () -> Unit,
) {
    androidx.compose.foundation.layout.Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_invoice_download_body),
            style = MaterialTheme.typography.bodySmall,
        )
        EsBtn(
            text = if (loading) "Generating invoice…" else "Download GST invoice",
            onClick = onDownload,
            kind = EsBtnKind.Ghost,
            disabled = loading,
            // This section inherits the fixed PaperDefault page surface.
            contentColor = LightEsColors.text,
        )
    }
}
