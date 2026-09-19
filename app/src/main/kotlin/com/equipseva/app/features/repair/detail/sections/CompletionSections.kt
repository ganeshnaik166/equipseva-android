package com.equipseva.app.features.repair.detail.sections

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

// Post-completion cards of the repair job detail screen: the Digital Service
// Report entry point, the service-report PDF download, and the engineer's
// completion photos. Split out of RepairJobDetailScreen (a 3,551-line monolith)
// so each section's hierarchy can be worked on in isolation.

// round3812 — entry card for the Digital Service Report. Static (no
// per-card fetch: the detail screen is already load-heavy, and the DSR
// screen itself resolves the record's actual state on open).
@Composable
internal fun DsrEntryCard(
    isHospital: Boolean,
    onOpen: () -> Unit,
) {
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
        Text(
            text = stringResource(R.string.dsr_entry_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            text = if (isHospital) {
                stringResource(R.string.dsr_entry_body_hospital)
            } else {
                stringResource(R.string.dsr_entry_body_engineer)
            },
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SevaGreen700)
                .clickable(onClick = onOpen)
                .padding(vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = if (isHospital) {
                    stringResource(R.string.dsr_entry_cta_hospital)
                } else {
                    stringResource(R.string.dsr_entry_cta_engineer)
                },
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
            )
        }
    }
}

@Composable
internal fun ServiceReportCard(
    loading: Boolean,
    onDownload: () -> Unit,
) {
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
        Text(
            text = stringResource(R.string.repair_service_report_title),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        Text(
            text = stringResource(R.string.repair_service_report_body),
            fontSize = 12.sp,
            color = SevaInk500,
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SevaGreen700)
                .clickable(enabled = !loading, onClick = onDownload)
                .padding(vertical = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = if (loading) stringResource(R.string.repair_service_report_generating) else stringResource(R.string.repair_service_report_download),
                color = Color.White,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
            )
        }
    }
}

// --- Completion proof card --------------------------------------------------
@Composable
internal fun CompletionProofCard(urls: List<String>) {
    Column(
        modifier = Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        LazyRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(urls, key = { it }) { url ->
                AsyncImage(
                    model = url,
                    contentDescription = "Completion photo",
                    modifier = Modifier
                        .size(96.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Paper2),
                    contentScale = ContentScale.Crop,
                )
            }
        }
        Text(
            text = stringResource(R.string.repair_completion_proof_body),
            fontSize = 12.sp,
            color = SevaInk500,
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}
