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
    primaryContainer = BrandGreenLight,
    onPrimaryContainer = Ink900,
    secondary = BrandGreenDark,
    onSecondary = Surface0,
    background = Surface0,
    onBackground = Ink900,
    surface = Surface0,
    onSurface = Ink900,
    surfaceVariant = Surface100,
    onSurfaceVariant = Ink700,
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
    background = Ink900,
    onBackground = Surface0,
    surface = Ink900,
    onSurface = Surface0,
    surfaceVariant = Ink700,
    onSurfaceVariant = Ink300,
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
        content = content,
    )
}
