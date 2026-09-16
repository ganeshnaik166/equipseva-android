package com.equipseva.app.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ESBackTopBar(
    title: String,
    onBack: () -> Unit,
    backEnabled: Boolean = true,
    actions: @Composable RowScope.() -> Unit = {},
) {
    CenterAlignedTopAppBar(
        title = {
            Text(
                text = title,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
                modifier = Modifier.semantics { heading() },
            )
        },
        navigationIcon = {
            IconButton(onClick = onBack, enabled = backEnabled) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = Ink900,
                )
            }
        },
        actions = actions,
        colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
    )
}

// Round-A redesign top bar matching `shared.jsx:TopBar`. 52dp tall,
// title 16sp/700 left-aligned (no left placeholder when no back),
// optional back arrow (36dp), optional right-slot composable.
@Composable
fun EsTopBar(
    modifier: Modifier = Modifier,
    title: String? = null,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    right: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(PaperDefault)
            .border(width = 1.dp, color = BorderDefault, shape = RectangleShape)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            // Round 455 — 48 dp touch target per Material a11y. Icon still
            // renders at 20 dp; only the clickable Box grows so the back
            // button is hittable for users with motor impairments or
            // larger fingers. ESTopBar is the global top bar so this
            // ripples to every screen with a back arrow.
            Box(
                modifier = Modifier
                    .size(48.dp)
                    // Role.Button so TalkBack announces "Back, button"
                    // instead of the generic clickable variant. The
                    // back affordance is the most-used a11y target in
                    // the app (every detail / settings screen has it).
                    .clickable(onClick = onBack, role = Role.Button),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = SevaInk900,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = if (onBack != null) 4.dp else 0.dp),
            verticalArrangement = Arrangement.Center,
        ) {
            if (title != null) {
                Text(
                    text = title,
                    // Round 461: heading semantics so TalkBack rotor can
                    // jump screen-to-screen by header. EsTopBar is used
                    // by ~57 screens; without this every screen title
                    // was reading as plain text. ESBackTopBar already
                    // marked its title; this brings the no-back variant
                    // into line.
                    modifier = Modifier.semantics { heading() },
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.16).sp,
                    color = SevaInk900,
                )
            }
            if (subtitle != null) Text(text = subtitle, style = EsType.Caption, color = SevaInk500)
        }
        if (right != null) right()
    }
}

// ---- Previews — design-system gallery. Every @Preview under designsystem/
// is also a Roborazzi screenshot test (see app/build.gradle.kts), so a
// variant that is missing here has no visual regression guard.

@Composable
private fun ESTopBarGallery() {
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = "ESBackTopBar", style = EsType.Caption, color = SevaInk500)
        ESBackTopBar(title = "Job details", onBack = {})
        ESBackTopBar(title = "Job details", onBack = {}, backEnabled = false)
        ESBackTopBar(
            title = "Ventilator service",
            onBack = {},
            actions = {
                IconButton(onClick = {}) {
                    Icon(Icons.Filled.Search, contentDescription = "Search", tint = Ink900)
                }
                IconButton(onClick = {}) {
                    Icon(Icons.Filled.MoreVert, contentDescription = "More", tint = Ink900)
                }
            },
        )
        ESBackTopBar(title = "", onBack = {})
        ESBackTopBar(
            title = "Repair request for GE Voluson E10 ultrasound at Apollo Hospitals, Jubilee Hills",
            onBack = {},
        )

        Text(text = "EsTopBar", style = EsType.Caption, color = SevaInk500)
        EsTopBar()
        EsTopBar(title = "My jobs")
        EsTopBar(title = "My jobs", subtitle = "3 open · 12 completed")
        EsTopBar(title = "Bid details", onBack = {})
        EsTopBar(title = "Bid details", subtitle = "₹4,500 · Ramesh Kumar", onBack = {})
        EsTopBar(
            title = "Notifications",
            right = {
                IconButton(onClick = {}) {
                    Icon(Icons.Filled.MoreVert, contentDescription = "More", tint = SevaInk900)
                }
            },
        )
        EsTopBar(
            title = "Fortis Hospital, Mulund",
            subtitle = "Philips IntelliVue MX450",
            onBack = {},
            right = { Text(text = "Skip", style = EsType.Caption, color = SevaInk500) },
        )
        EsTopBar(subtitle = "Last synced 2 min ago")
        EsTopBar(title = "", onBack = {})
        EsTopBar(
            title = "Preventive maintenance for Siemens Somatom CT scanner at Manipal Hospital, Whitefield",
            subtitle = "Scheduled for Thursday · Engineer Priya Nair · ₹12,000 quoted",
            onBack = {},
        )
    }
}

@Preview(name = "ESTopBar", showBackground = true)
@Composable
private fun ESTopBarPreview() {
    EquipSevaTheme(darkTheme = false) { ESTopBarGallery() }
}

@Preview(name = "ESTopBar large text", showBackground = true, fontScale = 1.3f)
@Composable
private fun ESTopBarPreviewLargeText() {
    EquipSevaTheme(darkTheme = false) { ESTopBarGallery() }
}
