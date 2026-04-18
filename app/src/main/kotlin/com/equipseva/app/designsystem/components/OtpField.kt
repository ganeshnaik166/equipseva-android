package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp

/**
 * Single-line 6-digit code entry. Stays a single field rather than 6 boxes — easier to paste,
 * easier for autofill, easier for accessibility, and avoids the focus-ping-pong UX bug
 * that plagues homemade OTP grids.
 */
@Composable
fun OtpField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isError: Boolean = false,
    errorText: String? = null,
    onSubmit: (() -> Unit)? = null,
) {
    OutlinedTextField(
        value = value,
        onValueChange = { new ->
            // Restrict to 6 digits, strip everything else.
            onValueChange(new.filter { it.isDigit() }.take(6))
        },
        modifier = modifier.fillMaxWidth(),
        enabled = enabled,
        singleLine = true,
        label = { Text("6-digit code") },
        isError = isError,
        supportingText = errorText?.let { { Text(it) } },
        textStyle = TextStyle(fontSize = 22.sp, textAlign = TextAlign.Center, letterSpacing = 6.sp),
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.NumberPassword,
            imeAction = ImeAction.Done,
        ),
        keyboardActions = KeyboardActions(onDone = { onSubmit?.invoke() }),
    )
}
