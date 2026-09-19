package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow

import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EquipSevaTheme
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
            // Minimum, not fixed: icon pill + label already fill 72 dp at the
            // default font scale, so a hard height clipped the labels of every
            // tab as soon as the user raised the system font size.
            .heightIn(min = 72.dp)
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(horizontal = 4.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        tabs.forEach { tab ->
            val active = currentRoute == tab.route
            val unread = tab.badge ?: 0
            // Only the badge carries information the merged label does not,
            // so it is the only case that needs an explicit name.
            val unreadName = if (unread > 0) {
                stringResource(R.string.bottom_nav_unread_cd, tab.label, unread)
            } else {
                null
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    // Role.Tab + selected semantics so TalkBack
                    // announces e.g. "Home, tab, selected" or
                    // "Jobs, tab, not selected, double-tap to
                    // activate". Without these, the bottom nav read
                    // as a row of generic buttons and users couldn't
                    // tell which destination was currently open. Bottom
                    // nav is the primary cross-feature navigation so
                    // this is the highest-traffic a11y target in the
                    // app.
                    .semantics {
                        selected = active
                        // Surface the unread count to TalkBack so a user
                        // hearing "Notifications, tab, 3 unread, selected"
                        // gets the same signal as a sighted user reading
                        // the red badge over the icon. With no badge the
                        // merged label Text is the name — setting one here
                        // as well made TalkBack repeat it.
                        if (unreadName != null) contentDescription = unreadName
                    }
                    .clickable(role = Role.Tab) { onSelect(tab.route) }
                    .padding(vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (active) SevaGreen50 else Color.Transparent)
                        // Leave room for the growing badge within its own tab,
                        // including the four-tab layout at large font scales.
                        .padding(horizontal = if (unread > 0) 4.dp else 18.dp, vertical = 4.dp),
                ) {
                    // The badge must participate in measurement. A fixed icon
                    // box also capped the badge text at 22 dp, even with a
                    // required minimum size on the badge itself.
                    Box {
                        Icon(
                            imageVector = tab.icon,
                            // The tab already has an accessible name (the
                            // label Text, or the unread description above);
                            // naming the icon too read the tab out twice.
                            contentDescription = null,
                            tint = if (active) SevaGreen700 else SevaInk500,
                            modifier = Modifier.size(22.dp).align(Alignment.BottomStart),
                        )
                        if (unread > 0) {
                            // Bumped from 16dp / 9sp to 18dp / 11sp so the
                            // unread count is readable for older users +
                            // matches Material's recommended badge minimum
                            // (~16-20dp). Below ~10dp height the digit
                            // becomes pixel-noise on dense Vivo / Realme
                            // displays.
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    // Reserve the icon's lower-left corner so
                                    // a wider/taller count grows the entire pill
                                    // rather than painting beyond its clipping
                                    // bounds or covering the whole icon.
                                    .padding(start = 11.dp, bottom = 11.dp)
                                    .sizeIn(minWidth = 18.dp, minHeight = 18.dp)
                                    .clip(RoundedCornerShape(999.dp))
                                    .background(SevaDanger500)
                                    .padding(horizontal = 3.dp),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = bottomNavBadgeLabel(unread),
                                    color = Color.White,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    maxLines = 1,
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
                    // A wrapped label pushed the second line under the bar's
                    // bottom edge; ellipsis keeps the tab readable instead.
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

/**
 * Unread-count text inside the bottom-nav badge.
 *
 * Caps at "99+" to keep the growing pill within its tab. The exact count
 * remains available in the tab's accessible description and in the inbox.
 */
internal fun bottomNavBadgeLabel(count: Int): String =
    if (count > 99) "99+" else count.toString()

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun EsBottomNavGallery() {
    val hospitalTabs = listOf(
        EsBottomNavItem(route = "home", label = "Home", icon = Icons.Outlined.Home),
        EsBottomNavItem(route = "bookings", label = "Bookings", icon = Icons.Outlined.WorkOutline),
        EsBottomNavItem(route = "profile", label = "Profile", icon = Icons.Outlined.Person),
    )
    val engineerTabs = listOf(
        EsBottomNavItem(route = "home", label = "Home", icon = Icons.Outlined.Home),
        EsBottomNavItem(route = "jobs", label = "Jobs", icon = Icons.Outlined.Build, badge = 3),
        EsBottomNavItem(route = "earnings", label = "Earnings", icon = Icons.Outlined.CurrencyRupee, badge = 0),
        EsBottomNavItem(route = "profile", label = "Profile", icon = Icons.Outlined.Person),
    )
    val hospitalWithMessagesTabs = listOf(
        EsBottomNavItem(route = "home", label = "Home", icon = Icons.Outlined.Home),
        EsBottomNavItem(route = "bookings", label = "Bookings", icon = Icons.Outlined.WorkOutline, badge = 1),
        EsBottomNavItem(route = "messages", label = "Messages", icon = Icons.AutoMirrored.Outlined.Chat, badge = 12),
        EsBottomNavItem(route = "profile", label = "Profile", icon = Icons.Outlined.Person),
    )
    val longLabelTabs = listOf(
        EsBottomNavItem(route = "home", label = "Home", icon = Icons.Outlined.Home),
        EsBottomNavItem(route = "requests", label = "Service Requests", icon = Icons.Outlined.Build),
        EsBottomNavItem(route = "payments", label = "Payment History", icon = Icons.Outlined.CurrencyRupee),
        EsBottomNavItem(route = "profile", label = "Hospital Profile", icon = Icons.Outlined.Person),
    )
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "Hospital · 3 tabs · Home active", fontSize = 11.sp, color = SevaInk500)
        EsBottomNav(tabs = hospitalTabs, currentRoute = "home", onSelect = {})
        Text(text = "Engineer · 4 tabs · badge 3 on active, badge 0 hidden", fontSize = 11.sp, color = SevaInk500)
        EsBottomNav(tabs = engineerTabs, currentRoute = "jobs", onSelect = {})
        Text(text = "Badges 1 and 12 on inactive tabs", fontSize = 11.sp, color = SevaInk500)
        EsBottomNav(tabs = hospitalWithMessagesTabs, currentRoute = "home", onSelect = {})
        Text(text = "No active tab (currentRoute = null)", fontSize = 11.sp, color = SevaInk500)
        EsBottomNav(tabs = engineerTabs, currentRoute = null, onSelect = {})
        Text(text = "Long labels", fontSize = 11.sp, color = SevaInk500)
        EsBottomNav(tabs = longLabelTabs, currentRoute = "payments", onSelect = {})
    }
}

@Preview(name = "EsBottomNav", showBackground = true)
@Composable
private fun EsBottomNavPreview() {
    EquipSevaTheme(darkTheme = false) { EsBottomNavGallery() }
}

@Preview(name = "EsBottomNav large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun EsBottomNavPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { EsBottomNavGallery() }
}
