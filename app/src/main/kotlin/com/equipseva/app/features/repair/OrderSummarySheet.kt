package com.equipseva.app.features.repair

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.formatRupeesPaise
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

/**
 * v0.3.4 PR C — pre-checkout order summary sheet.
 *
 * Renders AFTER hospital taps "Accept bid" and BEFORE the Razorpay
 * sheet launches. Surfaces:
 *   - engineer name (from the accepted bid)
 *   - 2-line repair scope (issueDescription)
 *   - timeline (bid.etaHours when set)
 *   - bid amount, GST @ 18%, total
 *   - escrow-safety reassurance copy
 *   - "Pay ₹X" CTA → caller proceeds to JobEscrowPaymentSheet
 *
 * Reduces drop-off at the payment stage by giving the hospital a
 * single, calm, transparent breakdown of what they're authorising.
 *
 * Notes:
 *   - r1499 — GST is INCLUSIVE, mirroring the server. The old sheet ADDED
 *     18% on top (bid ₹2,500 → "Total ₹2,950 / Pay ₹2,950") but the actual
 *     charge is escrow.amount_rupees = the bid verbatim (create-repair-job-
 *     payment-order edge fn), and the round449 GST invoice REVERSES the tax
 *     out of that gross (taxable = gross / 1.18). Verified live on
 *     RPR-00040: order summary promised ₹2,950, the pay sheet + Razorpay
 *     order were ₹2,500 — an 18% overstatement at the highest-stakes moment.
 *     The breakdown now shows taxable + GST-included + total-equals-bid,
 *     matching the tax invoice the hospital later downloads.
 */
@Composable
fun OrderSummarySheet(
    job: RepairJob,
    bid: RepairBid,
    engineerName: String,
    onClose: () -> Unit,
    onProceedToPayment: () -> Unit,
) {
    // Round 3760 — repair_job_bids.amount_rupees is nullable at the DB
    // level (round-479 audit migration's own pre-flight guard treats it
    // as such); a legacy/unusual bid row could reach this screen with no
    // amount. Fall back to "—" display rather than silently computing a
    // misleading ₹0 total — server-authoritative escrow.amount_rupees is
    // still the real debit amount either way (see KDoc above).
    val bidAmount = bid.amountRupees
    // r1499 — GST-inclusive breakdown mirroring the server (see KDoc above).
    // orderSummaryBreakdown is pure/non-nullable; the round-3760 nullable
    // bidAmount guard stays in place around it — a legacy bid row with no
    // amount still falls back to "—" rather than computing off a null.
    val breakdown = bidAmount?.let { orderSummaryBreakdown(it) }
    val taxableValueLabel = breakdown?.let { formatRupeesPaise(it.taxableValue) } ?: "—"
    val gstIncludedLabel = breakdown?.let { formatRupeesPaise(it.gstIncluded) } ?: "—"
    val totalAmountLabel = breakdown?.let { formatRupees(it.total) } ?: "—"

    EsBottomSheet(
        onClose = onClose,
        title = "Order summary",
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Engineer row
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Paper2)
                    .padding(12.dp),
            ) {
                Text(stringResource(R.string.order_summary_engineer_label), color = SevaInk500, fontSize = 11.sp)
                Text(
                    engineerName,
                    color = SevaInk900,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            // Repair scope
            Column {
                Text(
                    stringResource(R.string.order_summary_repair_scope_label),
                    color = SevaInk500,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    job.issueDescription,
                    color = SevaInk700,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                )
            }

            // Timeline (hide gracefully when ETA not set on the bid)
            bid.etaHours?.let { eta ->
                Column {
                    Text(
                        stringResource(R.string.order_summary_timeline_label),
                        color = SevaInk500,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        stringResource(R.string.order_summary_eta_arrival, eta),
                        color = SevaInk700,
                        fontSize = 13.sp,
                    )
                }
            }

            // Price breakdown
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Paper2)
                    .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                PriceRow(label = "Taxable value", value = taxableValueLabel)
                PriceRow(label = "GST (18%, included)", value = gstIncludedLabel)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        stringResource(R.string.order_summary_total_label),
                        color = SevaInk900,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        totalAmountLabel,
                        color = SevaInk900,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            // Escrow assurance
            Text(
                stringResource(R.string.order_summary_escrow_note),
                color = SevaInk500,
                fontSize = 12.sp,
                lineHeight = 17.sp,
            )

            Spacer(Modifier.height(4.dp))
            EsBtn(
                text = "Pay $totalAmountLabel",
                kind = EsBtnKind.Primary,
                full = true,
                onClick = onProceedToPayment,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

/**
 * r1499 — GST-inclusive price breakdown for the pre-checkout order summary.
 *
 * Mirrors the server exactly:
 *   - the charge is the bid verbatim (create-repair-job-payment-order uses
 *     escrow.amount_rupees, which accept_repair_bid sets to the bid), so
 *     [total] == bidAmount, always;
 *   - the round449 GST invoice reverses 18% INCLUSIVE tax out of the gross:
 *     taxable = round(gross / 1.18, 2), gst = gross − taxable. The sheet's
 *     rows must foot to the same invoice the hospital later downloads.
 *
 * Pin: total is NEVER bid × 1.18 — the old additive math promised ₹2,950 on
 * a ₹2,500 charge.
 */
internal data class OrderSummaryBreakdown(
    val taxableValue: Double,
    val gstIncluded: Double,
    val total: Double,
)

internal fun orderSummaryBreakdown(bidAmount: Double): OrderSummaryBreakdown {
    val taxable = kotlin.math.round(bidAmount / 1.18 * 100.0) / 100.0
    return OrderSummaryBreakdown(
        taxableValue = taxable,
        gstIncluded = kotlin.math.round((bidAmount - taxable) * 100.0) / 100.0,
        total = bidAmount,
    )
}

@Composable
private fun PriceRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, color = SevaInk600, fontSize = 13.sp)
        Text(
            value,
            color = SevaInk900,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
