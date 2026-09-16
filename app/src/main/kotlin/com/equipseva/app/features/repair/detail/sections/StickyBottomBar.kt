package com.equipseva.app.features.repair.detail.sections

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.RepairJobDetailViewModel
import com.equipseva.app.features.repair.isViewerAssignedEngineer

// Sticky bottom action bar for the repair job detail screen plus the
// queued-outbox pill that reports offline work waiting to sync. Split out of
// RepairJobDetailScreen (a 3,551-line monolith) so each section of the detail
// screen lives in its own file and hierarchy work can happen per section.

// --- Sticky bottom bar ------------------------------------------------------
@Composable
internal fun StickyBottomBar(
    job: RepairJob,
    ownBid: RepairBid?,
    selfEngineerRowId: String?,
    viewerRole: RepairJobDetailViewModel.ViewerRole,
    updatingStatus: Boolean,
    queuedStatusCount: Int,
    pendingCostRevision: com.equipseva.app.core.data.repair.CostRevision?,
    onPlaceBid: () -> Unit,
    onCheckIn: () -> Unit,
    onMarkDone: () -> Unit,
    onRate: () -> Unit,
    onCancel: () -> Unit,
    onReviseQuote: () -> Unit,
    // v0.3.5 fix #9 — Book-again CTA, hospital-only, surfaces on
    // Completed jobs once the hospital has rated the engineer (so
    // it doesn't compete with the Rate prompt). engineerId is
    // job.engineerId (engineers.id, what the directory uses).
    onBookAgain: (engineerId: String) -> Unit = {},
) {
    val isEngineer = viewerRole == RepairJobDetailViewModel.ViewerRole.Engineer
    val isHospital = viewerRole == RepairJobDetailViewModel.ViewerRole.Hospital
    val rated = when (viewerRole) {
        RepairJobDetailViewModel.ViewerRole.Hospital -> job.hospitalRating != null
        RepairJobDetailViewModel.ViewerRole.Engineer -> job.engineerRating != null
        RepairJobDetailViewModel.ViewerRole.Other -> true
    }
    // Hospital can cancel their own job (Requested or Assigned).
    // Engineer can cancel only if they're the assigned engineer (Assigned status).
    // Random engineer browsing a Requested job: no Cancel — they haven't
    // committed to anything yet; the negative action would be a no-op.
    // round3817 — "assigned" is decided by isViewerAssignedEngineer(): the
    // viewer's own engineers.id matches job.engineerId (covers AMC visit
    // jobs pre-assigned without any bid) OR their bid on this job was
    // accepted. Previously the on-site CTAs below keyed on bare
    // `isEngineer`, so ANY engineer opening an Assigned job saw
    // "Check in on-site" and got a 42501 for their trouble.
    val isAssignedEngineer = isEngineer &&
        isViewerAssignedEngineer(job = job, selfEngineerRowId = selfEngineerRowId, ownBid = ownBid)
    val canCancel = when {
        isHospital -> job.status in setOf(RepairJobStatus.Requested, RepairJobStatus.Assigned)
        isAssignedEngineer -> job.status == RepairJobStatus.Assigned
        else -> false
    }

    // Resolve which primary CTA to show. Null = no primary (e.g. Other role,
    // or terminal states without a CTA + without cancel).
    val primaryKind: PrimaryCta? = when {
        isEngineer && job.status == RepairJobStatus.Requested ->
            PrimaryCta.PlaceBid(editing = ownBid?.status == RepairBidStatus.Pending)
        isAssignedEngineer && job.status == RepairJobStatus.Assigned -> PrimaryCta.CheckIn
        isAssignedEngineer && (job.status == RepairJobStatus.EnRoute || job.status == RepairJobStatus.InProgress) ->
            PrimaryCta.MarkDone
        isHospital && job.status == RepairJobStatus.Completed && !rated -> PrimaryCta.Rate
        isHospital && job.status == RepairJobStatus.Completed && rated -> PrimaryCta.RatedDone
        // Engineer side mirrors hospital: once the job lands in Completed,
        // give the engineer the same Rate / RatedDone CTA against
        // engineer_rating (server enforces side-identity).
        isEngineer && job.status == RepairJobStatus.Completed && !rated -> PrimaryCta.Rate
        isEngineer && job.status == RepairJobStatus.Completed && rated -> PrimaryCta.RatedDone
        else -> null
    }

    // v0.3.5 fix #9 — hospital-side "Book this engineer again" CTA.
    // Surfaces only on Completed jobs where:
    //   * the viewer is the hospital (engineer wouldn't book themselves),
    //   * a specific engineer was assigned (engineerId non-null — repeat
    //     bookings need a target),
    //   * the hospital has already rated the engineer — gating on rated
    //     keeps the bottom bar a single primary CTA (Rate) until that's
    //     done, then swaps the slot to the higher-LTV re-book action.
    val showBookAgain = isHospital &&
        job.status == RepairJobStatus.Completed &&
        rated &&
        job.engineerId != null

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(1.dp, BorderDefault, RectangleShape)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        when (primaryKind) {
            is PrimaryCta.PlaceBid -> EsBtn(
                text = if (primaryKind.editing) "Edit bid" else "Place bid",
                onClick = onPlaceBid,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.CheckIn -> EsBtn(
                text = when {
                    updatingStatus -> "Working…"
                    queuedStatusCount > 0 -> "Queued — back online"
                    else -> "Check in on-site"
                },
                onClick = onCheckIn,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                // Also disable while a status flip is queued offline. The
                // local job.status was optimistically updated when the
                // queue happened, so the gate at transitionStatus would
                // bounce a second tap, but the button itself shouldn't
                // tempt the user. The label change tells them why.
                disabled = updatingStatus || queuedStatusCount > 0,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.MarkDone -> EsBtn(
                text = when {
                    updatingStatus -> "Marking…"
                    queuedStatusCount > 0 -> "Queued — back online"
                    else -> "Mark done"
                },
                onClick = onMarkDone,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                // Mirror CheckIn. Double-tap mid-flight used to fire two
                // 'Completed' RPCs — server-side trigger rejected the
                // second one but the user saw a spurious error toast.
                // Also gate on queuedStatusCount: an offline tap
                // optimistically flips local status, but the row is still
                // pending drain; a second tap before drain would queue
                // another row that the server-side state-machine guard
                // would later reject.
                disabled = updatingStatus || queuedStatusCount > 0,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.Rate -> EsBtn(
                // Hospital rates the engineer; engineer rates the hospital.
                // Same CTA + same flow, different counterpart label so the
                // copy isn't ambiguous on the engineer side.
                text = if (isHospital) "Rate engineer" else "Rate hospital",
                onClick = onRate,
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                modifier = Modifier.weight(1f),
            )
            PrimaryCta.RatedDone -> {
                // v0.3.5 fix #9 — once the hospital has rated the engineer
                // on a completed job, the bottom slot becomes a prominent
                // "Book this engineer again" primary CTA. Repeat bookings
                // are the highest-LTV path on this surface; the old
                // disabled "Rated · Thanks!" pill wasted prime real
                // estate. Engineers still see the disabled pill (no
                // re-book affordance for the engineer side).
                if (showBookAgain) {
                    EsBtn(
                        text = "★ Book this engineer again",
                        onClick = { onBookAgain(job.engineerId!!) },
                        kind = EsBtnKind.Primary,
                        full = true,
                        size = EsBtnSize.Lg,
                        modifier = Modifier.weight(1f),
                    )
                } else {
                    EsBtn(
                        text = "Rated · Thanks!",
                        onClick = {},
                        kind = EsBtnKind.Secondary,
                        full = true,
                        size = EsBtnSize.Lg,
                        disabled = true,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
            null -> Unit
        }
        if (canCancel) {
            EsBtn(
                text = "Cancel",
                onClick = onCancel,
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Lg,
            )
        }
        // v2 — engineer-only "Revise quote" affordance, only while
        // working the job and only when no proposal is already pending.
        if (
            isAssignedEngineer &&
            (job.status == RepairJobStatus.EnRoute || job.status == RepairJobStatus.InProgress) &&
            pendingCostRevision == null
        ) {
            EsBtn(
                text = "Revise quote",
                onClick = onReviseQuote,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Lg,
            )
        }
    }
}

private sealed interface PrimaryCta {
    data class PlaceBid(val editing: Boolean) : PrimaryCta
    data object CheckIn : PrimaryCta
    data object MarkDone : PrimaryCta
    data object Rate : PrimaryCta
    data object RatedDone : PrimaryCta
}

@Composable
internal fun QueuedOutboxPill(bidCount: Int, statusCount: Int) {
    if (bidCount <= 0 && statusCount <= 0) return
    val parts = buildList {
        if (bidCount > 0) add(if (bidCount == 1) "1 bid" else "$bidCount bids")
        if (statusCount > 0) add(if (statusCount == 1) "1 status change" else "$statusCount status changes")
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CheckCircle,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = stringResource(R.string.repair_queued_outbox_body, parts.joinToString(" + ")),
            fontSize = 12.sp,
            color = SevaInk900,
        )
    }
}
