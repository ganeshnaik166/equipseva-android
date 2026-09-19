package com.equipseva.app.designsystem.components

import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.TextFieldColors
import androidx.compose.runtime.Composable
import com.equipseva.app.designsystem.theme.EsColors

/** Complete pairing also applies when a legacy caller explicitly owns a light surface. */
@Composable
internal fun esInputColors(p: EsColors): TextFieldColors = OutlinedTextFieldDefaults.colors(
    focusedContainerColor = p.surface, unfocusedContainerColor = p.surface,
    disabledContainerColor = p.disabled.container, errorContainerColor = p.surface,
    focusedTextColor = p.text, unfocusedTextColor = p.text,
    disabledTextColor = p.disabled.content, errorTextColor = p.text,
    cursorColor = p.text, errorCursorColor = p.error.content,
    selectionColors = TextSelectionColors(p.text, p.action.container.copy(alpha = 0.30f)),
    focusedBorderColor = p.focus, unfocusedBorderColor = p.outline,
    disabledBorderColor = p.outline, errorBorderColor = p.error.content,
    focusedLabelColor = p.muted, unfocusedLabelColor = p.muted,
    disabledLabelColor = p.disabled.content, errorLabelColor = p.error.content,
    focusedPlaceholderColor = p.muted, unfocusedPlaceholderColor = p.muted,
    disabledPlaceholderColor = p.disabled.content, errorPlaceholderColor = p.muted,
    focusedLeadingIconColor = p.muted, unfocusedLeadingIconColor = p.muted,
    disabledLeadingIconColor = p.disabled.content, errorLeadingIconColor = p.error.content,
    focusedTrailingIconColor = p.muted, unfocusedTrailingIconColor = p.muted,
    disabledTrailingIconColor = p.disabled.content, errorTrailingIconColor = p.error.content,
    focusedSupportingTextColor = p.muted, unfocusedSupportingTextColor = p.muted,
    disabledSupportingTextColor = p.disabled.content, errorSupportingTextColor = p.error.content,
)
