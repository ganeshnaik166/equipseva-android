package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
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
                onSend = {
                    onImeAction?.invoke()
                    keyboardController?.hide()
                },
                onGo = {
                    onImeAction?.invoke()
                    keyboardController?.hide()
                },
                onSearch = {
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
