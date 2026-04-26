package com.medeq.app.ui.search

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.medeq.app.data.repository.EquipmentRepository.ResultSource
import com.medeq.app.data.repository.EquipmentRepository.SearchState
import com.medeq.app.domain.Equipment

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(viewModel: SearchViewModel) {
    val query by viewModel.query.collectAsState()
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Hospital Equipment") })
        },
    ) { padding ->
        Column(modifier = Modifier.padding(padding).fillMaxSize()) {
            OutlinedTextField(
                value = query,
                onValueChange = viewModel::onQueryChange,
                placeholder = { Text("Search by brand, model, type…") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            )

            when (val s = state) {
                SearchState.Idle -> EmptyState("Type at least 2 characters to search")

                SearchState.Loading -> Row(
                    Modifier.fillMaxWidth().padding(16.dp),
                    horizontalArrangement = Arrangement.Center,
                ) { CircularProgressIndicator() }

                is SearchState.Results -> if (s.items.isEmpty()) {
                    EmptyState("No results. Try a different brand or generic name.")
                } else {
                    SourceBanner(s.source, s.items.size, s.remoteError)
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        items(s.items, key = { it.id }) { item -> EquipmentRow(item) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SourceBanner(source: ResultSource, count: Int, error: String?) {
    val text = when (source) {
        ResultSource.LOCAL ->            "$count results · offline"
        ResultSource.LOCAL_AND_REMOTE -> "$count results · offline + OpenFDA"
        ResultSource.REMOTE_ONLY ->      "$count results · OpenFDA"
    }
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        shape = RoundedCornerShape(8.dp),
    ) {
        Column(Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            Text(text, style = MaterialTheme.typography.labelMedium)
            if (error != null) {
                Text(
                    "Network: $error",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

@Composable
private fun EmptyState(message: String) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(message, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun EquipmentRow(item: Equipment) {
    val ctx = LocalContext.current
    Column(
        Modifier
            .fillMaxWidth()
            .clickable {
                item.imageSearchUrl?.let {
                    ctx.startActivity(Intent(Intent.ACTION_VIEW, it.toUri()))
                }
            }
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(item.itemName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            buildString {
                item.brand?.let { append(it) }
                if (!item.model.isNullOrBlank()) append(" · ${item.model}")
            },
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (!item.specifications.isNullOrBlank()) {
            Text(
                item.specifications,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
            )
        }
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            AssistChip(
                onClick = {},
                label = { Text(item.category) },
                colors = AssistChipDefaults.assistChipColors(
                    containerColor = MaterialTheme.colorScheme.secondaryContainer,
                ),
            )
            Spacer(Modifier.height(0.dp))
            item.priceRangeLabel?.let {
                Text(
                    "  $it",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            if (item.source == Equipment.Source.GUDID) {
                Text(
                    "  · GUDID",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.outline,
                )
            }
        }
        HorizontalDivider(Modifier.padding(top = 12.dp))
    }
}
