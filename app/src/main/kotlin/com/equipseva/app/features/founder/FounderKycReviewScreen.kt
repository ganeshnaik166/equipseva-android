package com.equipseva.app.features.founder

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Single-engineer KYC review screen — replaces the inline modal sheet
 * the queue screen used to flip up. Hospitals submit docs (Aadhaar /
 * PAN / cert / selfie); founder reviews and approves or rejects with a
 * reason. Doc previews launch the system viewer via the same Storage
 * signed-URL path the queue screen uses.
 */
@HiltViewModel
class FounderKycReviewViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: FounderRepository,
    private val storage: StorageRepository,
) : ViewModel() {
    private val userId: String = savedStateHandle[Routes.FOUNDER_KYC_REVIEW_ARG_USER_ID] ?: ""

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val engineer: FounderRepository.PendingEngineer? = null,
        val rejectMode: Boolean = false,
        val reasonDraft: String = "",
        val acting: Boolean = false,
        val done: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchPendingEngineers()
                .onSuccess { rows ->
                    val match = rows.firstOrNull { it.userId == userId }
                    _state.update { it.copy(loading = false, engineer = match) }
                }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    suspend fun signedUrlFor(path: String): Result<String> = runCatching {
        storage.signedUrl(
            bucket = StorageRepository.Buckets.KYC_DOCS,
            path = path,
            expiresInMinutes = 60,
        )
    }

    fun openReject() {
        _state.update { it.copy(rejectMode = true, reasonDraft = "") }
    }

    fun closeReject() {
        if (_state.value.acting) return
        _state.update { it.copy(rejectMode = false, reasonDraft = "") }
    }

    fun onReasonChange(value: String) {
        _state.update { it.copy(reasonDraft = value.take(500)) }
    }

    fun approve() = setVerification(target = "verified", reason = null)

    fun confirmReject() {
        val s = _state.value
        if (s.reasonDraft.isBlank()) {
            _state.update { it.copy(error = "Reason required to reject") }
            return
        }
        setVerification(target = "rejected", reason = s.reasonDraft)
    }

    private fun setVerification(target: String, reason: String?) {
        if (_state.value.acting) return
        _state.update { it.copy(acting = true, error = null) }
        viewModelScope.launch {
            repo.setEngineerVerification(userId, target, reason)
                .onSuccess {
                    _state.update { it.copy(acting = false, rejectMode = false, done = true) }
                }
                .onFailure { e ->
                    _state.update { it.copy(acting = false, error = e.toUserMessage()) }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FounderKycReviewScreen(
    onBack: () -> Unit,
    viewModel: FounderKycReviewViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    LaunchedEffect(state.done) {
        if (state.done) onBack()
    }

    val openDoc: (FounderRepository.PendingEngineer.DocRef) -> Unit = { doc ->
        scope.launch {
            viewModel.signedUrlFor(doc.path)
                .onSuccess { url ->
                    runCatching {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    }
                }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "KYC review", onBack = onBack)
            Box(modifier = Modifier.weight(1f)) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.engineer == null -> EmptyStateView(
                        icon = Icons.Outlined.Description,
                        title = "Not in queue",
                        subtitle = state.error ?: "This engineer is no longer pending review.",
                    )
                    else -> ReviewBody(
                        engineer = state.engineer!!,
                        onOpenDoc = openDoc,
                    )
                }
            }
            // Sticky bottom action bar
            if (state.engineer != null) {
                Surface(color = Color.White) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Box(modifier = Modifier.weight(1f)) {
                            EsBtn(
                                text = "Reject",
                                onClick = viewModel::openReject,
                                kind = EsBtnKind.DangerOutline,
                                size = EsBtnSize.Lg,
                                full = true,
                                disabled = state.acting,
                            )
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            EsBtn(
                                text = if (state.acting) "…" else "Approve",
                                onClick = viewModel::approve,
                                kind = EsBtnKind.Primary,
                                size = EsBtnSize.Lg,
                                full = true,
                                disabled = state.acting,
                            )
                        }
                    }
                }
            }
        }
    }

    if (state.rejectMode) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            sheetState = sheetState,
            onDismissRequest = { viewModel.closeReject() },
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text("Reject KYC", style = EsType.H4, color = SevaInk900)
                OutlinedTextField(
                    value = state.reasonDraft,
                    onValueChange = viewModel::onReasonChange,
                    label = { Text("Reason (shown to engineer)") },
                    placeholder = { Text("e.g. Aadhaar photo unreadable") },
                    enabled = !state.acting,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(modifier = Modifier.weight(1f)) {
                        EsBtn(
                            text = "Cancel",
                            onClick = { viewModel.closeReject() },
                            kind = EsBtnKind.Secondary,
                            full = true,
                            disabled = state.acting,
                        )
                    }
                    Box(modifier = Modifier.weight(1f)) {
                        EsBtn(
                            text = if (state.acting) "…" else "Reject",
                            onClick = viewModel::confirmReject,
                            kind = EsBtnKind.Danger,
                            full = true,
                            disabled = state.acting || state.reasonDraft.isBlank(),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ReviewBody(
    engineer: FounderRepository.PendingEngineer,
    onOpenDoc: (FounderRepository.PendingEngineer.DocRef) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Hero card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
                .padding(16.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(SevaGreen900),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = engineer.fullName.firstOrNull()?.uppercaseChar()?.toString() ?: "E",
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(engineer.fullName, style = EsType.H4, color = SevaInk900)
                    val sub = listOfNotNull(
                        engineer.city,
                        engineer.createdAt?.let { "submitted ${it.take(10)}" },
                    ).joinToString(" · ")
                    if (sub.isNotBlank()) {
                        Text(sub, style = EsType.Caption, color = SevaInk500)
                    }
                }
            }
        }

        ReviewSection(title = "Identity") {
            Row(modifier = Modifier.fillMaxWidth()) {
                Text("Email", color = SevaInk500, modifier = Modifier.width(90.dp))
                Text(engineer.email ?: "—", color = SevaInk900, fontWeight = FontWeight.Medium)
            }
            Row(modifier = Modifier.fillMaxWidth()) {
                Text("Phone", color = SevaInk500, modifier = Modifier.width(90.dp))
                Text(engineer.phone ?: "—", color = SevaInk900, fontWeight = FontWeight.Medium)
            }
            if (engineer.aadhaarVerified) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text("Aadhaar", color = SevaInk500, modifier = Modifier.width(90.dp))
                    Text(
                        "verified",
                        color = SevaGreen700,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }

        if (engineer.experienceYears != null || engineer.serviceRadiusKm != null) {
            ReviewSection(title = "Coverage") {
                engineer.experienceYears?.let {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("Experience", color = SevaInk500, modifier = Modifier.width(120.dp))
                        Text("$it years", color = SevaInk900, fontWeight = FontWeight.Medium)
                    }
                }
                engineer.serviceRadiusKm?.let {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("Service radius", color = SevaInk500, modifier = Modifier.width(120.dp))
                        Text("$it km", color = SevaInk900, fontWeight = FontWeight.Medium)
                    }
                }
                engineer.state?.let {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text("State", color = SevaInk500, modifier = Modifier.width(120.dp))
                        Text(it, color = SevaInk900, fontWeight = FontWeight.Medium)
                    }
                }
            }
        }

        val docs = engineer.docPaths()
        if (docs.isNotEmpty()) {
            ReviewSection(title = "Documents") {
                // 2-column doc grid
                docs.chunked(2).forEach { pair ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        pair.forEach { doc ->
                            DocTile(
                                doc = doc,
                                onClick = { onOpenDoc(doc) },
                                modifier = Modifier.weight(1f),
                            )
                        }
                        if (pair.size == 1) {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }
            }
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ReviewSection(
    title: String,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(title, style = EsType.H5, color = SevaInk900)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun DocTile(
    doc: FounderRepository.PendingEngineer.DocRef,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Paper2)
            .clickable(onClick = onClick)
            .padding(vertical = 18.dp, horizontal = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            Icons.Outlined.Description,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(28.dp),
        )
        Text(
            text = doc.displayLabel,
            style = EsType.Caption.copy(fontWeight = FontWeight.SemiBold),
            color = SevaInk500,
        )
    }
}

