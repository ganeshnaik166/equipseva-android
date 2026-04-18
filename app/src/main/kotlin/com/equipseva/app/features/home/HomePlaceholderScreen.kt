package com.equipseva.app.features.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.material3.MaterialTheme
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.theme.Spacing

@Composable
fun HomePlaceholderScreen() {
    Scaffold(topBar = { ESTopBar(title = "EquipSeva") }) { inner ->
        Column(
            modifier = Modifier.fillMaxSize().padding(inner).padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Welcome to EquipSeva", style = MaterialTheme.typography.headlineLarge)
            Text("Phase 1 will land hospital + engineer entry points here.", style = MaterialTheme.typography.bodyMedium)
        }
    }
}
