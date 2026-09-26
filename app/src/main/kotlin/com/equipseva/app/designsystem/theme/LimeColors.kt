package com.equipseva.app.designsystem.theme

import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.TextFieldColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/** Paired roles prevent a fill from accidentally becoming unreadable text. */
@Immutable
data class EsColorPair(val container: Color, val content: Color)

@Immutable
data class EsColors(
    val canvas: Color,
    val surface: Color,
    val raised: Color,
    val text: Color,
    val muted: Color,
    val outline: Color,
    val divider: Color,
    val focus: Color,
    val disabled: EsColorPair,
    val error: EsColorPair,
    val pending: EsColorPair,
    val success: EsColorPair,
    val info: EsColorPair,
) {
    val action: EsColorPair = EsColorPair(Color(0xFFC6FF00), Color(0xFF11150B))
    val inverse: EsColorPair = EsColorPair(Color(0xFF11150F), Color(0xFFF5F7F1))
    val inverseMuted: Color = Color(0xFFB9C2B1)
    val inverseOutline: Color = Color(0xFF86947B)
    val inverseFocus: Color = Color(0xFFC6FF00)
}

internal val LightEsColors = EsColors(
    canvas = Color(0xFFF4F5F2), surface = Color.White, raised = Color(0xFFEBEEE7),
    text = Color(0xFF11150F), muted = Color(0xFF555D50), outline = Color(0xFF6D7566),
    divider = Color(0xFFD9DED4), focus = Color(0xFF415600),
    disabled = EsColorPair(Color(0xFFE2E7DC), Color(0xFF555D50)),
    error = EsColorPair(Color(0xFFFFECEE), Color(0xFF972D32)),
    pending = EsColorPair(Color(0xFFFFF1CC), Color(0xFF775000)),
    success = EsColorPair(Color(0xFFE6F5EB), Color(0xFF185D38)),
    info = EsColorPair(Color(0xFFE7F0FC), Color(0xFF1B4F82)),
)

internal val DarkEsColors = EsColors(
    canvas = Color(0xFF0C0F0B), surface = Color(0xFF1B2018), raised = Color(0xFF282E23),
    text = Color(0xFFF5F7F1), muted = Color(0xFFB9C2B1), outline = Color(0xFF86947B),
    divider = Color(0xFF394132), focus = Color(0xFFC6FF00),
    disabled = EsColorPair(Color(0xFF30382A), Color(0xFFB9C2B1)),
    error = EsColorPair(Color(0xFF3A1E22), Color(0xFFFFC4CA)),
    pending = EsColorPair(Color(0xFF352B16), Color(0xFFFFE0A3)),
    success = EsColorPair(Color(0xFF173523), Color(0xFFA8E5BF)),
    info = EsColorPair(Color(0xFF182D43), Color(0xFFBEDAFF)),
)

internal val LocalEsColors = staticCompositionLocalOf { LightEsColors }

object EsTheme {
    val colors: EsColors
        @Composable @ReadOnlyComposable get() = LocalEsColors.current
}

/** Transitional complete field pairing for fixed PaperDefault/Surface50 parents. */
@Composable
internal fun legacyLightFieldColors(): TextFieldColors {
    val p = LightEsColors
    val error = p.error.content
    return OutlinedTextFieldDefaults.colors(
        focusedTextColor = p.text, unfocusedTextColor = p.text,
        disabledTextColor = p.disabled.content, errorTextColor = p.text,
        cursorColor = p.text,
        focusedBorderColor = p.focus, unfocusedBorderColor = p.outline,
        disabledBorderColor = p.outline,
        focusedLabelColor = p.text, unfocusedLabelColor = p.muted,
        disabledLabelColor = p.disabled.content,
        focusedPlaceholderColor = p.muted, unfocusedPlaceholderColor = p.muted,
        disabledPlaceholderColor = p.disabled.content,
        focusedLeadingIconColor = p.muted, unfocusedLeadingIconColor = p.muted,
        disabledLeadingIconColor = p.disabled.content,
        focusedTrailingIconColor = p.muted, unfocusedTrailingIconColor = p.muted,
        disabledTrailingIconColor = p.disabled.content,
        focusedSupportingTextColor = p.muted, unfocusedSupportingTextColor = p.muted,
        disabledSupportingTextColor = p.disabled.content,
        selectionColors = androidx.compose.foundation.text.selection.TextSelectionColors(
            handleColor = p.text, backgroundColor = p.action.container.copy(alpha = 0.30f),
        ),
        errorCursorColor = error,
        errorBorderColor = error,
        errorLabelColor = error,
        errorLeadingIconColor = error,
        errorTrailingIconColor = error,
        errorSupportingTextColor = error,
        errorPlaceholderColor = p.muted,
    )
}
