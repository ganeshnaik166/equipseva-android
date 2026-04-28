package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import kotlin.math.absoluteValue

private val TIPS = listOf(
    "Bid within an hour to win 2× more often.",
    "Add a short note explaining your diagnosis — hospitals trust specifics.",
    "Check the map before bidding so you can plan your day.",
    "Mark Done with photos — verified work brings repeat hospitals.",
)

/**
 * Rotating engineer-side tip card. Picks one tip per app session (stable
 * across recompose via [rememberSaveable]) and lets the user dismiss it for
 * the rest of the session — `dismissedKey` flips to true and the composable
 * returns nothing on subsequent recomposes.
 *
 * Kept in-memory only to avoid the engineer never seeing tips again after
 * dismissing once; if you need a permanent dismiss, swap to DataStore.
 */
@Composable
fun EngineerTipCard(modifier: Modifier = Modifier) {
    var dismissed by rememberSaveable { mutableStateOf(false) }
    if (dismissed) return
    val tip = remember {
        // Pick a stable tip for the session; nothing fancy, just rotate by
        // millis-of-day so two engineers using the app today see different
        // tips without persisting state.
        TIPS[(System.currentTimeMillis() / 60_000).toInt().absoluteValue % TIPS.size]
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(12.dp))
            .padding(start = 12.dp, end = 4.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(AccentLimeSoft),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Lightbulb, contentDescription = null, tint = BrandGreenDeep, modifier = Modifier.size(16.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text("TIP", color = Ink500, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            Text(tip, color = Ink900, fontSize = 13.sp, lineHeight = 16.sp)
        }
        IconButton(onClick = { dismissed = true }) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "Dismiss tip",
                tint = Ink500,
                modifier = Modifier.size(16.dp),
            )
        }
    }
}
