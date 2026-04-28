package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

private val Gold = Color(0xFFF5A623)

// Single gold star + numeric rating + optional "(N)" review count.
// Used on engineer cards, public profiles, hospital banners.
@Composable
fun Stars(
    rating: Double,
    count: Int? = null,
    small: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val iconSize = if (small) 12.dp else 14.dp
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Star,
            contentDescription = null,
            tint = Gold,
            modifier = Modifier.size(iconSize),
        )
        Text(
            text = "%.1f".format(rating),
            style = if (small) EsType.Caption else EsType.Label,
            color = SevaInk900,
        )
        if (count != null) {
            Text(
                text = "($count)",
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
    }
}
