package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.repair.CostRevision
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

/**
 * Hospital-side decision sheet for a pending [CostRevision]. Shows the
 * delta + reason + Approve / Reject. On approve, server overwrites
 * `repair_jobs.contracted_amount_rupees`; on reject, the engineer can
 * propose another revision (capped at 3 per job server-side).
 */
@Composable
fun CostRevisionDecisionSheet(
    revision: CostRevision,
    deciding: Boolean,
    onDismiss: () -> Unit,
    onDecide: (approve: Boolean) -> Unit,
) {
    EsBottomSheet(onClose = onDismiss, title = "Revised quote") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Delta block
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.White)
                    .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                    .padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AmountRow(label = "Original", amount = revision.originalAmountRupees, accent = false)
                AmountRow(label = "Revised", amount = revision.revisedAmountRupees, accent = true)
            }
            Text(
                text = "Engineer's note",
                fontSize = 12.sp,
                color = SevaInk500,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = revision.reason,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                color = SevaInk700,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                EsBtn(
                    text = if (deciding) "…" else "Reject",
                    onClick = { onDecide(false) },
                    kind = EsBtnKind.Secondary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = deciding,
                    modifier = Modifier.weight(1f),
                )
                EsBtn(
                    text = if (deciding) "Approving…" else "Approve",
                    onClick = { onDecide(true) },
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = deciding,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun AmountRow(label: String, amount: Double, accent: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Text(
            text = formatRupees(amount),
            fontSize = if (accent) 18.sp else 14.sp,
            fontWeight = if (accent) FontWeight.Bold else FontWeight.SemiBold,
            color = SevaInk900,
        )
    }
}
