package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.SevaGreen500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaWarning500
import androidx.compose.ui.text.TextStyle

enum class OnlineStatus { Available, Busy, Offline }

private val AvatarBrush = Brush.linearGradient(listOf(SevaGreen700, SevaGreen500))

// Initials inside a green-gradient circle, with optional online-status
// dot at top-right (8dp circle, white border, status-tinted fill).
@Composable
fun Avatar(
    initials: String,
    size: Dp = 40.dp,
    online: OnlineStatus? = null,
    modifier: Modifier = Modifier,
) {
    val fontSize = (size.value * 0.4f).sp
    Box(modifier = modifier.size(size)) {
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(AvatarBrush),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = initials.take(2).uppercase(),
                color = Color.White,
                fontFamily = EsFontFamily,
                fontWeight = FontWeight.SemiBold,
                style = TextStyle(fontSize = fontSize),
            )
        }
        if (online != null) {
            val dotColor = when (online) {
                OnlineStatus.Available -> SevaGreen500
                OnlineStatus.Busy -> SevaWarning500
                OnlineStatus.Offline -> SevaInk300
            }
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 1.dp, y = (-1).dp)
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(Color.White),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(dotColor)
                        .border(0.dp, Color.Transparent, CircleShape),
                )
            }
        }
    }
}
