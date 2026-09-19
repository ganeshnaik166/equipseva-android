package com.equipseva.app.features.repair.detail.sections

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.theme.SevaInk900

// Full-screen fallback states for the repair-job detail screen: the job
// could not be found, or loading failed. Split out of the detail screen,
// which had grown into a 3,584-line monolith, so each section can be
// worked on in isolation.

@Composable
internal fun NotFoundState(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            stringResource(R.string.repair_notfound_body),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk900,
        )
        EsBtn(text = "Back", onClick = onBack, kind = EsBtnKind.Primary)
    }
}

@Composable
internal fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ErrorBanner(message = message)
        EsBtn(text = stringResource(R.string.common_retry), onClick = onRetry, kind = EsBtnKind.Primary)
    }
}
