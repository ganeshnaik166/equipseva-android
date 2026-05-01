package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import androidx.compose.foundation.shape.RoundedCornerShape

enum class EsFieldType { Text, Password, Number, Email, Phone, Multiline }

// Form input with label above, optional hint or error below, leading /
// trailing slot icons, and integrated keyboard / visual transform per
// EsFieldType. Mirrors the design's `<Field>` primitive in shared.jsx.
@Composable
fun EsField(
    value: String,
    onChange: (String) -> Unit,
    label: String? = null,
    placeholder: String? = null,
    hint: String? = null,
    error: String? = null,
    type: EsFieldType = EsFieldType.Text,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    enabled: Boolean = true,
    // Default Next so chained fields advance focus on Enter; pass Done on
    // the last field of a form to trigger [onImeAction] (or just dismiss
    // the keyboard if no callback is provided).
    imeAction: ImeAction = ImeAction.Next,
    onImeAction: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val keyboardController = LocalSoftwareKeyboardController.current
    val keyboardType = when (type) {
        EsFieldType.Number -> KeyboardType.Number
        EsFieldType.Email -> KeyboardType.Email
        EsFieldType.Phone -> KeyboardType.Phone
        EsFieldType.Password -> KeyboardType.Password
        else -> KeyboardType.Text
    }
    // Belt-and-braces: even though KeyboardType.Password / Email usually
    // suppress IME autocorrect on Android, some OEM keyboards still feed
    // typed characters through the predictive-text dictionary, leaking
    // password fragments to the system suggestions cache. Force them off.
    val noSuggest = type == EsFieldType.Password || type == EsFieldType.Email
    val capitalization = if (noSuggest) {
        androidx.compose.ui.text.input.KeyboardCapitalization.None
    } else {
        androidx.compose.ui.text.input.KeyboardCapitalization.Sentences
    }
    val visualTransformation: VisualTransformation =
        if (type == EsFieldType.Password) PasswordVisualTransformation() else VisualTransformation.None
    Column(modifier = modifier.fillMaxWidth()) {
        if (label != null) {
            Text(
                text = label,
                style = EsType.Label,
                color = SevaInk500,
                modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
            )
        }
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = placeholder?.let { { Text(it, style = EsType.Body, color = SevaInk500) } },
            leadingIcon = leading,
            trailingIcon = trailing,
            isError = error != null,
            singleLine = type != EsFieldType.Multiline,
            minLines = if (type == EsFieldType.Multiline) 3 else 1,
            visualTransformation = visualTransformation,
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                autoCorrect = !noSuggest,
                capitalization = capitalization,
                imeAction = imeAction,
            ),
            keyboardActions = KeyboardActions(
                onDone = {
                    onImeAction?.invoke()
                    keyboardController?.hide()
                },
            ),
            enabled = enabled,
            shape = RoundedCornerShape(EsRadius.Md),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = SevaGreen700,
                errorBorderColor = SevaDanger500,
                focusedTextColor = SevaInk900,
                unfocusedTextColor = SevaInk900,
            ),
            textStyle = EsType.Body,
        )
        val belowText = error ?: hint
        if (belowText != null) {
            Text(
                text = belowText,
                style = EsType.Caption,
                color = if (error != null) SevaDanger500 else SevaInk500,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp),
            )
        }
    }
}
