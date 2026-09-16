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
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.features.repair.canSubmitEngineerResponse

// Engineer-side dispute response sheet for the repair job detail screen.
// The detail screen was a 3,551-line monolith; each bottom sheet lives in
// its own file so hierarchy and spacing work can happen per sheet without
// touching the screen body.

@Composable
internal fun EngineerResponseSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var response by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onDismiss, title = "Respond to dispute") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                stringResource(R.string.repair_dispute_respond_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
            OutlinedTextField(
                value = response,
                onValueChange = { if (it.length <= 500) response = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.repair_dispute_respond_placeholder)) },
                minLines = 3,
                maxLines = 6,
            )
            val canSubmit = canSubmitEngineerResponse(response, submitting)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (canSubmit) SevaGreen700 else SevaInk300)
                    .clickable(enabled = canSubmit) {
                        onSubmit(response.trim())
                    }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (submitting) stringResource(R.string.repair_dispute_submitting) else stringResource(R.string.repair_dispute_submit_response),
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp,
                )
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}
