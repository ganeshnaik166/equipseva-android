package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.BorderDefault

// Toggle pill used for filters, specializations, brands, urgency picker.
// Active = filled green-50 + green-700 text; inactive = paper bg + ink-700.
//
// Accessibility: every chip carries a contentDescription so TalkBack
// reads "<label>, selected" or "<label>" instead of just the label
// — without this every filter pill was an unlabeled tap target.
@Composable
fun EsChip(
    text: String,
    modifier: Modifier = Modifier,
    active: Boolean = false,
    onClick: (() -> Unit)? = null,
    leading: (@Composable () -> Unit)? = null,
    contentDescription: String? = null,
) {
    val a11yLabel = contentDescription ?: text

    // A passive pill is a label, so it keeps the painted size exactly and
    // reserves nothing: only something tappable owes a touch target.
    if (onClick == null) {
        ChipPill(
            text = text,
            active = active,
            leading = leading,
            modifier = modifier.semantics {
                this.contentDescription = a11yLabel
                this.selected = active
            },
        )
        return
    }

    // The painted pill is 32 dp tall and often under 48 dp wide, which is
    // below the interactive minimum every one of these filter / spec /
    // urgency chips has to meet. The tap target has to be the node that
    // actually handles the tap: Material's `minimumInteractiveComponentSize`
    // is a LayoutModifierNode, so wrapping the pill in it reserves the space
    // in the parent row and leaves the hit area the size of the paint.
    //
    // So the click lives on an outer box measured to the minimum, and the
    // ripple is handed back to the pill through a shared interaction source
    // — otherwise the indication would fill the invisible 48 dp square and
    // every chip in the app would flash a rectangle instead of a pill.
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .sizeIn(minWidth = Spacing.MinTouchTarget, minHeight = Spacing.MinTouchTarget)
            .clickable(
                interactionSource = interaction,
                indication = null,
                // Role.Button announces the verb to TalkBack
                // ("double-tap to activate"); the .semantics block below
                // adds the selected-state hint so the full announcement
                // is "<label>, selected, button" or "<label>, button"
                // depending on `active`. Without the role, TalkBack falls
                // back to the generic clickable announcement and users
                // can't tell EsChip apart from a passive label.
                role = Role.Button,
                onClick = onClick,
            )
            .semantics {
                this.contentDescription = a11yLabel
                this.selected = active
            },
        contentAlignment = Alignment.Center,
    ) {
        ChipPill(
            text = text,
            active = active,
            leading = leading,
            interaction = interaction,
        )
    }
}

/**
 * The painted pill. It handles no input; [interaction] only lets it show the
 * ripple for a click its wrapper received.
 */
@Composable
private fun ChipPill(
    text: String,
    active: Boolean,
    leading: (@Composable () -> Unit)?,
    modifier: Modifier = Modifier,
    interaction: MutableInteractionSource? = null,
) {
    val bg = if (active) SevaGreen50 else PaperDefault
    val border = if (active) SevaGreen700 else BorderDefault
    val fg = if (active) SevaGreen700 else SevaInk700
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(EsRadius.Pill))
            // After the clip, so the ripple is bounded by the pill instead of
            // painting a rectangle over the reserved touch target.
            .then(
                if (interaction != null) {
                    Modifier.indication(interaction, ripple())
                } else {
                    Modifier
                },
            )
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(14.dp), contentAlignment = Alignment.Center) { leading() }
        }
        Text(text = text, style = EsType.Label, color = fg)
    }
}
