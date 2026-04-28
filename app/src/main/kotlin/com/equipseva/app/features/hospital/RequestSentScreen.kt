package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

// Confirmation landing after a successful repair-job submit. Mirrors the
// design's `screens-hospital.jsx:RequestSent` — green checkmark hero,
// job-number callout, "What happens next" 3-bullet card, View-job +
// Back-home CTAs.
@Composable
fun RequestSentScreen(
    jobNumber: String?,
    onViewJob: () -> Unit,
    onBackHome: () -> Unit,
) {
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 24.dp, vertical = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .clip(CircleShape)
                        .background(SevaGreen50),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.CheckCircle,
                        contentDescription = null,
                        tint = SevaGreen700,
                        modifier = Modifier.size(44.dp),
                    )
                }
                Spacer(Modifier.height(24.dp))
                Text(
                    text = "Request posted",
                    style = EsType.H2,
                    color = SevaInk900,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(8.dp))
                if (!jobNumber.isNullOrBlank()) {
                    Text(
                        text = buildAnnotatedJobLine(jobNumber),
                        style = EsType.BodySm,
                        color = SevaInk700,
                        textAlign = TextAlign.Center,
                    )
                } else {
                    Text(
                        text = "Your repair request is live. Verified engineers in your area can now bid.",
                        style = EsType.BodySm,
                        color = SevaInk700,
                        textAlign = TextAlign.Center,
                    )
                }
                Spacer(Modifier.height(20.dp))
                NextStepsCard()
            }
            Surface(color = androidx.compose.ui.graphics.Color.White) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    EsBtn(
                        text = "View job",
                        onClick = onViewJob,
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                    )
                    EsBtn(
                        text = "Back to home",
                        onClick = onBackHome,
                        kind = EsBtnKind.Ghost,
                        size = EsBtnSize.Lg,
                        full = true,
                    )
                }
            }
        }
    }
}

private fun buildAnnotatedJobLine(jobNumber: String): String =
    "Job $jobNumber is live. Verified engineers in your area can now bid."

@Composable
private fun NextStepsCard() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(androidx.compose.ui.graphics.Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Text(
            text = "WHAT HAPPENS NEXT",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk500,
            letterSpacing = 0.6.sp,
        )
        Spacer(Modifier.height(8.dp))
        NextStepRow(
            icon = Icons.Filled.Notifications,
            text = "You'll get a push when bids arrive (usually 5–30 min)",
        )
        Spacer(Modifier.height(10.dp))
        NextStepRow(
            icon = Icons.Outlined.CheckCircle,
            text = "Pick the bid that fits — engineer is notified",
        )
        Spacer(Modifier.height(10.dp))
        NextStepRow(
            icon = Icons.Filled.Build,
            text = "Track live status, chat, rate after",
        )
    }
}

@Composable
private fun NextStepRow(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier
                .padding(top = 2.dp)
                .size(14.dp),
        )
        Text(
            text = text,
            style = EsType.Caption,
            color = SevaInk700,
        )
    }
}
