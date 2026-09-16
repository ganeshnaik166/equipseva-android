package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaGreen500
import com.equipseva.app.designsystem.theme.SevaGreen700
import java.util.Locale

private val AvatarBrush = Brush.linearGradient(listOf(SevaGreen700, SevaGreen500))

// Initials inside a green-gradient circle.
@Composable
fun Avatar(
    initials: String,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
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

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun AvatarGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Sizes 24 / 32 / 40 (default) / 56 / 72 dp", style = EsType.Caption)
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Avatar(initials = "RK", size = 24.dp)
            Avatar(initials = "RK", size = 32.dp)
            Avatar(initials = "RK")
            Avatar(initials = "RK", size = 56.dp)
            Avatar(initials = "RK", size = 72.dp)
        }
        Text(
            text = "Initials: single letter, lowercase, full name (truncated), empty, \"li\"",
            style = EsType.Caption,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Avatar(initials = "A")
            Avatar(initials = "pm")
            Avatar(initials = "Suresh Iyer")
            Avatar(initials = "")
            Avatar(initials = "li")
        }
    }
}

@Preview(name = "Avatar", showBackground = true)
@Composable
private fun AvatarPreview() {
    EquipSevaTheme(darkTheme = false) { AvatarGallery() }
}

@Preview(name = "Avatar large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun AvatarPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { AvatarGallery() }
}
