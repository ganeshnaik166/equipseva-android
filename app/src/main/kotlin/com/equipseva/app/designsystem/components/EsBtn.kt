package com.equipseva.app.designsystem.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
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

import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.tooling.preview.Preview
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaInk500

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

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsBtnGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EsBtnKind.entries.forEach { kind ->
            Text(text = kind.name, style = EsType.Caption, color = SevaInk500)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                EsBtn(text = "Call", onClick = {}, kind = kind, size = EsBtnSize.Sm)
                EsBtn(text = "Accept bid", onClick = {}, kind = kind, size = EsBtnSize.Md)
                EsBtn(text = "Pay ₹4,500", onClick = {}, kind = kind, size = EsBtnSize.Lg)
            }
        }

        // Disabled styling ignores kind, so one row per size covers every kind.
        Text(text = "Disabled", style = EsType.Caption, color = SevaInk500)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            EsBtnSize.entries.forEach { size ->
                EsBtn(text = "Awaiting KYC", onClick = {}, size = size, disabled = true)
            }
        }

        Text(text = "Icon slots", style = EsType.Caption, color = SevaInk500)
        EsBtn(
            text = "Add equipment",
            onClick = {},
            kind = EsBtnKind.Primary,
            leading = { EsBtnGalleryIcon(Icons.Filled.Add, EsBtnKind.Primary) },
        )
        EsBtn(
            text = "View bids",
            onClick = {},
            kind = EsBtnKind.Secondary,
            trailing = { EsBtnGalleryIcon(Icons.AutoMirrored.Filled.ArrowForward, EsBtnKind.Secondary) },
        )
        EsBtn(
            text = "Confirm engineer",
            onClick = {},
            kind = EsBtnKind.Lime,
            size = EsBtnSize.Lg,
            leading = { EsBtnGalleryIcon(Icons.Filled.Check, EsBtnKind.Lime) },
            trailing = { EsBtnGalleryIcon(Icons.AutoMirrored.Filled.ArrowForward, EsBtnKind.Lime) },
        )
        EsBtn(
            text = "Cancel job",
            onClick = {},
            kind = EsBtnKind.DangerOutline,
            size = EsBtnSize.Sm,
            leading = { EsBtnGalleryIcon(Icons.Filled.Delete, EsBtnKind.DangerOutline) },
        )
        EsBtn(
            text = "Skip for now",
            onClick = {},
            kind = EsBtnKind.Ghost,
            trailing = { EsBtnGalleryIcon(Icons.AutoMirrored.Filled.ArrowForward, EsBtnKind.Ghost) },
        )
        EsBtn(
            text = "Add equipment",
            onClick = {},
            kind = EsBtnKind.Primary,
            leading = { EsBtnGalleryIcon(Icons.Filled.Add, EsBtnKind.Primary, disabled = true) },
            disabled = true,
        )

        Text(text = "Full width", style = EsType.Caption, color = SevaInk500)
        EsBtn(text = "Request repair quote", onClick = {}, full = true)
        EsBtn(
            text = "Pay ₹12,800 to Ramesh Iyer",
            onClick = {},
            kind = EsBtnKind.Lime,
            size = EsBtnSize.Lg,
            full = true,
            leading = { EsBtnGalleryIcon(Icons.Filled.Check, EsBtnKind.Lime) },
        )
        EsBtn(
            text = "Delete account",
            onClick = {},
            kind = EsBtnKind.Danger,
            full = true,
            trailing = { EsBtnGalleryIcon(Icons.Filled.Delete, EsBtnKind.Danger) },
        )
        EsBtn(text = "Continue", onClick = {}, full = true, disabled = true)

        Text(text = "Edge text", style = EsType.Caption, color = SevaInk500)
        EsBtn(text = "", onClick = {}, kind = EsBtnKind.Secondary)
        EsBtn(
            text = "Assign Ramesh Iyer (Senior Biomedical Engineer) to the Apollo Hospitals Chennai ventilator repair",
            onClick = {},
            full = true,
        )
    }
}

// Preview slots use the same paired tokens as EsBtn, including its disabled state.
@Composable
private fun EsBtnGalleryIcon(icon: ImageVector, kind: EsBtnKind, disabled: Boolean = false) {
    Icon(
        imageVector = icon,
        contentDescription = null,
        modifier = Modifier.size(16.dp),
        tint = if (disabled) EsTheme.colors.disabled.content else visual(kind, EsTheme.colors).fg,
    )
}

@Preview(name = "EsBtn", showBackground = true)
@Composable
private fun EsBtnPreview() {
    EquipSevaTheme(darkTheme = false) { EsBtnGallery() }
}

@Preview(name = "EsBtn large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsBtnPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsBtnGallery() }
}
