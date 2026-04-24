package com.equipseva.app.features.kyc

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

/**
 * A compact 3-step horizontal timeline that visualizes where the engineer's KYC
 * currently sits along the submitted → under review → verified flow. A rejection
 * is rendered as a red-X branch on step 2 (review), since a "rejected" outcome
 * always means the reviewer saw the submission.
 *
 * Mapping to [VerificationStatus]:
 * - [VerificationStatus.Pending] with docs uploaded → step 1 filled (submitted),
 *   step 2 active (under review), step 3 pending.
 * - [VerificationStatus.Pending] without docs → step 1 active (still drafting),
 *   rest pending. Callers pass [submitted] = false for this sub-case.
 * - [VerificationStatus.Verified] → all 3 filled green.
 * - [VerificationStatus.Rejected] → step 1 filled, step 2 red-X, step 3 pending.
 */
@Composable
fun KycStatusTimeline(
    status: VerificationStatus,
    submitted: Boolean,
    modifier: Modifier = Modifier,
) {
    // Per-step render state.
    // step 1 = Submitted, step 2 = Under review, step 3 = Verified.
    val (s1, s2, s3, subtitle) = when (status) {
        VerificationStatus.Verified -> TimelineRender(
            s1 = StepState.Done,
            s2 = StepState.Done,
            s3 = StepState.Done,
            subtitle = "Your verification is complete.",
        )
        VerificationStatus.Rejected -> TimelineRender(
            s1 = StepState.Done,
            s2 = StepState.Rejected,
            s3 = StepState.Pending,
            subtitle = "Your documents were rejected. Re-upload to send it back for review.",
        )
        VerificationStatus.Pending -> if (submitted) {
            TimelineRender(
                s1 = StepState.Done,
                s2 = StepState.Active,
                s3 = StepState.Pending,
                subtitle = "Submitted. A reviewer is checking your documents.",
            )
        } else {
            TimelineRender(
                s1 = StepState.Active,
                s2 = StepState.Pending,
                s3 = StepState.Pending,
                subtitle = "Upload documents and submit to start the review.",
            )
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(Surface0, RoundedCornerShape(14.dp))
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(
            text = "Verification status",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = Ink700,
            letterSpacing = 0.3.sp,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            TimelineStep(
                label = "Submitted",
                state = s1,
                showLeftConnector = false,
                leftConnectorDone = false,
                showRightConnector = true,
                rightConnectorDone = s2 == StepState.Done || s2 == StepState.Rejected,
                modifier = Modifier.weight(1f),
            )
            TimelineStep(
                label = "Under review",
                state = s2,
                showLeftConnector = true,
                leftConnectorDone = s2 == StepState.Done || s2 == StepState.Rejected,
                showRightConnector = true,
                rightConnectorDone = s3 == StepState.Done,
                modifier = Modifier.weight(1f),
            )
            TimelineStep(
                label = "Verified",
                state = s3,
                showLeftConnector = true,
                leftConnectorDone = s3 == StepState.Done,
                showRightConnector = false,
                rightConnectorDone = false,
                modifier = Modifier.weight(1f),
            )
        }

        Text(
            text = subtitle,
            fontSize = 12.sp,
            color = Ink500,
        )
    }
}

private enum class StepState { Pending, Active, Done, Rejected }

private data class TimelineRender(
    val s1: StepState,
    val s2: StepState,
    val s3: StepState,
    val subtitle: String,
)

@Composable
private fun TimelineStep(
    label: String,
    state: StepState,
    showLeftConnector: Boolean,
    leftConnectorDone: Boolean,
    showRightConnector: Boolean,
    rightConnectorDone: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Connector(visible = showLeftConnector, done = leftConnectorDone, modifier = Modifier.weight(1f))
            StepMarker(state = state)
            Connector(visible = showRightConnector, done = rightConnectorDone, modifier = Modifier.weight(1f))
        }
        Text(
            text = label,
            fontSize = 11.sp,
            lineHeight = 14.sp,
            fontWeight = if (state == StepState.Active) FontWeight.SemiBold else FontWeight.Medium,
            color = when (state) {
                StepState.Done, StepState.Active -> Ink900
                StepState.Rejected -> ErrorRed
                StepState.Pending -> Ink500
            },
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 6.dp),
        )
    }
}

@Composable
private fun StepMarker(state: StepState) {
    val fill: Color = when (state) {
        StepState.Done -> BrandGreen
        StepState.Rejected -> ErrorRed
        StepState.Active, StepState.Pending -> Color.White
    }
    val borderColor: Color = when (state) {
        StepState.Done -> BrandGreen
        StepState.Rejected -> ErrorRed
        StepState.Active -> BrandGreen
        StepState.Pending -> Surface200
    }
    Box(
        modifier = Modifier
            .size(24.dp)
            .background(fill, CircleShape)
            .border(2.dp, borderColor, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when (state) {
            StepState.Done -> Icon(
                imageVector = Icons.Outlined.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
            StepState.Rejected -> Icon(
                imageVector = Icons.Outlined.Close,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
            StepState.Active -> Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(BrandGreen, CircleShape),
            )
            StepState.Pending -> Unit
        }
    }
}

@Composable
private fun Connector(visible: Boolean, done: Boolean, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .height(2.dp)
            .background(
                when {
                    !visible -> Color.Transparent
                    done -> BrandGreen
                    else -> Surface200
                },
            ),
    )
}
