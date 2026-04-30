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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ESTopBar(title: String) {
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
        colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
    )
}

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
    title: String? = null,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    right: (@Composable () -> Unit)? = null,
    transparent: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val bg = if (transparent) Color.Transparent else PaperDefault
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(bg)
            .let { if (!transparent) it.border(width = 1.dp, color = BorderDefault, shape = RectangleShape) else it }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            Box(
                modifier = Modifier.size(36.dp).clickable(onClick = onBack),
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
