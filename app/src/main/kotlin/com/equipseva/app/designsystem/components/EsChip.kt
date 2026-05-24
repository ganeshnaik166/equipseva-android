package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
    val bg = if (active) SevaGreen50 else PaperDefault
    val border = if (active) SevaGreen700 else BorderDefault
    val fg = if (active) SevaGreen700 else SevaInk700
    val a11yLabel = contentDescription ?: text
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(EsRadius.Pill))
            // Role.Button announces the verb to TalkBack
            // ("double-tap to activate"); the .semantics block below
            // adds the selected-state hint so the full announcement
            // is "<label>, selected, button" or "<label>, button"
            // depending on `active`. Without the role, TalkBack falls
            // back to the generic clickable announcement and users
            // can't tell EsChip apart from a passive label.
            .let { if (onClick != null) it.clickable(onClick = onClick, role = Role.Button) else it }
            .semantics {
                this.contentDescription = a11yLabel
                this.selected = active
            }
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
