package com.equipseva.app.features.repair.detail.sheets

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.equipseva.app.R
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.RepairJobDetailViewModel
import com.equipseva.app.features.repair.UriListSaver
import kotlinx.coroutines.launch

// Engineer "mark done" bottom sheet: pick up to four after-photos and hand
// them to the ViewModel as completion proof. Split out of the repair detail
// screen, which had grown into a single multi-thousand-line file, so each
// sheet can be reworked on its own.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CompletionProofSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (List<RepairJobDetailViewModel.CompletionProofPhoto>) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var picked by rememberSaveable(stateSaver = UriListSaver) { mutableStateOf(emptyList<Uri>()) }
    // Same window as the check-in sheet: the submit flag is set inside the
    // viewmodel, which the photo read has to finish before it can reach.
    var reading by remember { mutableStateOf(false) }
    val maxPhotos = 4

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = maxPhotos),
    ) { uris ->
        if (uris.isNotEmpty()) {
            picked = (picked + uris).distinct().take(maxPhotos)
        }
    }

    ModalBottomSheet(
        onDismissRequest = { if (!submitting) onDismiss() },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.repair_markdone_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            // Helper text — engineers were uploading random shots and
            // dragging support questions about "did it submit?". State
            // the count cap + the why (hospital NABH/JCI compliance
            // archives consume these images) so the bar is clear before
            // the picker opens.
            Text(
                text = stringResource(R.string.repair_markdone_body, maxPhotos),
                fontSize = 12.sp,
                color = SevaInk600,
            )
            Text(
                text = stringResource(R.string.repair_markdone_photos_label),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk700,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                repeat(maxPhotos) { i ->
                    val hasPhoto = i < picked.size
                    val uri = picked.getOrNull(i)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (hasPhoto) Paper2 else Color.White)
                            .border(
                                width = 1.5.dp,
                                color = if (hasPhoto) SevaGreen700 else BorderDefault,
                                shape = RoundedCornerShape(10.dp),
                            )
                            .clickable(enabled = !submitting && !hasPhoto) {
                                launcher.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                                )
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (hasPhoto && uri != null) {
                            AsyncImage(
                                model = uri,
                                contentDescription = null,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .clip(RoundedCornerShape(10.dp)),
                                contentScale = ContentScale.Crop,
                            )
                            // Round 461: 48dp touch min (same fix as
                            // the update-status grid above).
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(48.dp)
                                    .clickable(
                                        enabled = !submitting,
                                        onClickLabel = "Remove photo",
                                        role = androidx.compose.ui.semantics.Role.Button,
                                        onClick = { picked = picked - uri },
                                    ),
                                contentAlignment = Alignment.TopEnd,
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(22.dp)
                                        .padding(2.dp)
                                        .background(Color.Black.copy(alpha = 0.55f), CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Icon(
                                        Icons.Filled.Close,
                                        contentDescription = null,
                                        tint = Color.White,
                                        modifier = Modifier.size(12.dp),
                                    )
                                }
                            }
                        } else if (i == picked.size) {
                            Icon(
                                imageVector = Icons.Filled.AddPhotoAlternate,
                                contentDescription = "Add photo",
                                tint = SevaGreen700,
                                modifier = Modifier.size(20.dp),
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Outlined.PhotoCamera,
                                contentDescription = null,
                                tint = SevaInk400,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                }
            }
            // "Work summary" multiline field used to live here, but the
            // sheet's onSubmit + submitCompletionProof both took only
            // photos — the typed text was discarded. Removed until a
            // real work_summary column ships and submitCompletionProof
            // can carry it through.
            EsBtn(
                text = if (submitting) "Saving…" else "Mark done",
                onClick = {
                    // Round 340 — read uris on IO. Compose onClick runs on
                    // Main; up to 4 multi-MB picked photos blocking Main
                    // would trip ANR.
                    reading = true
                    scope.launch(kotlinx.coroutines.Dispatchers.IO) {
                        try {
                            val resolver = context.contentResolver
                            val photos = picked.mapNotNull { uri ->
                                val mime = resolver.getType(uri) ?: MIME_JPEG
                                val name = uri.lastPathSegment ?: "after-${System.currentTimeMillis()}.jpg"
                                val bytes = runCatching {
                                    resolver.openInputStream(uri)?.use { it.readBytes() }
                                }.getOrNull() ?: return@mapNotNull null
                                RepairJobDetailViewModel.CompletionProofPhoto(
                                    fileName = name,
                                    mimeType = mime,
                                    bytes = bytes,
                                )
                            }
                            onSubmit(photos)
                        } finally {
                            reading = false
                        }
                    }
                },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = picked.isEmpty() || submitting || reading,
            )
            EsBtn(
                text = stringResource(R.string.common_cancel),
                onClick = onDismiss,
                kind = EsBtnKind.Ghost,
                full = true,
                disabled = submitting,
            )
        }
    }
}
