package com.equipseva.app.designsystem.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.EsTheme

enum class EsBtnKind { Primary, Lime, Secondary, Ghost, DangerOutline, Danger }
enum class EsBtnSize { Sm, Md, Lg }

private data class BtnVisual(val bg: Color, val fg: Color, val border: Color?)

private fun visual(kind: EsBtnKind, p: EsColors): BtnVisual = when (kind) {
    EsBtnKind.Primary, EsBtnKind.Lime -> BtnVisual(p.action.container, p.action.content, p.outline)
    EsBtnKind.Secondary -> BtnVisual(p.surface, p.text, p.outline)
    EsBtnKind.Ghost -> BtnVisual(Color.Transparent, p.text, null)
    EsBtnKind.DangerOutline -> BtnVisual(p.surface, p.error.content, p.error.content)
    EsBtnKind.Danger -> BtnVisual(p.error.content, p.error.container, null)
}

/** Physical minimum, never a fixed text height. Primary kinds always have at least 52dp. */
internal fun heightFor(size: EsBtnSize): Dp = when (size) {
    EsBtnSize.Sm -> 48.dp
    EsBtnSize.Md, EsBtnSize.Lg -> 52.dp
}

@Composable
fun EsBtn(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    kind: EsBtnKind = EsBtnKind.Primary,
    size: EsBtnSize = EsBtnSize.Md,
    full: Boolean = false,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    disabled: Boolean = false,
    contentColor: Color = Color.Unspecified,
) {
    val p = EsTheme.colors
    val defaults = visual(kind, p)
    // Explicit foreground is for legacy fixed-surface callers; disabled controls keep a paired fill.
    val v = if (contentColor == Color.Unspecified) defaults else defaults.copy(fg = contentColor)
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val primary = kind == EsBtnKind.Primary || kind == EsBtnKind.Lime
    val floor = if (primary) maxOf(52.dp, heightFor(size)) else heightFor(size)
    val borderColor = if (focused) {
        // Focus stays inside the fill. Ink remains distinct from lime even on a dark parent.
        if (primary) p.action.content else v.fg
    } else if (disabled) p.outline else v.border
    Button(
        onClick = onClick,
        enabled = !disabled,
        modifier = modifier.let { if (full) it.fillMaxWidth() else it }.heightIn(min = floor),
        shape = RoundedCornerShape(26.dp),
        border = borderColor?.let { BorderStroke(if (focused) 3.dp else 1.dp, it) },
        interactionSource = interaction,
        contentPadding = PaddingValues(horizontal = if (size == EsBtnSize.Lg) 24.dp else 16.dp, vertical = 12.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = v.bg, contentColor = v.fg,
            disabledContainerColor = p.disabled.container, disabledContentColor = p.disabled.content,
        ),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (leading != null) Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) { leading() }
            Text(text, style = if (size == EsBtnSize.Sm) MaterialTheme.typography.labelMedium else MaterialTheme.typography.labelLarge,
                textAlign = if (full) TextAlign.Center else TextAlign.Start,
                modifier = Modifier.weight(1f, fill = full))
            if (trailing != null) Box(Modifier.size(20.dp), contentAlignment = Alignment.Center) { trailing() }
        }
    }
}
