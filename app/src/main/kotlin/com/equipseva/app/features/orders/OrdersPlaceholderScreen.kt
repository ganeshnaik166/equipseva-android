package com.equipseva.app.features.orders

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.equipseva.app.designsystem.components.ESTopBar

@Composable
fun OrdersPlaceholderScreen() {
    Scaffold(topBar = { ESTopBar(title = "Orders") }) { inner ->
        Box(Modifier.fillMaxSize().padding(inner), contentAlignment = Alignment.Center) {
            Text("Your orders — Phase 1")
        }
    }
}
