package com.equipseva.app.features.repair.detail.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.features.repair.canSubmitEngineerResponse

// Bottom sheet a hospital uses to open an escrow dispute on a repair job.
// Split out of RepairJobDetailScreen so the detail screen stays a thin
// orchestrator and each sheet can be iterated on in isolation.

@Composable
internal fun EscrowDisputeSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var reason by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onDismiss, title = "Open a dispute") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                stringResource(R.string.repair_dispute_open_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
            OutlinedTextField(
                value = reason,
                onValueChange = { if (it.length <= 500) reason = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.repair_dispute_open_placeholder)) },
                minLines = 3,
                maxLines = 6,
            )
            val canOpen = canSubmitEngineerResponse(reason, submitting)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (canOpen) SevaDanger500 else SevaInk300)
                    .clickable(enabled = canOpen) {
                        onSubmit(reason.trim())
                    }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (submitting) stringResource(R.string.repair_dispute_opening) else stringResource(R.string.repair_dispute_open_action),
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}
