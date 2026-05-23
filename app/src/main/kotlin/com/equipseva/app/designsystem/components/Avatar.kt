package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.SevaGreen500
import com.equipseva.app.designsystem.theme.SevaGreen700
import java.util.Locale

private val AvatarBrush = Brush.linearGradient(listOf(SevaGreen700, SevaGreen500))

// Initials inside a green-gradient circle.
@Composable
fun Avatar(
    initials: String,
    size: Dp = 40.dp,
    modifier: Modifier = Modifier,
) {
    val fontSize = (size.value * 0.4f).sp
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(AvatarBrush),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = avatarDisplayInitials(initials),
            color = Color.White,
            fontFamily = EsFontFamily,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontSize = fontSize),
        )
    }
}

/**
 * Avatar display initials.
 *
 * Truncates the source to 2 characters and uppercases with
 * Locale.ENGLISH. Critical regression target: Turkish-locale
 * default uppercase() maps 'i' to dotted-capital 'İ' (and 'I' to
 * dotless 'ı'), corrupting initials for English names like
 * "ig" → "İG" or "li" → "Lİ". Pin Locale.ENGLISH so the rendering
 * stays consistent regardless of device locale.
 */
internal fun avatarDisplayInitials(initials: String): String =
    initials.take(2).uppercase(Locale.ENGLISH)
