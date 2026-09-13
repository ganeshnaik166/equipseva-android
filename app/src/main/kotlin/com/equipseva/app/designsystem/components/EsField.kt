package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.hideFromAccessibility
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.EsTheme
import androidx.compose.foundation.shape.RoundedCornerShape

enum class EsFieldType { Text, Password, Number, Email, Phone, Multiline }

// Persistent labels grow above the outline; the editable node owns the accessible name.
// The outer modifier remains on the group for existing picker/focus callers.
@Composable
fun EsField(
    value: String,
    onChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    hint: String? = null,
    error: String? = null,
    type: EsFieldType = EsFieldType.Text,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    enabled: Boolean = true,
    // Default Next so chained fields advance focus on Enter; pass Done on
    // the last field of a form to just dismiss the keyboard.
    imeAction: ImeAction = ImeAction.Next,
    // Round 462 — fired when the keyboard's submit-equivalent key (Done /
    // Send / Go / Search) is tapped, so screens can submit the form on
    // Enter instead of forcing a button tap. When null the keyboard
    // simply dismisses on Done (original behavior).
    onImeAction: (() -> Unit)? = null,
    palette: EsColors = EsTheme.colors,
) {
    val keyboardController = LocalSoftwareKeyboardController.current
    val currentEnabled by rememberUpdatedState(enabled)
    val currentAction by rememberUpdatedState(onImeAction)
    val finishInput: () -> Unit = {
        if (currentEnabled) {
            currentAction?.invoke()
            keyboardController?.hide()
        }
    }
    val keyboardType = when (type) {
        EsFieldType.Number -> KeyboardType.Number
        EsFieldType.Email -> KeyboardType.Email
        EsFieldType.Phone -> KeyboardType.Phone
        EsFieldType.Password -> KeyboardType.Password
        else -> KeyboardType.Text
    }
    // Request password/email input without autocorrect or capitalization.
    // The Compose bridge omits AUTO_CORRECT; this is not an OEM keyboard audit.
    val noSuggest = type == EsFieldType.Password || type == EsFieldType.Email
    val capitalization = if (noSuggest) {
        androidx.compose.ui.text.input.KeyboardCapitalization.None
    } else {
        androidx.compose.ui.text.input.KeyboardCapitalization.Sentences
    }
    val visualTransformation: VisualTransformation =
        if (type == EsFieldType.Password) PasswordVisualTransformation() else VisualTransformation.None
    val inputLabel = label ?: placeholder
    Column(modifier = modifier.fillMaxWidth()) {
        inputLabel?.let {
            Text(it, style = EsType.Label,
                color = if (error != null) palette.error.content else if (enabled) palette.muted else palette.disabled.content,
                modifier = Modifier.padding(start = 4.dp, bottom = 6.dp).semantics { hideFromAccessibility() })
        }
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics {
                if (inputLabel != null) contentDescription = inputLabel
                if (error != null) error(error)
            },
            placeholder = placeholder?.takeIf { label != null }?.let { { Text(it, style = EsType.Body) } },
            supportingText = (error ?: hint)?.let { { Text(it, style = EsType.BodySm) } },
            leadingIcon = leading,
            trailingIcon = trailing,
            isError = error != null,
            singleLine = type != EsFieldType.Multiline,
            minLines = if (type == EsFieldType.Multiline) 3 else 1,
            visualTransformation = visualTransformation,
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                autoCorrectEnabled = !noSuggest,
                capitalization = capitalization,
                imeAction = imeAction,
            ),
            keyboardActions = KeyboardActions(
                onDone = {
                    finishInput()
                },
                onSend = {
                    finishInput()
                },
                onGo = {
                    finishInput()
                },
                onSearch = {
                    finishInput()
                },
            ),
            enabled = enabled,
            shape = RoundedCornerShape(EsRadius.Md),
            colors = esInputColors(palette),
            textStyle = EsType.Body,
        )
    }
}
