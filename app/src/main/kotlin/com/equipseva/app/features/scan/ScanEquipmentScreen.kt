package com.equipseva.app.features.scan

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EquipmentArt
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.components.TonalButton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

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
        containerColor = Surface50,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            when {
                state.result != null -> ResultCard(
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
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = Spacing.xxl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        // Brand-50 hero circle with the scanner glyph centered.
        Box(
            modifier = Modifier
                .size(140.dp)
                .clip(CircleShape)
                .background(BrandGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Default.QrCodeScanner,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier.size(64.dp),
            )
        }

        Text(
            text = "Scan equipment",
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold),
            color = Ink900,
            textAlign = TextAlign.Center,
        )
        Text(
            text = "Point your camera at the equipment label, nameplate, or model sticker.",
            style = MaterialTheme.typography.bodyMedium,
            color = Ink500,
            textAlign = TextAlign.Center,
        )

        PrimaryButton(label = "Open camera", onClick = onCapture)

        Text(
            text = "Phase 2 preview · identification is mocked. Real AI lands soon.",
            style = MaterialTheme.typography.labelMedium,
            color = Ink500,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ScanningCard(thumbnail: android.graphics.Bitmap?) {
    val shape = MaterialTheme.shapes.large
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Surface0)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        if (thumbnail != null) {
            Image(
                bitmap = thumbnail.asImageBitmap(),
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .clip(MaterialTheme.shapes.medium),
                contentScale = ContentScale.Crop,
            )
        }
        CircularProgressIndicator()
        Text(
            text = "Analyzing…",
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = Ink700,
        )
        Text(
            text = "Matching nameplate against the medical-equipment catalog.",
            style = MaterialTheme.typography.bodySmall,
            color = Ink500,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ResultCard(
    result: ScanEquipmentViewModel.ScanResult,
    onFindParts: () -> Unit,
    onRetake: () -> Unit,
) {
    val shape = MaterialTheme.shapes.large
    val confidencePct = (result.confidence * 100).toInt()
    // Hue varies with confidence: green at high, amber at low — keeps the tile
    // chromatically tied to the model's certainty.
    val tileHue = when {
        result.confidence >= 0.85f -> 150
        result.confidence >= 0.7f -> 200
        else -> 40
    }

    SectionHeader(title = "AI identified · please verify")

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Surface0)
            .border(1.dp, Surface200, shape)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Pastel tile with a medical-services illustration as the result thumb.
        GradientTile(
            art = EquipmentArt.MedicalServices,
            hue = tileHue,
            size = 200.dp,
        )

        Text(
            text = result.brand,
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold),
            color = Ink900,
        )
        Text(
            text = result.model,
            style = MaterialTheme.typography.titleMedium,
            color = Ink700,
        )
        Text(
            text = result.category,
            style = MaterialTheme.typography.bodyMedium,
            color = Ink500,
        )
        StatusChip(
            label = "$confidencePct% confident",
            tone = when {
                result.confidence >= 0.85f -> StatusTone.Success
                result.confidence >= 0.7f -> StatusTone.Info
                else -> StatusTone.Warn
            },
        )
    }

    PrimaryButton(label = "Find parts", onClick = onFindParts)
    TonalButton(label = "Re-take photo", onClick = onRetake)
    Spacer(Modifier.height(Spacing.md))
}
