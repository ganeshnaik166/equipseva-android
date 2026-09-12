package com.equipseva.app.designsystem.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp

/** Legacy body-family call sites follow the active app locale. Page headings use EsType.H2. */
val EsFontFamily: FontFamily
    @Composable @ReadOnlyComposable get() = MaterialTheme.typography.bodyLarge.fontFamily ?: FontFamily.Default

// Retain explicit-size tokens for callers pending page-level migration.
val EsTextXs = 12.sp
val EsTextSm = 14.sp
val EsTextMd = 16.sp
val EsTextLg = 18.sp
val EsTextXl = 20.sp
val EsText2xl = 24.sp
val EsText3xl = 32.sp
val EsText4xl = 44.sp
val EsText5xl = 60.sp
val EsText6xl = 80.sp

/** Compatibility names backed by canonical Material roles, including locale changes.
 * These are composable getters, not independent static styles. Non-UI code can use
 * EquipSevaTypography. Explicit sizes/families still need page-level migration.
 */
object EsType {
    val Display1: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.displayLarge
    val Display2: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.displayMedium
    val H1: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.headlineLarge
    val H2: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.headlineLarge
    val H3: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.headlineMedium
    val H4: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.headlineMedium
    val H5: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.headlineSmall
    val BodyLg: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.bodyLarge
    val Body: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.bodyLarge
    val BodySm: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.bodyMedium
    val Label: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.labelMedium
    val Caption: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.bodySmall
    val Overline: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.labelMedium
    val Mono: TextStyle @Composable @ReadOnlyComposable get() = MaterialTheme.typography.bodyMedium.copy(fontFeatureSettings = "tnum")
}
