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
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.BorderStrong

// Toggle pill used for filters, specializations, brands, urgency picker.
// Active = filled green-50 + green-700 text; inactive = paper bg + ink-700.
@Composable
fun EsChip(
    text: String,
    active: Boolean = false,
    onClick: (() -> Unit)? = null,
    leading: (@Composable () -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val bg = if (active) SevaGreen50 else PaperDefault
    val border = if (active) SevaGreen700 else BorderDefault
    val fg = if (active) SevaGreen700 else SevaInk700
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(EsRadius.Pill))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
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
