package com.equipseva.app.features.scan

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DocumentScanner
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanEquipmentScreen(
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = { ESBackTopBar(title = "Scan equipment", onBack = onBack) },
    ) { inner ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            EmptyStateView(
                icon = Icons.Outlined.DocumentScanner,
                title = "AI scanner coming soon",
                subtitle = "Point your camera at equipment to identify brand, model, " +
                    "and match spare parts. Camera capture ships in the next update.",
            )
        }
    }
}
