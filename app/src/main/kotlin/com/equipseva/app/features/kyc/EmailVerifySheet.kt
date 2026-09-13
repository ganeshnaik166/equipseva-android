package com.equipseva.app.features.kyc

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EsActionGroup
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.OtpDigitField
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.EsTheme
import com.equipseva.app.designsystem.theme.EsType

private class EmailSheetLifetime { var active = true }

/** UI ownership is an observed sheet/email context, not repository account ownership. */
@Composable
internal fun EmailVerifySheet(
    email: String,
    code: String,
    sending: Boolean,
    verifying: Boolean,
    onCodeChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit,
    onResend: () -> Unit,
    error: String? = null,
) {
    key(email) {
        EmailVerifyDialog(email, code, sending, verifying, onCodeChange, onSubmit, onDismiss, onResend, error)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EmailVerifyDialog(
    email: String, code: String, sending: Boolean, verifying: Boolean,
    onCodeChange: (String) -> Unit, onSubmit: () -> Unit, onDismiss: () -> Unit,
    onResend: () -> Unit, error: String?,
) {
    val p = EsTheme.colors
    val lifetime = remember { EmailSheetLifetime() }
    DisposableEffect(lifetime) { onDispose { lifetime.active = false } }
    val currentVerifying by rememberUpdatedState(verifying)
    val currentSending by rememberUpdatedState(sending)
    val currentCode by rememberUpdatedState(code)
    val currentChange by rememberUpdatedState(onCodeChange)
    val currentSubmit by rememberUpdatedState(onSubmit)
    val currentDismiss by rememberUpdatedState(onDismiss)
    val currentResend by rememberUpdatedState(onResend)
    // Material3 keys its saved SheetState on this callback. Keep its identity stable
    // so a busy-state change cannot recreate an already visible sheet.
    val confirmTransition = remember {
        { next: SheetValue -> lifetime.active && (next != SheetValue.Hidden || !currentVerifying) }
    }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true,
        confirmValueChange = confirmTransition)
    val dismiss = remember { { if (lifetime.active && !currentVerifying) currentDismiss() } }
    val submit = remember {
        { if (lifetime.active && !currentSending && !currentVerifying && currentCode.length == 6 &&
            currentCode.all { it in '0'..'9' }) currentSubmit() }
    }
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = sheetState,
        properties = ModalBottomSheetProperties(shouldDismissOnBackPress = false),
        containerColor = p.surface, contentColor = p.text, shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)) {
        // Material3 1.3.1's Back path hides without consulting confirmValueChange.
        // Handle Back in this dialog before any hide starts, reading current busy state.
        BackHandler(onBack = dismiss)
        Column(Modifier.fillMaxWidth().imePadding().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.kyc_verify_your_email), style = EsType.H4, color = p.text,
                modifier = Modifier.semantics { heading() })
            Text(stringResource(if (sending) R.string.otp_sending_to else R.string.kyc_email_code_sent, email),
                style = EsType.Body, color = p.muted)
            OtpDigitField(value = code, onValueChange = {
                if (lifetime.active && !currentVerifying) currentChange(it)
            }, enabled = !verifying, error = error,
                hint = if (sending) stringResource(R.string.kyc_email_sending_code) else null,
                onImeAction = submit)
            PrimaryButton(label = stringResource(if (verifying) R.string.kyc_email_verifying else R.string.kyc_verify_action),
                onClick = submit, enabled = !sending && !verifying && code.length == 6 && code.all { it in '0'..'9' },
                loading = verifying)
            EsActionGroup {
                EsBtn(text = stringResource(if (sending) R.string.kyc_email_otp_sending else R.string.kyc_email_resend_code),
                    kind = EsBtnKind.Secondary, disabled = sending || verifying,
                    onClick = { if (lifetime.active && !currentSending && !currentVerifying) currentResend() })
                EsBtn(text = stringResource(R.string.otp_close), kind = EsBtnKind.Ghost,
                    disabled = verifying, onClick = dismiss)
            }
        }
    }
}

