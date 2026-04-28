package com.equipseva.app.features.hospital.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200

/**
 * Top-of-Repair-tab hero for hospitals. Three pill counts (Open / In progress
 * / Completed) drawn from the existing job lists, plus a primary "Request
 * repair" CTA so it's always one tap away (today the CTA only appears in the
 * empty state). A secondary "Browse engineers →" link nudges discovery when
 * the hospital wants to vet someone before posting.
 */
@Composable
fun HospitalRepairHeroCard(
    openCount: Int,
    inProgressCount: Int,
    completedCount: Int,
    onRequestRepair: () -> Unit,
    onBrowseEngineers: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(18.dp))
            .background(Brush.verticalGradient(listOf(BrandGreen, BrandGreenDeep)))
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(AccentLimeSoft),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Build, contentDescription = null, tint = BrandGreenDeep, modifier = Modifier.size(20.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text("Repair workspace", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text(
                    "Track bids, hand off jobs, manage payments.",
                    color = Color.White.copy(alpha = 0.85f),
                    fontSize = 12.sp,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            StatPill(value = openCount, label = "Open", modifier = Modifier.weight(1f))
            StatPill(value = inProgressCount, label = "Active", modifier = Modifier.weight(1f))
            StatPill(value = completedCount, label = "Done", modifier = Modifier.weight(1f))
        }
        Button(
            onClick = onRequestRepair,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = AccentLime,
                contentColor = BrandGreenDeep,
            ),
        ) {
            Text("Request repair", fontWeight = FontWeight.Bold)
        }
        TextButton(
            onClick = onBrowseEngineers,
            modifier = Modifier.align(Alignment.CenterHorizontally),
        ) {
            Icon(
                imageVector = Icons.Filled.Search,
                contentDescription = null,
                tint = AccentLime,
                modifier = Modifier.size(14.dp),
            )
            Spacer(Modifier.width(4.dp))
            Text("Browse engineers", color = AccentLime, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = AccentLime,
                modifier = Modifier.size(14.dp),
            )
        }
    }
}

@Composable
private fun StatPill(value: Int, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.13f))
            .padding(vertical = 10.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(value.toString(), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text(label.uppercase(), color = Color.White.copy(alpha = 0.85f), fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
    }
}

/**
 * Three-step "How it works" strip rendered alongside the empty-state CTA. Keeps
 * the screen non-blank for first-time hospitals and makes the next-step
 * obvious without forcing them to read a paragraph.
 */
@Composable
fun HospitalHowItWorksStrip(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        StepTile(number = 1, title = "Post", subtitle = "Describe the issue + add photos.", modifier = Modifier.weight(1f))
        StepTile(number = 2, title = "Compare", subtitle = "Verified engineers send bids.", modifier = Modifier.weight(1f))
        StepTile(number = 3, title = "Track", subtitle = "Chat, get proof, then rate.", modifier = Modifier.weight(1f))
    }
}

@Composable
private fun StepTile(number: Int, title: String, subtitle: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(12.dp))
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape)
                .background(BrandGreen),
            contentAlignment = Alignment.Center,
        ) {
            Text(number.toString(), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
        Text(title, color = Ink900, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        Text(subtitle, color = Ink500, fontSize = 11.sp, lineHeight = 14.sp)
    }
}

/**
 * Optional "Browse engineers" tile for the empty-state body — second-best
 * action when the hospital hasn't posted yet but might want to size up the
 * supply pool first.
 */
@Composable
fun HospitalBrowseEngineersTile(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(14.dp))
            .background(AccentLimeSoft)
            .clickable(onClick = onClick)
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(BrandGreen),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Engineering, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text("Browse verified engineers", color = Ink900, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text("See who's nearby before you post.", color = Ink700, fontSize = 12.sp)
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(18.dp),
        )
    }
}

@Composable
fun HeroCardSpacer(height: Int = 4) {
    Spacer(Modifier.height(height.dp))
}
