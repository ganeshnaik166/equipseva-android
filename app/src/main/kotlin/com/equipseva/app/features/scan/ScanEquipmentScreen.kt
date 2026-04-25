package com.equipseva.app.features.scan

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing

/**
 * Capture a photo for the user's reference and let them type the brand/model
 * to search the parts marketplace. The Vision Edge Function isn't live yet —
 * we ask rather than fabricate identifications.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanEquipmentScreen(
    onBack: () -> Unit,
    onFindParts: () -> Unit = {},
    viewModel: ScanEquipmentViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview(),
        onResult = viewModel::onCaptured,
    )

    Scaffold(
        topBar = { ESBackTopBar(title = "Scan equipment", onBack = onBack) },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .verticalScroll(rememberScrollState())
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            if (state.captured) {
                EntryCard(
                    thumbnail = state.thumbnail,
                    entry = state.entry,
                    onBrandChange = viewModel::onBrandChange,
                    onModelChange = viewModel::onModelChange,
                )
                PrimaryButton(
                    label = "Find matching parts",
                    onClick = onFindParts,
                    enabled = state.entry.canSearch,
                )
                OutlinedButton(
                    onClick = {
                        viewModel.onRetake()
                        launcher.launch(null)
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Retake photo")
                }
                Box(modifier = Modifier.height(Spacing.md))
            } else {
                CapturePrompt(onCapture = { launcher.launch(null) })
            }
        }
    }
}

@Composable
private fun CapturePrompt(onCapture: () -> Unit) {
    EmptyStateView(
        icon = Icons.Outlined.DocumentScanner,
        title = "Find spare parts by photo",
        subtitle = "Snap a picture of the nameplate or model sticker. " +
            "Then type the brand and model so we can show matching parts.",
    )
    PrimaryButton(
        label = "Capture photo",
        onClick = onCapture,
    )
}

@Composable
private fun EntryCard(
    thumbnail: android.graphics.Bitmap?,
    entry: ScanEquipmentViewModel.ManualEntry,
    onBrandChange: (String) -> Unit,
    onModelChange: (String) -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            thumbnail?.let {
                Image(
                    bitmap = it.asImageBitmap(),
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop,
                )
            }
            SectionHeader(title = "Equipment details")
            Text(
                text = "Read the brand and model off the nameplate, then type them in.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedTextField(
                value = entry.brand,
                onValueChange = onBrandChange,
                label = { Text("Brand") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = entry.model,
                onValueChange = onModelChange,
                label = { Text("Model") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                text = "Tip: confidence is highest when you fill in both fields.",
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Normal,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
