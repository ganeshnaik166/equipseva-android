package com.equipseva.app.features.founder

import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.outlined.Category
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.components.EmptyStateView
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private fun url(draft: FounderCategoriesViewModel.EditDraft): String? =
    draft.imageUrl?.takeIf { it.isNotBlank() }

@HiltViewModel
class FounderCategoriesViewModel @Inject constructor(
    private val repo: FounderRepository,
    private val storage: StorageRepository,
) : ViewModel() {
    data class EditDraft(
        val key: String = "",
        val displayName: String = "",
        val scope: String = "both",
        val sortOrder: String = "100",
        val isActive: Boolean = true,
        val imageUrl: String? = null,
        val isNew: Boolean = true,
        val uploadingImage: Boolean = false,
    )

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.CategoryRow> = emptyList(),
        val editDraft: EditDraft? = null,
        val saving: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchCategories()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun openNew() {
        _state.update { it.copy(editDraft = EditDraft(isNew = true)) }
    }

    fun openEdit(row: FounderRepository.CategoryRow) {
        _state.update {
            it.copy(
                editDraft = EditDraft(
                    key = row.key,
                    displayName = row.displayName,
                    scope = row.scope,
                    sortOrder = row.sortOrder.toString(),
                    isActive = row.isActive,
                    imageUrl = row.imageUrl,
                    isNew = false,
                ),
            )
        }
    }

    fun uploadImage(context: Context, uri: Uri) {
        val draft = _state.value.editDraft ?: return
        val key = draft.key.trim().lowercase().ifBlank {
            _state.update { it.copy(error = "Set the key first") }
            return
        }
        _state.update { it.copy(editDraft = draft.copy(uploadingImage = true), error = null) }
        viewModelScope.launch {
            val resolver = context.contentResolver
            val mime = resolver.getType(uri) ?: "image/jpeg"
            val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                _state.update { it.copy(editDraft = it.editDraft?.copy(uploadingImage = false), error = "Couldn't read image") }
                return@launch
            }
            val ext = when (mime.lowercase()) {
                "image/png" -> "png"
                "image/webp" -> "webp"
                else -> "jpg"
            }
            val path = "$key.$ext"
            storage.upload(StorageRepository.Buckets.CATEGORY_IMAGES, path, bytes, mime)
                .onSuccess {
                    val url = storage.publicUrl(StorageRepository.Buckets.CATEGORY_IMAGES, path) +
                        "?v=" + System.currentTimeMillis()
                    _state.update {
                        it.copy(editDraft = it.editDraft?.copy(imageUrl = url, uploadingImage = false))
                    }
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            editDraft = it.editDraft?.copy(uploadingImage = false),
                            error = e.toUserMessage(),
                        )
                    }
                }
        }
    }

    fun closeSheet() {
        if (_state.value.saving) return
        _state.update { it.copy(editDraft = null, saving = false) }
    }

    fun onDraftChange(transform: (EditDraft) -> EditDraft) {
        _state.update { it.copy(editDraft = it.editDraft?.let(transform)) }
    }

    fun save() {
        val draft = _state.value.editDraft ?: return
        if (draft.key.isBlank() || draft.displayName.isBlank()) {
            _state.update { it.copy(error = "Key and name are required") }
            return
        }
        if (draft.scope !in setOf("spare_part", "repair", "both")) {
            _state.update { it.copy(error = "Scope must be spare_part, repair, or both") }
            return
        }
        val sort = draft.sortOrder.toIntOrNull() ?: 100
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            repo.upsertCategory(
                key = draft.key.trim().lowercase(),
                displayName = draft.displayName.trim(),
                scope = draft.scope,
                sortOrder = sort,
                isActive = draft.isActive,
                imageUrl = draft.imageUrl,
            )
                .onSuccess {
                    _state.update { it.copy(saving = false, editDraft = null) }
                    reload()
                }
                .onFailure { e ->
                    _state.update { it.copy(saving = false, error = e.toUserMessage()) }
                }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderCategoriesScreen(
    onBack: () -> Unit,
    viewModel: FounderCategoriesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(
        topBar = { EsTopBar(title = "Equipment categories", onBack = onBack) },
        containerColor = PaperDefault,
        floatingActionButton = {
            FloatingActionButton(
                onClick = { viewModel.openNew() },
                containerColor = SevaGreen700,
            ) { Icon(Icons.Filled.Add, contentDescription = "Add category", tint = androidx.compose.ui.graphics.Color.White) }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null && state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Category,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Category,
                    title = "No categories yet",
                    subtitle = "Tap + to add the first category.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.rows, key = { it.key }) { row ->
                        CategoryRowCard(row = row, onClick = { viewModel.openEdit(row) })
                    }
                }
            }
        }
    }

    val draft = state.editDraft
    if (draft != null) {
        val context = androidx.compose.ui.platform.LocalContext.current
        val imagePicker = rememberLauncherForActivityResult(
            contract = ActivityResultContracts.GetContent(),
        ) { uri: Uri? ->
            if (uri != null) viewModel.uploadImage(context, uri)
        }
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            sheetState = sheetState,
            onDismissRequest = { viewModel.closeSheet() },
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    if (draft.isNew) "New category" else "Edit ${draft.key}",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaInk900,
                )

                // Image preview + picker.
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Paper2)
                            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center,
                    ) {
                        val url = draft.imageUrl
                        if (!url.isNullOrBlank()) {
                            AsyncImage(
                                model = url,
                                contentDescription = "Category image",
                                modifier = Modifier.fillMaxSize(),
                                contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Outlined.Category,
                                contentDescription = null,
                                tint = SevaInk500,
                            )
                        }
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        OutlinedButton(
                            onClick = { imagePicker.launch("image/*") },
                            enabled = !state.saving && !draft.uploadingImage && draft.key.isNotBlank(),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Icon(Icons.Filled.AddPhotoAlternate, contentDescription = null, modifier = Modifier.size(18.dp))
                            Text(
                                if (draft.uploadingImage) "Uploading…"
                                else if (url(draft) == null) "Pick image"
                                else "Replace image",
                                modifier = Modifier.padding(start = 6.dp),
                                fontSize = 13.sp,
                            )
                        }
                        Text(
                            if (draft.key.isBlank()) "Set the key first"
                            else "Set image first if scope = both",
                            color = SevaInk500,
                            fontSize = 11.sp,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }

                OutlinedTextField(
                    value = draft.key,
                    onValueChange = { v -> viewModel.onDraftChange { it.copy(key = v) } },
                    label = { Text("Key (snake_case)") },
                    enabled = draft.isNew && !state.saving,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = draft.displayName,
                    onValueChange = { v -> viewModel.onDraftChange { it.copy(displayName = v) } },
                    label = { Text("Display name") },
                    enabled = !state.saving,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("spare_part", "repair", "both").forEach { opt ->
                        val selected = draft.scope == opt
                        OutlinedButton(
                            onClick = { viewModel.onDraftChange { it.copy(scope = opt) } },
                            enabled = !state.saving,
                            modifier = Modifier.weight(1f),
                            colors = if (selected) {
                                androidx.compose.material3.ButtonDefaults.outlinedButtonColors(
                                    containerColor = SevaGreen700.copy(alpha = 0.1f),
                                    contentColor = SevaGreen700,
                                )
                            } else {
                                androidx.compose.material3.ButtonDefaults.outlinedButtonColors()
                            },
                        ) { Text(opt, fontSize = 12.sp) }
                    }
                }
                OutlinedTextField(
                    value = draft.sortOrder,
                    onValueChange = { v -> viewModel.onDraftChange { it.copy(sortOrder = v.filter { ch -> ch.isDigit() }) } },
                    label = { Text("Sort order") },
                    enabled = !state.saving,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Active", color = SevaInk700, modifier = Modifier.weight(1f))
                    Switch(
                        checked = draft.isActive,
                        onCheckedChange = { v -> viewModel.onDraftChange { it.copy(isActive = v) } },
                        enabled = !state.saving,
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { viewModel.closeSheet() },
                        enabled = !state.saving,
                        modifier = Modifier.weight(1f),
                    ) { Text("Cancel") }
                    Button(
                        onClick = { viewModel.save() },
                        enabled = !state.saving,
                        modifier = Modifier.weight(1f),
                    ) { Text(if (state.saving) "…" else "Save") }
                }
            }
        }
    }
}

@Composable
private fun CategoryRowCard(
    row: FounderRepository.CategoryRow,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(androidx.compose.ui.graphics.Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Paper2)
                .border(1.dp, BorderDefault, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
        ) {
            val img = row.imageUrl
            if (!img.isNullOrBlank()) {
                AsyncImage(
                    model = img,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                )
            } else {
                Icon(Icons.Outlined.Category, contentDescription = null, tint = SevaInk500)
            }
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(row.displayName, color = SevaInk900, fontWeight = FontWeight.Bold, fontSize = 15.sp, modifier = Modifier.weight(1f))
                val statusColor = if (row.isActive) SevaGreen700 else SevaInk500
                Text(
                    if (row.isActive) "Active" else "Disabled",
                    color = statusColor,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
            Text("key: ${row.key}", color = SevaInk500, fontSize = 12.sp)
            Text("scope: ${row.scope} · order: ${row.sortOrder}", color = SevaInk700, fontSize = 12.sp)
        }
    }
}
