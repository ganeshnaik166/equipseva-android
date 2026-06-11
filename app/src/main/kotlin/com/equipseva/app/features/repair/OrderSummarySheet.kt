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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.util.formatRupees
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
 *   - GST hardcoded at 18% per MVP scope. When backend introduces
 *     per-state or service-class variation, route the rate through
 *     state and switch the multiplier to a server-derived value.
 *   - The eventual Razorpay sheet uses `escrow.amount_rupees` (server-
 *     authoritative) as the actual debit amount. The total shown here
 *     is client-computed bid + GST; the two should match in normal
 *     flows but the server is the source of truth for the debit.
 */
@Composable
fun OrderSummarySheet(
    job: RepairJob,
    bid: RepairBid,
    engineerName: String,
    onClose: () -> Unit,
    onProceedToPayment: () -> Unit,
) {
    val bidAmount = bid.amountRupees
    val gstAmount = bidAmount * 0.18  // GST @ 18% — see KDoc above
    val totalAmount = bidAmount + gstAmount

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
                Text("Engineer", color = SevaInk500, fontSize = 11.sp)
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
                    "Repair scope",
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
                        "Timeline",
                        color = SevaInk500,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        "Engineer arrives within $eta hours",
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
                PriceRow(label = "Bid amount", value = formatRupees(bidAmount))
                PriceRow(label = "GST (18%)", value = formatRupees(gstAmount))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        "Total",
                        color = SevaInk900,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        formatRupees(totalAmount),
                        color = SevaInk900,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            // Escrow assurance
            Text(
                "Held safe in EquipSeva escrow until you confirm the job is " +
                    "complete. Auto-releases after 48 hours, or refundable if cancelled.",
                color = SevaInk500,
                fontSize = 12.sp,
                lineHeight = 17.sp,
            )

            Spacer(Modifier.height(4.dp))
            EsBtn(
                text = "Pay ${formatRupees(totalAmount)}",
                kind = EsBtnKind.Primary,
                full = true,
                onClick = onProceedToPayment,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
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
