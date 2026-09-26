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
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.RepairJobDetailViewModel
import com.equipseva.app.features.repair.UriListSaver
import kotlinx.coroutines.launch

// Engineer check-in bottom sheet (before-photos required) for the repair
// job detail screen. Split out of the 3,551-line RepairJobDetailScreen
// monolith so each sheet lives in its own file and hierarchy work can
// happen per section without touching the whole screen.

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CheckinSheet(
    updating: Boolean,
    onDismiss: () -> Unit,
    onConfirm: (List<RepairJobDetailViewModel.CompletionProofPhoto>) -> Unit,
) {
    // PR-D10 (T2.9): before-photos required at check-in. Mirrors the
    // CompletionProofSheet photo-grid pattern. 1+ photo is the minimum
    // strategy memo enforces ("photo of equipment before any work");
    // we cap at 4 to keep the upload payload sane on bad reception.
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var picked by rememberSaveable(stateSaver = UriListSaver) { mutableStateOf(emptyList<Uri>()) }
    // Reading up to four multi-megabyte photos off the content resolver
    // takes long enough for a second tap to land, and the viewmodel's
    // in-flight flag cannot help yet — it hasn't been called. Without this
    // the before-photo set was stashed and uploaded twice.
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
        onDismissRequest = { if (!updating) onDismiss() },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.repair_checkin_title),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                text = stringResource(R.string.repair_checkin_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
            Text(
                text = stringResource(R.string.repair_checkin_photos_label),
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
                            .clickable(enabled = !updating && !hasPhoto) {
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
                            // Round 461: 48dp hit area (Material/WCAG
                            // touch min); visible chip stays 22dp via
                            // the inner Box. Was a fat-finger nightmare.
                            Box(
                                modifier = Modifier
                                    .align(Alignment.TopEnd)
                                    .size(48.dp)
                                    .clickable(
                                        enabled = !updating,
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
            EsBtn(
                text = if (updating) "Checking in…" else "I'm here · check in",
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
                                val name = uri.lastPathSegment ?: "before-${System.currentTimeMillis()}.jpg"
                                val bytes = runCatching {
                                    resolver.openInputStream(uri)?.use { it.readBytes() }
                                }.getOrNull() ?: return@mapNotNull null
                                RepairJobDetailViewModel.CompletionProofPhoto(
                                    fileName = name,
                                    mimeType = mime,
                                    bytes = bytes,
                                )
                            }
                            onConfirm(photos)
                        } finally {
                            reading = false
                        }
                    }
                },
                kind = EsBtnKind.Primary,
                full = true,
                size = EsBtnSize.Lg,
                disabled = picked.isEmpty() || updating || reading,
            )
            EsBtn(
                text = stringResource(R.string.common_cancel),
                onClick = onDismiss,
                kind = EsBtnKind.Ghost,
                full = true,
                disabled = updating,
            )
        }
    }
}
