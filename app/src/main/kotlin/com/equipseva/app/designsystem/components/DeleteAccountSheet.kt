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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
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
    password: String,
    passwordError: String?,
    deleting: Boolean,
    onReasonChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
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
            // Re-auth gate. Without proof of the current password an
            // attacker with momentary access to an unlocked device could
            // hard-delete the legitimate owner's account (RPC runs purely
            // on auth.uid; no other gate at the server). Surface
            // passwordError on wrong-password attempts so the user sees
            // "incorrect password" instead of a generic toast.
            OutlinedTextField(
                value = password,
                onValueChange = onPasswordChange,
                label = { Text("Confirm with your password") },
                isError = passwordError != null,
                supportingText = passwordError?.let { { Text(it) } },
                visualTransformation = PasswordVisualTransformation(),
                // KeyboardType.Password disables predictive text on the
                // soft keyboard. Without this, Android adds the typed
                // password to the per-user dictionary and a subsequent
                // typo elsewhere can suggest the real password as a
                // completion — a documented PII-leak class.
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                enabled = !deleting,
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
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
                    // Require a non-blank password before the Confirm
                    // is tappable. The VM still validates server-side
                    // so an empty value can't slip through stale state.
                    disabled = !canConfirmDeleteAccount(password, deleting),
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/**
 * Confirm-button gate on the delete-account sheet.
 *
 * Enabled when password is non-blank AND not currently deleting.
 *
 * Critical pin: requires non-blank password (re-auth gate). Without
 * proof of the current password an attacker with momentary access
 * to an unlocked device could hard-delete the legitimate owner's
 * account — the RPC runs purely on auth.uid with no other server-
 * side gate. A refactor that dropped the password check would
 * surface as a security regression.
 */
internal fun canConfirmDeleteAccount(password: String, deleting: Boolean): Boolean =
    password.isNotBlank() && !deleting
