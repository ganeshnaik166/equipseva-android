package com.equipseva.app.designsystem.components

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.HelpOutline
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.ReportProblem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

internal const val SUPPORT_EMAIL = "support@equipseva.com"
internal const val REFUND_POLICY_URL = "https://equipseva.com/refunds"
internal const val FAQ_URL = "https://equipseva.com/faq"

/**
 * FIX #10: Help & Support escalation bottom-sheet. Renders 5 actions:
 *  1. Contact us         → mailto:support@equipseva.com
 *  2. Report engineer    → free-text → mailto with subject prefix
 *  3. Report job issue   → free-text → mailto with subject prefix
 *  4. Refund policy      → https://equipseva.com/refunds
 *  5. FAQ                → https://equipseva.com/faq
 *
 * All side-effects (Intent dispatch + ActivityNotFound fallback)
 * are handled internally so call-sites stay one line:
 *
 *    if (helpOpen) HelpSupportSheet(onClose = { helpOpen = false }, onShowMessage = ...)
 *
 * The hospital escalation use-case (engineer no-show, negligent
 * repair) is the primary motivator — without a visible in-app path
 * users escalate to WhatsApp / legal, off-platform.
 */
@Composable
fun HelpSupportSheet(
    onClose: () -> Unit,
    onShowMessage: (String) -> Unit = {},
    repairJobNumber: String? = null,
) {
    val context = LocalContext.current
    var reportEngineerOpen by rememberSaveable { mutableStateOf(false) }
    var reportJobOpen by rememberSaveable { mutableStateOf(false) }

    EsBottomSheet(onClose = onClose, title = "Help & support") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Reach our team — we usually reply within 24h on business days.",
                fontSize = 12.sp,
                color = SevaInk500,
            )
            Spacer(Modifier.height(4.dp))
            SupportActionRow(
                icon = Icons.Outlined.Email,
                title = "Contact us",
                subtitle = SUPPORT_EMAIL,
            ) {
                launchSupportEmail(context, onShowMessage)
            }
            SupportActionRow(
                icon = Icons.Outlined.Person,
                title = "Report an engineer",
                subtitle = "No-show, asked for cash, unsafe behaviour",
            ) {
                reportEngineerOpen = true
            }
            SupportActionRow(
                icon = Icons.Outlined.ReportProblem,
                title = "Report a job issue",
                subtitle = "Wrong diagnosis, parts not replaced, billing dispute",
            ) {
                reportJobOpen = true
            }
            SupportActionRow(
                icon = Icons.Outlined.Gavel,
                title = "Refund policy",
                subtitle = "When and how we refund",
            ) {
                openUrl(context, REFUND_POLICY_URL, onShowMessage)
            }
            SupportActionRow(
                icon = Icons.AutoMirrored.Outlined.HelpOutline,
                title = "FAQ",
                subtitle = "Common questions and how the platform works",
            ) {
                openUrl(context, FAQ_URL, onShowMessage)
            }
            Spacer(Modifier.height(8.dp))
        }
    }

    if (reportEngineerOpen) {
        ReportFormSheet(
            title = "Report an engineer",
            placeholder = "Engineer name + what happened (no-show, cash demand, unsafe work, etc.)",
            subjectPrefix = "Engineer report",
            repairJobNumber = repairJobNumber,
            onClose = { reportEngineerOpen = false },
            onShowMessage = onShowMessage,
        )
    }
    if (reportJobOpen) {
        ReportFormSheet(
            title = "Report a job issue",
            placeholder = "Job number + what went wrong (wrong diagnosis, billing dispute, etc.)",
            subjectPrefix = "Job issue",
            repairJobNumber = repairJobNumber,
            onClose = { reportJobOpen = false },
            onShowMessage = onShowMessage,
        )
    }
}

@Composable
private fun ReportFormSheet(
    title: String,
    placeholder: String,
    subjectPrefix: String,
    repairJobNumber: String?,
    onClose: () -> Unit,
    onShowMessage: (String) -> Unit,
) {
    val context = LocalContext.current
    var body by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onClose, title = title) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Tell us what happened. We'll respond from $SUPPORT_EMAIL.",
                fontSize = 12.sp,
                color = SevaInk500,
            )
            OutlinedTextField(
                value = body,
                onValueChange = { if (it.length <= 1000) body = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(placeholder) },
                minLines = 4,
                maxLines = 8,
            )
            val trimmed = body.trim()
            EsBtn(
                text = "Send to support",
                onClick = {
                    val subject = if (repairJobNumber != null) {
                        "$subjectPrefix — $repairJobNumber"
                    } else {
                        subjectPrefix
                    }
                    launchSupportEmail(
                        context = context,
                        onShowMessage = onShowMessage,
                        subject = subject,
                        body = trimmed,
                    )
                    onClose()
                },
                kind = EsBtnKind.Primary,
                full = true,
                disabled = trimmed.length < 5,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun SupportActionRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(
                onClickLabel = title,
                role = Role.Button,
                onClick = onClick,
            )
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(18.dp),
            )
        }
        Column(modifier = Modifier.fillMaxWidth().padding(end = 8.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = SevaInk900)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, fontSize = 12.sp, color = SevaInk700, lineHeight = 16.sp)
        }
    }
}

/**
 * Fires a `mailto:` Intent so the user's email composer opens
 * pre-addressed to support. ACTION_SENDTO + `mailto:` URI is the
 * Android-canonical recipe — it filters the chooser to actual email
 * apps only, vs ACTION_SEND which surfaces every share target.
 *
 * Caller passes `body` only for the form-driven flows; bare "Contact
 * us" uses subject-only to let the user start fresh.
 */
internal fun launchSupportEmail(
    context: Context,
    onShowMessage: (String) -> Unit,
    subject: String = "EquipSeva support request",
    body: String = "",
) {
    val intent = Intent(Intent.ACTION_SENDTO).apply {
        data = "mailto:$SUPPORT_EMAIL".toUri()
        putExtra(Intent.EXTRA_SUBJECT, subject)
        if (body.isNotBlank()) {
            putExtra(Intent.EXTRA_TEXT, body)
        }
    }
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        onShowMessage("No email app installed. Reach us at $SUPPORT_EMAIL")
    }
}

internal fun openUrl(
    context: Context,
    url: String,
    onShowMessage: (String) -> Unit,
) {
    val intent = Intent(Intent.ACTION_VIEW, url.toUri()).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        onShowMessage("Couldn't open browser")
    }
}
