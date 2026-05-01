package com.equipseva.app.features.about

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import com.equipseva.app.BuildConfig
import com.equipseva.app.R
import com.equipseva.app.designsystem.components.EsListRow
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import android.content.Intent

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(
    onBack: () -> Unit,
) {
    val ctx = LocalContext.current
    val open: (String) -> Unit = { url ->
        runCatching {
            ctx.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "About", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                // Logo + version block — 40/24 padding, centered.
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 40.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.ic_logo_mark),
                        contentDescription = null,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(16.dp)),
                    )
                    Spacer(Modifier.height(16.dp))
                    Text(
                        text = "EquipSeva",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = SevaInk900,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Version ${BuildConfig.VERSION_NAME} (build ${BuildConfig.VERSION_CODE})",
                        fontSize = 12.sp,
                        color = SevaInk500,
                    )
                }

                // Links card — Privacy / Terms / Licenses.
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White)
                            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
                    ) {
                        EsListRow(
                            title = "Privacy policy",
                            leading = {
                                Icon(
                                    Icons.Outlined.Description,
                                    contentDescription = null,
                                    tint = SevaInk600,
                                    modifier = Modifier.size(18.dp),
                                )
                            },
                            trailing = {
                                Icon(
                                    Icons.AutoMirrored.Outlined.OpenInNew,
                                    contentDescription = null,
                                    tint = SevaInk400,
                                    modifier = Modifier.size(16.dp),
                                )
                            },
                            onClick = { open("https://equipseva.com/privacy") },
                        )
                        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
                        EsListRow(
                            title = "Terms of service",
                            leading = {
                                Icon(
                                    Icons.Outlined.Description,
                                    contentDescription = null,
                                    tint = SevaInk600,
                                    modifier = Modifier.size(18.dp),
                                )
                            },
                            trailing = {
                                Icon(
                                    Icons.AutoMirrored.Outlined.OpenInNew,
                                    contentDescription = null,
                                    tint = SevaInk400,
                                    modifier = Modifier.size(16.dp),
                                )
                            },
                            onClick = { open("https://equipseva.com/terms") },
                        )
                        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
                        EsListRow(
                            title = "Open-source licenses",
                            leading = {
                                Icon(
                                    Icons.Outlined.Description,
                                    contentDescription = null,
                                    tint = SevaInk600,
                                    modifier = Modifier.size(18.dp),
                                )
                            },
                            trailing = {
                                Icon(
                                    Icons.Outlined.ChevronRight,
                                    contentDescription = null,
                                    tint = SevaInk400,
                                    modifier = Modifier.size(16.dp),
                                )
                            },
                            onClick = { open("https://equipseva.com/licenses") },
                        )
                    }
                }

                Spacer(Modifier.height(24.dp))
                Text(
                    text = "© ${java.time.Year.now().value} EquipSeva",
                    fontSize = 12.sp,
                    color = SevaInk500,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}
