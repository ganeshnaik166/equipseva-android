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
    secondary = BrandGreenDark,
    onSecondary = Surface0,
    secondaryContainer = Surface100,
    onSecondaryContainer = Ink900,
    tertiary = BrandGreenLight,
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
    primary = BrandGreenLight,
    onPrimary = Ink900,
    primaryContainer = BrandGreenDark,
    onPrimaryContainer = Surface0,
    secondary = BrandGreen,
    onSecondary = Surface0,
    secondaryContainer = Ink700,
    onSecondaryContainer = Surface0,
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
