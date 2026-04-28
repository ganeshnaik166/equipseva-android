package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

// Touchable list row used everywhere settings rows live (Profile sub-
// pages, Notifications inbox, KYC sections). Optional leading icon-box
// + title + subtitle stack + trailing widget (chevron, pill, switch).
@Composable
fun EsListRow(
    title: String,
    subtitle: String? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    danger: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val titleColor = if (danger) SevaDanger500 else SevaInk900
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.White)
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (leading != null) {
            Box(modifier = Modifier.size(36.dp), contentAlignment = Alignment.Center) { leading() }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, style = EsType.Label, color = titleColor)
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = EsType.Caption,
                    color = SevaInk500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
        if (trailing != null) trailing()
    }
}
