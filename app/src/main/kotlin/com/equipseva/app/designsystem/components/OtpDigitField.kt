package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsTheme
import com.equipseva.app.designsystem.theme.EsType

private class OtpInputLifetime { var active = true }

/** One visible native editor. Code remains caller-owned and is never auto-submitted. */
@Composable
fun OtpDigitField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    length: Int = 6,
    error: String? = null,
    enabled: Boolean = true,
    hint: String? = null,
    onImeAction: (() -> Unit)? = null,
    palette: EsColors = EsTheme.colors,
) {
    require(length > 0) { "OTP length must be positive" }
    val lifetime = remember { OtpInputLifetime() }
    DisposableEffect(lifetime) { onDispose { lifetime.active = false } }
    val currentEnabled by rememberUpdatedState(enabled)
    val currentValue by rememberUpdatedState(value)
    val currentLength by rememberUpdatedState(length)
    val currentChange by rememberUpdatedState(onValueChange)
    val currentAction by rememberUpdatedState(onImeAction)
    val keyboard = LocalSoftwareKeyboardController.current
    val displayed = value.take(length)
    val label = stringResource(R.string.otp_code_label, length)
    val progress = stringResource(R.string.otp_code_progress, displayed.length, length)

    Column(modifier.fillMaxWidth()) {
        Text(label, style = EsType.Label,
            color = if (error != null) palette.error.content else if (enabled) palette.muted else palette.disabled.content,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp).semantics { hideFromAccessibility() })
        OutlinedTextField(
            value = displayed,
            onValueChange = { input ->
                if (lifetime.active && currentEnabled) {
                    // Match the existing live KYC ASCII contract; preserve leading zeros.
                    currentChange(input.filter { it in '0'..'9' }.take(currentLength))
                }
            },
            enabled = enabled,
            singleLine = true,
            isError = error != null,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics {
                contentDescription = label
                stateDescription = progress
                if (error != null) error(error)
            },
            textStyle = EsType.Body.copy(fontFeatureSettings = "tnum"),
            shape = RoundedCornerShape(EsRadius.Md),
            colors = esInputColors(palette),
            // Keep the existing visible-code UX. NumberPassword is an IME request,
            // not visual masking or an OEM privacy guarantee.
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword,
                capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false,
                imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = {
                if (lifetime.active && currentEnabled) {
                    val action = currentAction
                    if (action == null) keyboard?.hide()
                    else if (currentValue.length == currentLength && currentValue.all { it in '0'..'9' }) action()
                }
            }),
            supportingText = {
                Text(error ?: hint ?: progress, style = EsType.BodySm,
                    modifier = Modifier.semantics { if (error != null || hint != null) liveRegion = LiveRegionMode.Polite })
            },
        )
    }
}
