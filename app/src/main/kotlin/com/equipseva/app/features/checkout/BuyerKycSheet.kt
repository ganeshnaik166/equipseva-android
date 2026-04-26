package com.equipseva.app.features.checkout

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AttachFile
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.core.data.buyerkyc.BuyerKycRepository
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg

private val WARN_AMBER = Color(0xFFEC8E26)

/**
 * KYC gate shown on the Checkout payment step when buyerKycStatus != "verified".
 * Pending shows an "Under review" banner; rejected shows the reason and a
 * resubmit; unsubmitted shows the 6-doc grid + GST input + file picker.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BuyerKycSheet(
    status: String,
    saving: Boolean,
    error: String?,
    rejectionReason: String?,
    onDismiss: () -> Unit,
    onSubmit: (
        docType: BuyerKycRepository.DocType,
        gstNumber: String?,
        pickFile: () -> Unit,
    ) -> Unit,
    onPickedFile: ((Context, Uri, BuyerKycRepository.DocType, String?) -> Unit),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selected by remember { mutableStateOf<BuyerKycRepository.DocType?>(null) }
    var gst by remember { mutableStateOf("") }
    var agreed by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val picker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? ->
        val sel = selected ?: return@rememberLauncherForActivityResult
        if (uri != null) onPickedFile(context, uri, sel, gst.takeIf { it.isNotBlank() })
    }

    ModalBottomSheet(
        sheetState = sheetState,
        onDismissRequest = onDismiss,
        containerColor = Surface0,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            when (status) {
                "pending" -> StatusBanner(
                    title = "KYC under review",
                    subtitle = "We're verifying your document. You'll be notified within 24 hours; checkout will unlock automatically.",
                    color = Warning,
                    bg = WarningBg,
                    icon = Icons.Filled.Warning,
                )
                "verified" -> StatusBanner(
                    title = "KYC verified",
                    subtitle = "You're all set — close this sheet to continue checkout.",
                    color = BrandGreen,
                    bg = AccentLime.copy(alpha = 0.12f),
                    icon = Icons.Filled.Check,
                )
                "rejected" -> StatusBanner(
                    title = "Document rejected",
                    subtitle = rejectionReason ?: "Please re-upload a clearer copy.",
                    color = MaterialTheme.colorScheme.error,
                    bg = MaterialTheme.colorScheme.errorContainer,
                    icon = Icons.Filled.Warning,
                )
                else -> StatusBanner(
                    title = "Your KYC is incomplete",
                    subtitle = "Choose a KYC document to continue.",
                    color = Surface0,
                    bg = WARN_AMBER,
                    icon = Icons.Filled.Warning,
                )
            }

            if (status != "pending" && status != "verified") {
                Text(
                    "Upload any KYC proof",
                    color = Ink900,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                )
                val docs = BuyerKycRepository.DocType.entries
                docs.chunked(2).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        row.forEach { doc ->
                            DocCard(
                                doc = doc,
                                selected = selected == doc,
                                onClick = { selected = doc },
                                modifier = Modifier.weight(1f),
                            )
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }

                val sel = selected
                if (sel == BuyerKycRepository.DocType.Gst) {
                    OutlinedTextField(
                        value = gst,
                        onValueChange = { v -> gst = v.uppercase().filter { it.isLetterOrDigit() }.take(20) },
                        label = { Text("GST number (GSTIN)") },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !saving,
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = agreed, onCheckedChange = { agreed = it }, enabled = !saving)
                    Text(
                        "I agree to the KYC terms and conditions.",
                        fontSize = 13.sp,
                        color = Ink700,
                    )
                }

                error?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, fontSize = 12.sp)
                }

                Button(
                    onClick = {
                        val sel2 = selected ?: return@Button
                        onSubmit(sel2, gst.takeIf { it.isNotBlank() }) { picker.launch("*/*") }
                    },
                    enabled = !saving && selected != null && agreed &&
                        (selected != BuyerKycRepository.DocType.Gst || gst.length in 10..20),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Filled.AttachFile, contentDescription = null, modifier = Modifier.size(18.dp))
                    Text(
                        if (saving) "Uploading…" else "Pick file & submit",
                        modifier = Modifier.padding(start = 6.dp),
                    )
                }

                Text(
                    "Your information is 100% safe & secure with us.",
                    color = Ink500,
                    fontSize = 11.sp,
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun StatusBanner(
    title: String,
    subtitle: String,
    color: Color,
    bg: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(Surface0.copy(alpha = 0.25f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = color)
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = color, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(subtitle, color = color.copy(alpha = 0.85f), fontSize = 12.sp)
        }
    }
}

@Composable
private fun DocCard(
    doc: BuyerKycRepository.DocType,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = if (selected) BrandGreen else Surface200
    val tickColor = if (selected) BrandGreen else Ink500
    Column(
        modifier = modifier
            .height(96.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) AccentLime.copy(alpha = 0.08f) else Surface50)
            .border(if (selected) 2.dp else 1.dp, borderColor, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(18.dp)
                    .clip(CircleShape)
                    .border(2.dp, tickColor, CircleShape)
                    .background(if (selected) BrandGreen else Color.Transparent),
                contentAlignment = Alignment.Center,
            ) {
                if (selected) Icon(Icons.Filled.Check, contentDescription = null, tint = Surface0, modifier = Modifier.size(12.dp))
            }
            Spacer(Modifier.size(8.dp))
            Text(
                doc.display,
                color = Ink900,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp,
            )
        }
        Text(doc.subtitle, color = Ink500, fontSize = 10.sp, lineHeight = 12.sp)
    }
}
