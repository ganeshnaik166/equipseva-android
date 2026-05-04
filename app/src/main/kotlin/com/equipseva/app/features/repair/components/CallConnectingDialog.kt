package com.equipseva.app.features.repair.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700

/**
 * Modal shown while the request-call-session edge function is dialing
 * Exotel. Once Exotel returns 200, the user's phone rings from the
 * EquipSeva ExoPhone number — this dialog auto-dismisses ~4s after
 * we get a successful response. On error, the host VM shows a
 * snackbar instead.
 */
@Composable
fun CallConnectingDialog(
    message: String,
    onCancel: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onCancel,
        confirmButton = {
            TextButton(onClick = onCancel) { Text("Cancel") }
        },
        title = { Text("Connecting…") },
        text = {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(top = 8.dp),
            ) {
                CircularProgressIndicator()
                Spacer(Modifier.height(4.dp))
                Text(
                    text = message,
                    color = SevaInk700,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = "Your phone will ring shortly. Real numbers stay private — calls route through EquipSeva's secure line.",
                    color = SevaInk500,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                )
            }
        },
    )
}
