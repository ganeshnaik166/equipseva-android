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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
            when {
                state.result != null -> ResultCard(
                    thumbnail = state.thumbnail,
                    result = state.result!!,
                    onFindParts = onFindParts,
                    onRetake = {
                        viewModel.onRetake()
                        launcher.launch(null)
                    },
                )

                state.scanning -> ScanningCard(thumbnail = state.thumbnail)

                else -> CapturePrompt(onCapture = { launcher.launch(null) })
            }
        }
    }
}

@Composable
private fun CapturePrompt(onCapture: () -> Unit) {
    EmptyStateView(
        icon = Icons.Outlined.DocumentScanner,
        title = "Identify equipment with AI",
        subtitle = "Point your camera at the nameplate or model sticker. We'll suggest " +
            "matching brand, model, and spare parts.",
    )
    PrimaryButton(
        label = "Capture photo",
        onClick = onCapture,
    )
    Text(
        text = "Phase 2 preview — identification is mocked. Real AI arrives in the next update.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun ScanningCard(thumbnail: android.graphics.Bitmap?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            thumbnail?.let {
                Image(
                    bitmap = it.asImageBitmap(),
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp)
                        .clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop,
                )
            }
            CircularProgressIndicator()
            Text("Identifying equipment…", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun ResultCard(
    thumbnail: android.graphics.Bitmap?,
    result: ScanEquipmentViewModel.ScanResult,
    onFindParts: () -> Unit,
    onRetake: () -> Unit,
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
            SectionHeader(title = "AI-identified — please verify")
            Text(
                text = result.brand,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = result.model,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = result.category,
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(
                text = "Confidence: ${(result.confidence * 100).toInt()}%",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
    PrimaryButton(
        label = "Find matching parts",
        onClick = onFindParts,
    )
    OutlinedButton(
        onClick = onRetake,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text("Retake photo")
    }
    Box(modifier = Modifier.height(Spacing.md))
}
