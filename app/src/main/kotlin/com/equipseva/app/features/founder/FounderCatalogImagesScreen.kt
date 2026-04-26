package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.catalog.CatalogReferenceRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@HiltViewModel
class FounderCatalogImagesViewModel @Inject constructor(
    private val client: SupabaseClient,
    private val repo: CatalogReferenceRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val items: List<CatalogReferenceRepository.Item> = emptyList(),
        val error: String? = null,
        val saving: Set<Int> = emptySet(),
    )

    @Serializable
    private data class ImageUpdate(
        @SerialName("image_url") val imageUrl: String?,
        @SerialName("image_url_source") val imageUrlSource: String?,
        @SerialName("needs_image_review") val needsImageReview: Boolean,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                client.from("catalog_reference_items").select {
                    filter { eq("needs_image_review", true) }
                    limit(200)
                }.decodeList<CatalogReferenceRepository.Item>()
            }.onSuccess { rows ->
                _state.update { it.copy(loading = false, items = rows) }
            }.onFailure { ex ->
                _state.update { it.copy(loading = false, error = ex.toUserMessage()) }
            }
        }
    }

    fun onSetUrl(itemId: Int, url: String) {
        if (url.isBlank()) return
        _state.update { it.copy(saving = it.saving + itemId) }
        viewModelScope.launch {
            runCatching {
                client.from("catalog_reference_items").update(
                    ImageUpdate(
                        imageUrl = url.trim(),
                        imageUrlSource = "manual",
                        needsImageReview = false,
                    )
                ) {
                    filter { eq("id", itemId) }
                }
            }.onSuccess {
                _state.update {
                    it.copy(
                        items = it.items.filterNot { row -> row.id == itemId },
                        saving = it.saving - itemId,
                    )
                }
            }.onFailure { ex ->
                _state.update { it.copy(error = ex.toUserMessage(), saving = it.saving - itemId) }
            }
        }
    }
}

@Composable
fun FounderCatalogImagesScreen(
    onBack: () -> Unit,
    viewModel: FounderCatalogImagesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current

    Scaffold(topBar = { ESBackTopBar(title = "Catalogue images", onBack = onBack) }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.items.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "All curated",
                    subtitle = "No catalog rows are waiting for an image.",
                )
                else -> LazyColumn(
                    contentPadding = PaddingValues(Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    items(state.items, key = { it.id }) { item ->
                        ReviewRow(
                            item = item,
                            saving = item.id in state.saving,
                            onSetUrl = { url -> viewModel.onSetUrl(item.id, url) },
                            onOpenSearch = {
                                item.imageSearchUrl?.let { url ->
                                    runCatching {
                                        context.startActivity(
                                            android.content.Intent(
                                                android.content.Intent.ACTION_VIEW,
                                                android.net.Uri.parse(url),
                                            ),
                                        )
                                    }
                                }
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ReviewRow(
    item: CatalogReferenceRepository.Item,
    saving: Boolean,
    onSetUrl: (String) -> Unit,
    onOpenSearch: () -> Unit,
) {
    var draft by remember(item.id) { mutableStateOf(item.imageUrl.orEmpty()) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (!item.imageUrl.isNullOrBlank()) {
            coil3.compose.AsyncImage(
                model = item.imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Surface200),
            )
        }
        Text(item.itemName, fontWeight = FontWeight.Bold, color = Ink900, fontSize = 15.sp)
        val brandLine = listOfNotNull(item.brand, item.model).joinToString(" · ")
        if (brandLine.isNotBlank()) {
            Text(brandLine, color = Ink700, fontSize = 13.sp)
        }
        item.imageUrlConfidence?.let { conf ->
            Text(
                "Auto match score: ${"%.2f".format(conf)} — please verify",
                color = if (conf < 0.25) BrandGreen.copy(alpha = 0.6f) else Ink500,
                fontSize = 11.sp,
            )
        }
        OutlinedTextField(
            value = draft,
            onValueChange = { draft = it },
            label = { Text("Paste correct image URL") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onOpenSearch, modifier = Modifier.weight(1f)) {
                Icon(Icons.Filled.Image, contentDescription = null)
                Text("  Search images", fontSize = 12.sp)
            }
            Button(
                onClick = { onSetUrl(draft) },
                enabled = !saving && draft.isNotBlank(),
                modifier = Modifier.weight(1f),
            ) {
                Text(if (saving) "Saving…" else "Save URL", fontSize = 12.sp)
            }
        }
    }
}
