package com.equipseva.app.features.repair.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

/**
 * Replaces the "Call (raw phone) / WhatsApp (raw phone)" pair on
 * EngineerPublicProfile with a privacy-first equivalent. Both CTAs
 * stay in-app: tap "Call" → server-side bridge dials both legs from
 * EquipSeva's ExoPhone (neither party sees the other's MSISDN), tap
 * "Open chat" → existing in-app chat. The privacy footer is the
 * single most-effective trust signal — keep the copy.
 */
@Composable
fun MaskedContactPanel(
    onCall: () -> Unit,
    onOpenChat: () -> Unit,
    callEnabled: Boolean,
    chatEnabled: Boolean,
    callBusy: Boolean,
    chatBusy: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = "Contact engineer",
            fontSize = 13.sp,
            color = SevaInk900,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(modifier = Modifier.weight(1f)) {
                EsBtn(
                    text = if (callBusy) "Calling…" else "Call",
                    onClick = onCall,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = !callEnabled || callBusy,
                    leading = {
                        Icon(
                            imageVector = Icons.Outlined.Phone,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                )
            }
            Box(modifier = Modifier.weight(1f)) {
                EsBtn(
                    text = if (chatBusy) "Opening…" else "Open chat",
                    onClick = onOpenChat,
                    kind = EsBtnKind.Secondary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = !chatEnabled || chatBusy,
                    leading = {
                        Icon(
                            imageVector = Icons.AutoMirrored.Outlined.Chat,
                            contentDescription = null,
                            tint = SevaInk700,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SevaInfo50)
                .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                .padding(12.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Security,
                    contentDescription = null,
                    tint = SevaInfo500,
                    modifier = Modifier
                        .padding(top = 1.dp)
                        .size(16.dp),
                )
                Text(
                    text = "Calls route through EquipSeva's secure line. Your real number — and the engineer's — stay private.",
                    color = SevaInfo500,
                    fontSize = 12.sp,
                    lineHeight = 17.sp,
                )
            }
        }
    }
}

@Composable
fun MaskedContactPanelComingSoon(
    onOpenChat: () -> Unit,
    chatEnabled: Boolean,
    chatBusy: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(text = "Contact engineer", fontSize = 13.sp, color = SevaInk900)
        Box(modifier = Modifier.fillMaxWidth()) {
            EsBtn(
                text = if (chatBusy) "Opening…" else "Open chat",
                onClick = onOpenChat,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = !chatEnabled || chatBusy,
            )
        }
        Text(
            text = "In-app calls coming soon — chat for now to keep your details private.",
            color = SevaInk500,
            fontSize = 12.sp,
        )
    }
}
