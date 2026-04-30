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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500

/**
 * Per-role bottom-nav item — drives both the tab visual and the
 * route-comparison logic in callers.
 *
 * Hospital ships 3 tabs (Home / Bookings / Profile); engineer ships
 * 4 (Home / Jobs / Earnings / Profile). Caller picks which list to
 * pass.
 */
data class EsBottomNavItem(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val badge: Int? = null,
)

/**
 * Data-driven bottom-nav matching `shared.jsx:BottomNav`. Active tab
 * gets a green-50 pill behind the icon (with active green-700 tint
 * and SemiBold label); inactive uses ink-500. Optional red dot/count
 * badge sits at the icon's top-right.
 */
@Composable
fun EsBottomNav(
    tabs: List<EsBottomNavItem>,
    currentRoute: String?,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(72.dp)
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(horizontal = 4.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        tabs.forEach { tab ->
            val active = currentRoute == tab.route
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onSelect(tab.route) }
                    .padding(vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (active) SevaGreen50 else Color.Transparent)
                        .padding(horizontal = 18.dp, vertical = 4.dp),
                ) {
                    Box(modifier = Modifier.size(22.dp)) {
                        Icon(
                            imageVector = tab.icon,
                            contentDescription = tab.label,
                            tint = if (active) SevaGreen700 else SevaInk500,
                            modifier = Modifier.size(22.dp),
                        )
                        if (tab.badge != null && tab.badge > 0) {
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(16.dp)
                                    .clip(CircleShape)
                                    .background(SevaDanger500),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = tab.badge.toString(),
                                    color = Color.White,
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                        }
                    }
                }
                Text(
                    text = tab.label,
                    fontSize = 11.sp,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium,
                    color = if (active) SevaGreen700 else SevaInk500,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}
