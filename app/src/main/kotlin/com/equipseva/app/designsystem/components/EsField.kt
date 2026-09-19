package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Icon
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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
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

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsFieldGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EsField(
            value = "Apollo Hospitals, Jubilee Hills",
            onChange = {},
            label = "Hospital name",
            type = EsFieldType.Text,
        )
        EsField(
            value = "",
            onChange = {},
            placeholder = "Search equipment, e.g. Philips MX450",
            leading = { Icon(Icons.Outlined.Search, contentDescription = null) },
        )
        EsField(
            value = "ventilator-2024",
            onChange = {},
            label = "Password",
            type = EsFieldType.Password,
            trailing = { Icon(Icons.Filled.Visibility, contentDescription = null) },
        )
        EsField(
            value = "4500",
            onChange = {},
            label = "Quoted amount (₹)",
            hint = "Excludes 18% GST; parts billed separately",
            type = EsFieldType.Number,
        )
        EsField(
            value = "rohit.verma@apollohospitals.com",
            onChange = {},
            label = "Work email",
            type = EsFieldType.Email,
            leading = { Icon(Icons.Outlined.Email, contentDescription = null) },
        )
        EsField(
            value = "9876543210",
            onChange = {},
            label = "Mobile number",
            hint = "OTP will be sent to this number",
            type = EsFieldType.Phone,
            leading = { Icon(Icons.Outlined.Phone, contentDescription = null) },
            trailing = { Icon(Icons.Outlined.Check, contentDescription = null) },
        )
        EsField(
            value = "Ventilator raises a 'Low O2 supply' alarm every 10 minutes even though " +
                "pipeline pressure reads 4.2 bar. Last serviced by Sunil Kumar on 12 Aug; " +
                "humidifier chamber was replaced then.",
            onChange = {},
            label = "Fault description",
            type = EsFieldType.Multiline,
        )
        EsField(
            value = "",
            onChange = {},
            label = "Notes for engineer",
            placeholder = "Anything the engineer should know before the visit",
            type = EsFieldType.Multiline,
        )
        EsField(
            value = "",
            onChange = {},
            label = "Equipment serial number",
            placeholder = "e.g. SN-MX450-118842",
            error = "Serial number is required to raise a repair job",
        )
        EsField(
            value = "98765",
            onChange = {},
            label = "Mobile number",
            error = "Enter the full 10-digit mobile number registered with Fortis Hospital, " +
                "Bannerghatta Road",
            type = EsFieldType.Phone,
        )
        EsField(
            value = "Sunil Kumar",
            onChange = {},
            label = "Assigned engineer",
            hint = "Assigned by EquipSeva; contact support to change",
            enabled = false,
        )
        EsField(
            value = "",
            onChange = {},
            label = "Bid amount (₹)",
            placeholder = "₹4,500",
            type = EsFieldType.Number,
            enabled = false,
        )
    }
}

@Preview(name = "EsField", showBackground = true)
@Composable
private fun EsFieldPreview() {
    EquipSevaTheme(darkTheme = false) { EsFieldGallery() }
}

@Preview(name = "EsField large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsFieldPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsFieldGallery() }
}
