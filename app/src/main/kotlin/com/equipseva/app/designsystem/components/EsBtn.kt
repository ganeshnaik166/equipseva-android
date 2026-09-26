package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGlow
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk100
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.BorderDefault

enum class EsBtnKind {
    Primary,         // green-700 fill, white text
    Lime,            // glow green, near-black text
    Secondary,       // white fill, ink-900 text, ink-100 border
    Ghost,           // transparent, ink-700 text
    DangerOutline,   // danger border + danger text
    Danger,          // danger fill, white text
}

enum class EsBtnSize { Sm, Md, Lg }

private data class BtnVisual(val bg: Color, val fg: Color, val border: Color?)

private fun visual(kind: EsBtnKind, disabled: Boolean): BtnVisual {
    if (disabled) return BtnVisual(SevaInk100, SevaInk500, null)
    return when (kind) {
        EsBtnKind.Primary       -> BtnVisual(SevaGreen700, Color.White, null)
        EsBtnKind.Lime          -> BtnVisual(SevaGlow, SevaGreen900, null)
        EsBtnKind.Secondary     -> BtnVisual(Color.White, SevaInk900, BorderDefault)
        EsBtnKind.Ghost         -> BtnVisual(Color.Transparent, SevaInk900, null)
        EsBtnKind.DangerOutline -> BtnVisual(Color.White, SevaDanger500, SevaDanger500)
        EsBtnKind.Danger        -> BtnVisual(SevaDanger500, Color.White, null)
    }
}

/**
 * Pin the per-size button height. The values are exposed so the
 * 44dp Md default (matches Material 3's accessibility-minimum touch
 * target) and the 44dp Sm / 52dp Lg variants stay frozen — a
 * regression to <44dp on Md/Sm would silently degrade tap-target
 * accessibility across every primary CTA.
 *
 * Round 461: bumped Sm from 36dp → 44dp. 36dp was 12dp under WCAG /
 * Material's 48dp recommendation; the only reason Sm was kept smaller
 * was visual density, but the buttons are real interactive CTAs (not
 * visual hints) so the smaller hit area was a real a11y defect.
 */
internal fun heightFor(size: EsBtnSize): Dp = when (size) {
    EsBtnSize.Sm -> 44.dp
    EsBtnSize.Md -> 44.dp
    EsBtnSize.Lg -> 52.dp
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
    labelStyle: TextStyle = EsType.Label,
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
            // Use clickable's `enabled` flag instead of skipping the
            // modifier entirely — a disabled button must still announce
            // itself as a button to TalkBack ("Disabled, Button") so
            // users know the affordance exists. Role.Button gives the
            // a11y service the verb hint ("double-tap to activate") for
            // every EsBtn callsite in the app at once.
            .clickable(
                enabled = !disabled,
                onClick = onClick,
                role = Role.Button,
            )
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = if (full) Arrangement.Center else Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(16.dp), contentAlignment = Alignment.Center) { leading() }
            Box(modifier = Modifier.size(8.dp))
        }
        Text(text = text, style = labelStyle, color = v.fg)
        if (trailing != null) {
            Box(modifier = Modifier.size(8.dp))
            Box(modifier = Modifier.size(16.dp), contentAlignment = Alignment.Center) { trailing() }
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

// Slot content gets no colour from EsBtn, so the sample icon reuses the
// button's own foreground rule to stay legible on every kind.
@Composable
private fun EsBtnGalleryIcon(icon: ImageVector, kind: EsBtnKind, disabled: Boolean = false) {
    Icon(
        imageVector = icon,
        contentDescription = null,
        modifier = Modifier.size(16.dp),
        tint = visual(kind, disabled).fg,
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
