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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import androidx.compose.ui.graphics.Color

enum class EsBottomTab { Home, Repair, Profile }

// 3-tab bottom nav matching `shared.jsx:BottomNav`. Active tab gets
// a green-50 pill behind icon + label; inactive shows ink-500 icon
// + label. Repair tab supports an optional red badge (e.g. unread
// count, new-bid notifications).
@Composable
fun EsBottomNav(
    current: EsBottomTab,
    onSelect: (EsBottomTab) -> Unit,
    repairBadge: Int? = null,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(72.dp)
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        TabSlot(
            tab = EsBottomTab.Home,
            label = "Home",
            icon = Icons.Filled.Home,
            current = current,
            onSelect = onSelect,
            modifier = Modifier.weight(1f),
        )
        TabSlot(
            tab = EsBottomTab.Repair,
            label = "Repair",
            icon = Icons.Filled.Build,
            current = current,
            onSelect = onSelect,
            badge = repairBadge,
            modifier = Modifier.weight(1f),
        )
        TabSlot(
            tab = EsBottomTab.Profile,
            label = "Profile",
            icon = Icons.Filled.Person,
            current = current,
            onSelect = onSelect,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun TabSlot(
    tab: EsBottomTab,
    label: String,
    icon: ImageVector,
    current: EsBottomTab,
    onSelect: (EsBottomTab) -> Unit,
    badge: Int? = null,
    modifier: Modifier = Modifier,
) {
    val active = current == tab
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(if (active) SevaGreen50 else Color.Transparent)
            .clickable { onSelect(tab) }
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(modifier = Modifier.size(24.dp), contentAlignment = Alignment.Center) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = if (active) SevaGreen700 else SevaInk500,
                modifier = Modifier.size(22.dp),
            )
            if (badge != null && badge > 0) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(SevaDanger500),
                )
            }
        }
        Text(
            text = label,
            style = EsType.Caption,
            color = if (active) SevaInk900 else SevaInk500,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}
