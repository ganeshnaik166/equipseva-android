package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
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

// Inline KYC trust badge. Small variant fits in a row of metadata; the
// default sits next to the engineer name in profiles.
@Composable
fun VerifiedBadge(small: Boolean = false, modifier: Modifier = Modifier) {
    val iconSize = if (small) 12.dp else 14.dp
    val padH = if (small) 6.dp else 8.dp
    val padV = if (small) 2.dp else 4.dp
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(EsRadius.Pill))
            .background(SevaGreen50)
            .padding(horizontal = padH, vertical = padV),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Verified,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(iconSize),
        )
        Text(text = "Verified", style = EsType.Caption, color = SevaGreen700)
    }
}
