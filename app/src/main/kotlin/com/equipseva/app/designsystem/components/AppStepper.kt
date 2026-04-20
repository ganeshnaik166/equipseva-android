package com.equipseva.app.designsystem.components

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.Ink400
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Surface200

data class StepperStep(
    val title: String,
    val time: String? = null,
)

@Composable
fun VerticalStepper(
    steps: List<StepperStep>,
    current: Int,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        steps.forEachIndexed { index, step ->
            val isDone = index < current
            val isCurrent = index == current
            val markerFill: Color = when {
                isDone -> BrandGreen
                isCurrent -> BrandGreen
                else -> Color.White
            }
            val markerBorder: Color = when {
                isDone || isCurrent -> BrandGreen
                else -> Surface200
            }
            val connectorColor: Color = if (isDone) BrandGreen else Surface200
            val titleColor: Color = if (isDone || isCurrent) Ink900 else Ink500
            val titleWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Medium

            Row(
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.width(24.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .background(markerFill, CircleShape)
                            .border(2.dp, markerBorder, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isDone) {
                            Icon(
                                imageVector = Icons.Outlined.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(12.dp),
                            )
                        } else if (isCurrent) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .background(Color.White, CircleShape),
                            )
                        }
                    }
                    if (index < steps.lastIndex) {
                        Box(
                            modifier = Modifier
                                .width(2.dp)
                                .height(34.dp)
                                .background(connectorColor),
                        )
                    }
                }
                Spacer(Modifier.width(12.dp))
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(bottom = if (index < steps.lastIndex) 16.dp else 0.dp),
                ) {
                    Text(
                        text = step.title,
                        fontSize = 14.sp,
                        lineHeight = 18.sp,
                        fontWeight = titleWeight,
                        color = titleColor,
                    )
                    if (!step.time.isNullOrBlank()) {
                        Text(
                            text = step.time,
                            fontSize = 12.sp,
                            lineHeight = 15.sp,
                            color = Ink500,
                            modifier = Modifier.padding(top = 2.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun HorizontalStepper(
    steps: List<String>,
    current: Int,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        steps.forEachIndexed { index, label ->
            val isDone = index < current
            val isCurrent = index == current
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.weight(1f),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(2.dp)
                            .background(
                                if (isDone || (isCurrent && index > 0)) BrandGreen else Surface200,
                            )
                            .padding(horizontal = 0.dp),
                    )
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .background(
                                when {
                                    isDone -> BrandGreen
                                    isCurrent -> BrandGreen50
                                    else -> Color.White
                                },
                                CircleShape,
                            )
                            .border(
                                2.dp,
                                if (isDone || isCurrent) BrandGreen else Surface200,
                                CircleShape,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isDone) {
                            Icon(
                                imageVector = Icons.Outlined.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(14.dp),
                            )
                        } else {
                            Text(
                                text = (index + 1).toString(),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (isCurrent) BrandGreen else Ink400,
                            )
                        }
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(2.dp)
                            .background(
                                if (isDone) BrandGreen else Surface200,
                            ),
                    )
                }
                Text(
                    text = label,
                    fontSize = 11.sp,
                    lineHeight = 14.sp,
                    fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Medium,
                    color = if (isCurrent || isDone) Ink900 else Ink500,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
        }
    }
}
