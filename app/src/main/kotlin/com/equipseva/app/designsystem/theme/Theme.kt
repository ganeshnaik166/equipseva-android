package com.equipseva.app.designsystem.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext

private fun materialColors(dark: Boolean) = (if (dark) darkColorScheme() else lightColorScheme()).let { base ->
    val p = if (dark) DarkEsColors else LightEsColors
    // Material primary is also text, cursor, radio and progress foreground. Lime on white
    // is 1.19:1, so light mode uses ink here. Explicit primary actions use p.action instead.
    base.copy(
        primary = if (dark) p.action.container else p.text,
        onPrimary = if (dark) p.action.content else p.surface,
        primaryContainer = p.action.container, onPrimaryContainer = p.action.content,
        inversePrimary = p.inverseFocus,
        secondary = p.muted, onSecondary = p.surface,
        secondaryContainer = p.raised, onSecondaryContainer = p.text,
        tertiary = p.info.content, onTertiary = p.info.container,
        tertiaryContainer = p.info.container, onTertiaryContainer = p.info.content,
        background = p.canvas, onBackground = p.text,
        surface = p.surface, onSurface = p.text,
        surfaceVariant = p.raised, onSurfaceVariant = p.muted,
        surfaceTint = Color.Transparent,
        inverseSurface = p.inverse.container, inverseOnSurface = p.inverse.content,
        surfaceDim = p.canvas, surfaceBright = p.raised,
        surfaceContainerLowest = p.canvas, surfaceContainerLow = p.surface,
        surfaceContainer = p.surface, surfaceContainerHigh = p.raised,
        surfaceContainerHighest = p.raised,
        outline = p.outline, outlineVariant = p.divider,
        error = p.error.content, onError = p.error.container,
        errorContainer = p.error.container, onErrorContainer = p.error.content,
        scrim = Color.Black,
    )
}

private val LightColors = materialColors(false)
private val DarkColors = materialColors(true)

@Composable
fun EquipSevaTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    // Preserve the explicit opt-in API. App callers keep wallpaper colors disabled by default.
    val colors = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val ctx = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        }
        darkTheme -> DarkColors
        else -> LightColors
    }
    val language = LocalConfiguration.current.locales[0]?.language.orEmpty()
    CompositionLocalProvider(LocalEsColors provides if (darkTheme) DarkEsColors else LightEsColors) {
        MaterialTheme(
            colorScheme = colors,
            typography = typographyForLanguage(language),
            shapes = EquipSevaShapes,
            content = content,
        )
    }
}