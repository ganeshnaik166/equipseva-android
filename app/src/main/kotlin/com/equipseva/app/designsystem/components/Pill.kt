package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaGlow
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen800
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaSuccess500
import com.equipseva.app.designsystem.theme.SevaSuccess50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.Paper3

enum class PillKind { Default, Success, Warn, Info, Danger, Forest, Lime, Neutral }

private data class PillColors(val bg: Color, val fg: Color, val border: Color?)

private fun colorsFor(kind: PillKind): PillColors = when (kind) {
    PillKind.Default -> PillColors(SevaGreen50,  SevaGreen700,  null)
    PillKind.Success -> PillColors(SevaSuccess50, SevaSuccess500, null)
    PillKind.Warn    -> PillColors(SevaWarning50, SevaWarning500, null)
    PillKind.Info    -> PillColors(SevaInfo50,   SevaInfo500,    null)
    PillKind.Danger  -> PillColors(SevaDanger50, SevaDanger500,  null)
    PillKind.Forest  -> PillColors(SevaGreen900, Color.White,    null)
    PillKind.Lime    -> PillColors(SevaGlow,     SevaGreen900,   null)
    PillKind.Neutral -> PillColors(Paper3,       SevaInk500,     null)
}

@Composable
fun Pill(
    text: String,
    kind: PillKind = PillKind.Default,
    leading: (@Composable () -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val c = colorsFor(kind)
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(c.bg)
            .let { if (c.border != null) it.border(1.dp, c.border, RoundedCornerShape(EsRadius.Pill)) else it }
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(12.dp), contentAlignment = Alignment.Center) { leading() }
        }
        Text(text = text, style = EsType.Caption, color = c.fg)
    }
}
