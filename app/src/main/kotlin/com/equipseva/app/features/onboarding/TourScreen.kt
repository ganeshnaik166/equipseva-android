package com.equipseva.app.features.onboarding

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.EsFontFamily
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen900
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

private data class TourPage(
    val icon: ImageVector,
    val title: String,
    val body: String,
)

private val pages = listOf(
    TourPage(
        icon = Icons.Filled.Build,
        title = "Verified engineers, nearby",
        body = "Every engineer on EquipSeva is KYC-verified. See ratings, brands they service, and base location.",
    ),
    TourPage(
        icon = Icons.Filled.Bolt,
        title = "Post a job, get bids in minutes",
        body = "Describe the issue, attach photos, set urgency. Engineers in your radius bid. You pick.",
    ),
    TourPage(
        icon = Icons.Filled.Shield,
        title = "Job-by-job trust",
        body = "Live status, on-site check-in, before/after photos, ratings on both sides.",
    ),
)

@HiltViewModel
class TourViewModel @Inject constructor(
    private val userPrefs: UserPrefs,
) : ViewModel() {
    fun markSeen() {
        viewModelScope.launch { userPrefs.setTourSeen() }
    }
}

@Composable
fun TourScreen(
    onFinish: () -> Unit,
    viewModel: TourViewModel = hiltViewModel(),
) {
    var step by remember { mutableIntStateOf(0) }
    val finish: () -> Unit = {
        viewModel.markSeen()
        onFinish()
    }
    val s = pages[step]
    Surface(modifier = Modifier.fillMaxSize(), color = SevaGreen900) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars)
                .padding(24.dp),
        ) {
            // Skip
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                Text(
                    text = "Skip",
                    fontFamily = EsFontFamily,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.7f),
                    modifier = Modifier.clickable(onClick = finish),
                )
            }
            // Hero
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 12.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .clip(RoundedCornerShape(22.dp))
                        .background(SevaGlowRaw.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = s.icon,
                        contentDescription = null,
                        tint = SevaGlowRaw,
                        modifier = Modifier.size(40.dp),
                    )
                }
                Spacer(Modifier.height(28.dp))
                Text(
                    text = s.title,
                    fontFamily = EsFontFamily,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    lineHeight = 32.sp,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(12.dp))
                Text(
                    text = s.body,
                    fontFamily = EsFontFamily,
                    fontSize = 15.sp,
                    color = Color.White.copy(alpha = 0.75f),
                    lineHeight = 22.sp,
                    textAlign = TextAlign.Center,
                )
            }
            // Dots
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.Center,
            ) {
                pages.forEachIndexed { i, _ ->
                    val w by animateDpAsState(if (i == step) 24.dp else 8.dp, label = "dot")
                    val color = if (i == step) SevaGlowRaw else Color.White.copy(alpha = 0.3f)
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 3.dp)
                            .height(8.dp)
                            .width(w)
                            .clip(RoundedCornerShape(4.dp))
                            .background(color),
                    )
                }
            }
            EsBtn(
                text = if (step < pages.lastIndex) "Next" else "Get started",
                onClick = {
                    if (step < pages.lastIndex) step += 1 else finish()
                },
                kind = EsBtnKind.Lime,
                size = EsBtnSize.Lg,
                full = true,
            )
        }
    }
}

