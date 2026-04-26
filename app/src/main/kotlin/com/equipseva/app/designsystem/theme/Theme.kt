package com.equipseva.app.designsystem.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = BrandGreen,
    onPrimary = Surface0,
    primaryContainer = Color98Green,
    onPrimaryContainer = BrandGreenDark,
    // S5 brand: vibrant electric-lime accent as the secondary slot.
    secondary = AccentLime,
    onSecondary = BrandGreenDeep,
    secondaryContainer = AccentLimeSoft,
    onSecondaryContainer = BrandGreenDeep,
    tertiary = BrandGreenDeep,
    onTertiary = Surface0,
    background = Surface50,
    onBackground = Ink900,
    surface = Surface0,
    onSurface = Ink900,
    surfaceVariant = Surface100,
    onSurfaceVariant = Ink500,
    outline = Outline,
    outlineVariant = Surface100,
    error = ErrorRed,
    onError = Surface0,
)

private val DarkColors = darkColorScheme(
    primary = AccentLime,
    onPrimary = BrandGreenDeep,
    primaryContainer = BrandGreenDark,
    onPrimaryContainer = AccentLimeBright,
    secondary = BrandGreenLight,
    onSecondary = Ink900,
    secondaryContainer = Ink700,
    onSecondaryContainer = AccentLimeBright,
    tertiary = BrandGreenLight,
    onTertiary = Ink900,
    background = Ink900,
    onBackground = Surface0,
    surface = InkSurface,
    onSurface = Surface0,
    surfaceVariant = Ink700,
    onSurfaceVariant = Ink300,
    outline = Ink500,
    outlineVariant = Ink700,
    error = ErrorRed,
    onError = Surface0,
)

@Composable
fun EquipSevaTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colors = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val ctx = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }
    MaterialTheme(
        colorScheme = colors,
        typography = EquipSevaTypography,
        shapes = EquipSevaShapes,
        content = content,
    )
}
