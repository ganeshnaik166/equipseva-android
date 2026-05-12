package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeleteAccountSheet(
    reason: String,
    deleting: Boolean,
    onReasonChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = { if (!deleting) onDismiss() },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = "Delete your account?",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                // Copy reviewed 2026-05-12: the RPC hard-deletes
                // auth.users + storage objects on the same call; there is
                // no 30-day grace period and support cannot restore the
                // account once this runs. List the real scope so the user
                // sees what's about to disappear.
                text = "Deletes your profile, repair jobs, bids, AMC contracts, " +
                    "messages, payments, saved addresses, and uploaded files. All " +
                    "device sessions are signed out immediately. This is permanent — " +
                    "support cannot restore the account after this runs.",
                style = MaterialTheme.typography.bodyMedium,
                color = Ink700,
            )
            OutlinedTextField(
                value = reason,
                onValueChange = onReasonChange,
                label = { Text("Reason (optional)") },
                supportingText = { Text("${reason.length}/500") },
                enabled = !deleting,
                modifier = Modifier.fillMaxWidth(),
                minLines = 2,
                maxLines = 4,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                TextButton(
                    onClick = {
                        scope.launch {
                            sheetState.hide()
                            onDismiss()
                        }
                    },
                    enabled = !deleting,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                // Destructive action — must read as red, not brand-primary
                // green. PrimaryButton previously made the confirm look
                // identical to a "Save" CTA on every other sheet.
                EsBtn(
                    text = if (deleting) "Deleting…" else "Delete account",
                    onClick = onConfirm,
                    kind = EsBtnKind.Danger,
                    size = EsBtnSize.Md,
                    full = true,
                    disabled = deleting,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}
