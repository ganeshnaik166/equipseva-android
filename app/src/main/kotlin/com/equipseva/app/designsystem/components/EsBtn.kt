package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGlow
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen800
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.BorderDefault

enum class EsBtnKind {
    Primary,         // green-700 fill, white text
    Forest,          // green-900 dark, white text
    Lime,            // glow green, near-black text
    Secondary,       // white fill, ink-900 text, ink-100 border
    Ghost,           // transparent, ink-700 text
    DangerOutline,   // danger border + danger text
    Danger,          // danger fill, white text
}

enum class EsBtnSize { Sm, Md, Lg }

private data class BtnVisual(val bg: Color, val fg: Color, val border: Color?)

private fun visual(kind: EsBtnKind, disabled: Boolean): BtnVisual {
    if (disabled) return BtnVisual(Color(0xFFE2E7E2), SevaInk500, null)
    return when (kind) {
        EsBtnKind.Primary       -> BtnVisual(SevaGreen700, Color.White, null)
        EsBtnKind.Forest        -> BtnVisual(SevaGreen900, Color.White, null)
        EsBtnKind.Lime          -> BtnVisual(SevaGlow, SevaGreen900, null)
        EsBtnKind.Secondary     -> BtnVisual(Color.White, SevaInk900, BorderDefault)
        EsBtnKind.Ghost         -> BtnVisual(Color.Transparent, SevaInk900, null)
        EsBtnKind.DangerOutline -> BtnVisual(Color.White, SevaDanger500, SevaDanger500)
        EsBtnKind.Danger        -> BtnVisual(SevaDanger500, Color.White, null)
    }
}

private fun heightFor(size: EsBtnSize): Dp = when (size) {
    EsBtnSize.Sm -> 36.dp
    EsBtnSize.Md -> 44.dp
    EsBtnSize.Lg -> 52.dp
}

@Composable
fun EsBtn(
    text: String,
    onClick: () -> Unit,
    kind: EsBtnKind = EsBtnKind.Primary,
    size: EsBtnSize = EsBtnSize.Md,
    full: Boolean = false,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    disabled: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val v = visual(kind, disabled)
    val shape = RoundedCornerShape(EsRadius.Md)
    Row(
        modifier = modifier
            .let { if (full) it.fillMaxWidth() else it }
            .height(heightFor(size))
            .clip(shape)
            .background(v.bg)
            .let { if (v.border != null) it.border(1.dp, v.border, shape) else it }
            .let { if (!disabled) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = if (full) Arrangement.Center else Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(16.dp), contentAlignment = Alignment.Center) { leading() }
            Box(modifier = Modifier.size(8.dp))
        }
        Text(text = text, style = EsType.Label, color = v.fg)
        if (trailing != null) {
            Box(modifier = Modifier.size(8.dp))
            Box(modifier = Modifier.size(16.dp), contentAlignment = Alignment.Center) { trailing() }
        }
    }
}
