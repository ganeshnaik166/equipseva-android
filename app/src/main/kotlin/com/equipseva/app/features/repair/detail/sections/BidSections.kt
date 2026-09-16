package com.equipseva.app.features.repair.detail.sections

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Icon
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
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.Avatar
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.VerifiedBadge
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.bidCardDistanceLabel
import com.equipseva.app.features.repair.bidCardEtaText
import com.equipseva.app.features.repair.initialsOf
import com.equipseva.app.features.repair.ownBidAmountAndEtaLine

// Bid-related sections of the repair job detail screen: the hospital's bid
// list, the engineer's own bid, and the assigned-engineer card. Split out of
// the 3,551-line detail screen so each section's hierarchy can be worked on
// in isolation without touching the screen shell.

// --- Bids list (hospital view) ---------------------------------------------
@Composable
internal fun BidsList(
    bids: List<RepairBid>,
    engineerNames: Map<String, String>,
    acceptingBidId: String?,
    openingChat: Boolean,
    onAccept: (String) -> Unit,
    onMessage: () -> Unit,
) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        bids.forEach { bid ->
            BidCard(
                bid = bid,
                engineerName = engineerNames[bid.engineerUserId] ?: "Engineer",
                accepting = acceptingBidId == bid.id,
                anyAccepting = acceptingBidId != null,
                openingChat = openingChat,
                onAccept = onAccept,
                onMessage = onMessage,
            )
        }
    }
}

@Composable
internal fun NoBidsYetCard() {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_nobids_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            text = stringResource(R.string.repair_nobids_body),
            fontSize = 12.sp,
            color = SevaInk500,
        )
    }
}

@Composable
internal fun BidCard(
    bid: RepairBid,
    engineerName: String,
    accepting: Boolean,
    anyAccepting: Boolean,
    openingChat: Boolean,
    onAccept: (String) -> Unit,
    onMessage: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Avatar(initials = initialsOf(engineerName), size = 36.dp)
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = engineerName,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaInk900,
                    )
                    VerifiedBadge(small = true)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    // Round 3760 — repair_job_bids.amount_rupees can be
                    // null on a legacy/anomalous row; show "—" rather
                    // than crash or a misleading ₹0.
                    text = bid.amountRupees?.let { formatRupees(it) } ?: "—",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaGreen700,
                )
                bid.createdAtInstant?.let { placed ->
                    Text(
                        text = stringResource(R.string.repair_bidcard_placed_ago, relativeLabel(placed)),
                        fontSize = 10.sp,
                        color = SevaInk400,
                    )
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(BorderDefault),
        )
        Spacer(Modifier.height(8.dp))
        // PR-B: ETA + distance chip line. Distance comes from the new
        // list_repair_job_bids_with_distance RPC; null when the engineer
        // has no base coords or the job has no site coords — chip hides.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = bidCardEtaText(bid.etaHours),
                fontSize = 12.sp,
                color = SevaInk600,
                lineHeight = 17.sp,
            )
            val distanceLabel = bidCardDistanceLabel(bid.distanceKm)
            if (distanceLabel != null) {
                Text(
                    text = distanceLabel,
                    fontSize = 12.sp,
                    color = SevaInk500,
                )
            }
        }
        if (!bid.note.isNullOrBlank()) {
            Text(
                text = bid.note,
                fontSize = 12.sp,
                color = SevaInk600,
                lineHeight = 17.sp,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Row(
            modifier = Modifier
                .padding(top = 10.dp)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            EsBtn(
                text = "Message",
                onClick = onMessage,
                kind = EsBtnKind.Secondary,
                disabled = openingChat,
            )
            EsBtn(
                text = if (accepting) "Accepting…" else "Accept this bid",
                onClick = { if (!anyAccepting) onAccept(bid.id) },
                kind = EsBtnKind.Primary,
                full = true,
                disabled = anyAccepting,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// --- Engineer's own bid card -----------------------------------------------
@Composable
internal fun YourBidCard(ownBid: RepairBid, onWithdraw: () -> Unit) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(14.dp),
    ) {
        Text(
            text = stringResource(R.string.repair_yourbid_label),
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Text(
            text = ownBidAmountAndEtaLine(ownBid.amountRupees, ownBid.etaHours),
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = SevaGreen900,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            text = stringResource(R.string.repair_yourbid_status_prefix, ownBid.status.displayName),
            fontSize = 12.sp,
            color = SevaInk700,
            modifier = Modifier.padding(top = 4.dp),
        )
        if (!ownBid.note.isNullOrBlank()) {
            Text(
                text = ownBid.note,
                fontSize = 12.sp,
                color = SevaInk700,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        if (ownBid.status == RepairBidStatus.Pending) {
            Spacer(Modifier.height(10.dp))
            EsBtn(
                text = "Withdraw bid",
                onClick = onWithdraw,
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Sm,
            )
        }
    }
}

// --- Assigned engineer card ------------------------------------------------
@Composable
internal fun AssignedEngineerCard(
    name: String,
    openingChat: Boolean,
    onMessage: () -> Unit,
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Avatar(initials = initialsOf(name), size = 44.dp)
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = name,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaInk900,
                    )
                    VerifiedBadge(small = true)
                }
            }
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = SevaInk400,
                modifier = Modifier.size(18.dp),
            )
        }
        Row(
            modifier = Modifier
                .padding(top = 8.dp)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            // Dropped the always-disabled "Call" button — its onClick was
            // mis-wired to onMessage anyway, so if it ever flipped enabled
            // it would have opened chat instead of dialing. Masked-call
            // path lives on the engineer-profile MaskedContactPanel; the
            // assigned-engineer card here is just a chat shortcut.
            EsBtn(
                text = if (openingChat) "Opening…" else "Message",
                onClick = onMessage,
                kind = EsBtnKind.Secondary,
                full = true,
                disabled = openingChat,
                leading = {
                    Icon(
                        imageVector = Icons.Outlined.ChatBubbleOutline,
                        contentDescription = null,
                        tint = SevaInk700,
                        modifier = Modifier.size(16.dp),
                    )
                },
                modifier = Modifier.weight(1f),
            )
        }
    }
}
