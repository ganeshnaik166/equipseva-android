package com.equipseva.app.designsystem.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontSynthesis
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.equipseva.app.R

internal val SpaceGrotesk = FontFamily(Font(R.font.space_grotesk_semibold, FontWeight.SemiBold))
internal val Inter = FontFamily(
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
)
internal val Devanagari = FontFamily(
    Font(R.font.noto_sans_devanagari_regular, FontWeight.Normal),
    Font(R.font.noto_sans_devanagari_medium, FontWeight.Medium),
    Font(R.font.noto_sans_devanagari_semibold, FontWeight.SemiBold),
)
internal val Telugu = FontFamily(
    Font(R.font.noto_sans_telugu_regular, FontWeight.Normal),
    Font(R.font.noto_sans_telugu_medium, FontWeight.Medium),
    Font(R.font.noto_sans_telugu_semibold, FontWeight.SemiBold),
)

private fun typography(heading: FontFamily, body: FontFamily): Typography {
    fun style(family: FontFamily, size: Int, line: Int, weight: FontWeight) = TextStyle(
        fontFamily = family, fontSize = size.sp, lineHeight = line.sp, fontWeight = weight,
        letterSpacing = 0.sp, fontSynthesis = FontSynthesis.None,
        // Keep marks above/below Indic glyphs inside the layout on supported Android versions.
        platformStyle = PlatformTextStyle(includeFontPadding = true),
    )
    val page = style(heading, 28, 34, FontWeight.SemiBold)
    val section = style(heading, 20, 26, FontWeight.SemiBold)
    val card = style(heading, 18, 24, FontWeight.SemiBold)
    return Typography(
        displayLarge = page, displayMedium = page, displaySmall = page,
        headlineLarge = page, headlineMedium = section, headlineSmall = card,
        titleLarge = section, titleMedium = card,
        titleSmall = style(body, 16, 24, FontWeight.SemiBold),
        bodyLarge = style(body, 16, 24, FontWeight.Normal),
        bodyMedium = style(body, 14, 20, FontWeight.Normal),
        bodySmall = style(body, 12, 18, FontWeight.Normal),
        labelLarge = style(body, 16, 24, FontWeight.SemiBold),
        labelMedium = style(body, 14, 20, FontWeight.SemiBold),
        labelSmall = style(body, 12, 18, FontWeight.Medium),
    )
}

/** Immutable English styles remain usable outside composition. Theme selects the active locale. */
val EquipSevaTypography = typography(SpaceGrotesk, Inter)
private val HindiTypography = typography(Devanagari, Devanagari)
private val TeluguTypography = typography(Telugu, Telugu)

/** Distinct resource IDs invalidate Compose's font cache when the configured language changes.
 * Other scripts in mixed names use Android's system fallback; these families are not a glyph chain.
 */
internal fun typographyForLanguage(language: String): Typography = when (language) {
    "hi" -> HindiTypography
    "te" -> TeluguTypography
    else -> EquipSevaTypography
}