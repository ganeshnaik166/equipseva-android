package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

private val Steps = listOf(
    "Requested" to RepairJobStatus.Requested,
    "Assigned"  to RepairJobStatus.Assigned,
    "En route"  to RepairJobStatus.EnRoute,
    "In progress" to RepairJobStatus.InProgress,
    "Completed" to RepairJobStatus.Completed,
)

private fun stepIndex(s: RepairJobStatus): Int = when (s) {
    RepairJobStatus.Requested -> 0
    RepairJobStatus.Assigned -> 1
    RepairJobStatus.EnRoute -> 2
    RepairJobStatus.InProgress -> 3
    RepairJobStatus.Completed -> 4
    RepairJobStatus.Cancelled -> -1
    RepairJobStatus.Disputed -> -1
    RepairJobStatus.Unknown -> -1
}

// 5-circle linear progress matching `shared.jsx:StatusStepper`.
// Circles: filled green when done/active, outlined ink-300 when pending.
// Connecting lines: green when both ends done, paper-3 when not.
// Labels below each circle, current step highlighted ink-900 + bold.
@Composable
fun EsStatusStepper(
    current: RepairJobStatus,
    modifier: Modifier = Modifier,
) {
    val currentIdx = stepIndex(current)
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Steps.forEachIndexed { index, _ ->
                val state = when {
                    currentIdx < 0 -> StepState.Pending
                    index < currentIdx -> StepState.Done
                    index == currentIdx -> StepState.Active
                    else -> StepState.Pending
                }
                StepCircle(state = state)
                if (index < Steps.lastIndex) {
                    val connectorDone = currentIdx > index
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(2.dp)
                            .background(if (connectorDone) SevaGreen700 else Paper3, RectangleShape),
                    )
                }
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Steps.forEachIndexed { index, (label, _) ->
                val active = index == currentIdx
                Text(
                    text = label,
                    style = EsType.Caption,
                    color = if (active) SevaInk900 else SevaInk500,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

private enum class StepState { Pending, Active, Done }

@Composable
private fun StepCircle(state: StepState) {
    val fill = when (state) {
        StepState.Done -> SevaGreen700
        StepState.Active -> Color.White
        StepState.Pending -> Color.White
    }
    val border = when (state) {
        StepState.Done -> SevaGreen700
        StepState.Active -> SevaGreen700
        StepState.Pending -> Paper3
    }
    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(CircleShape)
            .background(fill)
            .border(2.dp, border, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when (state) {
            StepState.Done -> Icon(
                imageVector = Icons.Outlined.Check,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(12.dp),
            )
            StepState.Active -> Box(
                modifier = Modifier.size(8.dp).clip(CircleShape).background(SevaGreen700),
            )
            StepState.Pending -> Unit
        }
    }
}
