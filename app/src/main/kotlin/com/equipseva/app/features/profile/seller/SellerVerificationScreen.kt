package com.equipseva.app.features.profile.seller

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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.UploadFile
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@HiltViewModel
class SellerVerificationViewModel @Inject constructor(
    private val client: SupabaseClient,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val storage: StorageRepository,
) : ViewModel() {

    @Serializable
    private data class OrgRow(
        @SerialName("verification_status") val verificationStatus: String? = null,
        @SerialName("rejection_reason") val rejectionReason: String? = null,
    )

    data class UiState(
        val loading: Boolean = true,
        val orgId: String? = null,
        val status: String = "pending", // pending | verified | rejected | unsubmitted
        val rejectionReason: String? = null,
        val gstNumber: String = "",
        val licenceUri: Uri? = null,
        val licenceFileName: String? = null,
        val submitting: Boolean = false,
        val errorMessage: String? = null,
    )

    sealed interface Effect { data class ShowMessage(val text: String) : Effect }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init { reload() }

    fun reload() {
        viewModelScope.launch {
            val session = authRepository.sessionState.filterIsInstance<AuthSession.SignedIn>().first()
            val profile = profileRepository.fetchById(session.userId).getOrNull()
            val orgId = profile?.organizationId
            if (orgId == null) {
                _state.update { it.copy(loading = false, status = "unsubmitted", errorMessage = "Your account isn't linked to a supplier organization yet.") }
                return@launch
            }
            val org = client.from("organizations").select(columns = Columns.list("verification_status", "rejection_reason")) {
                filter { eq("id", orgId) }
                limit(1)
            }.decodeList<OrgRow>().firstOrNull()
            _state.update {
                it.copy(
                    loading = false,
                    orgId = orgId,
                    status = org?.verificationStatus ?: "pending",
                    rejectionReason = org?.rejectionReason,
                )
            }
        }
    }

    fun onGstChange(value: String) =
        _state.update { it.copy(gstNumber = value.uppercase().take(15), errorMessage = null) }

    fun onLicencePicked(uri: Uri?, fileName: String?) =
        _state.update { it.copy(licenceUri = uri, licenceFileName = fileName, errorMessage = null) }

    fun onSubmit(context: Context, onDone: () -> Unit) {
        val s = _state.value
        if (s.submitting) return
        if (s.gstNumber.length !in 13..15) {
            _state.update { it.copy(errorMessage = "Enter a valid GSTIN (15 chars).") }
            return
        }
        if (s.licenceUri == null) {
            _state.update { it.copy(errorMessage = "Upload your trade licence PDF or photo.") }
            return
        }
        val orgId = s.orgId ?: return
        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            val userId = authRepository.sessionState.filterIsInstance<AuthSession.SignedIn>().first().userId
            // Read URI bytes
            val bytes = runCatching {
                context.contentResolver.openInputStream(s.licenceUri)?.use { it.readBytes() }
            }.getOrNull()
            if (bytes == null || bytes.isEmpty()) {
                _state.update { it.copy(submitting = false, errorMessage = "Could not read the selected file.") }
                return@launch
            }
            val mimeType = context.contentResolver.getType(s.licenceUri) ?: "application/pdf"
            val ext = when {
                mimeType.contains("pdf") -> "pdf"
                mimeType.contains("png") -> "png"
                mimeType.contains("jpeg") || mimeType.contains("jpg") -> "jpg"
                mimeType.contains("webp") -> "webp"
                else -> "bin"
            }
            val path = "$userId/seller_licence_${System.currentTimeMillis()}.$ext"
            val upload = storage.upload(StorageRepository.Buckets.KYC_DOCS, path, bytes, mimeType)
            if (upload.isFailure) {
                _state.update { it.copy(submitting = false, errorMessage = upload.exceptionOrNull()?.toUserMessage() ?: "Upload failed.") }
                return@launch
            }
            // Insert verification request row
            val insert = runCatching {
                client.from("seller_verification_requests").insert(
                    mapOf(
                        "organization_id" to orgId,
                        "submitted_by" to userId,
                        "gst_number" to s.gstNumber,
                        "trade_licence_url" to path,
                    ),
                )
                Unit
            }
            insert.onSuccess {
                _state.update {
                    it.copy(
                        submitting = false,
                        status = "pending",
                        rejectionReason = null,
                    )
                }
                _effects.send(Effect.ShowMessage("Submitted — founder review queued"))
                onDone()
            }.onFailure { e ->
                _state.update { it.copy(submitting = false, errorMessage = e.toUserMessage()) }
            }
        }
    }
}

@Composable
fun SellerVerificationScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: SellerVerificationViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) { is SellerVerificationViewModel.Effect.ShowMessage -> onShowMessage(e.text) }
        }
    }

    val licencePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri ->
        val name = uri?.lastPathSegment?.substringAfterLast('/')
        viewModel.onLicencePicked(uri, name)
    }

    Scaffold(topBar = { ESBackTopBar(title = "Seller verification", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            if (state.loading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(Spacing.lg),
                    verticalArrangement = Arrangement.spacedBy(Spacing.md),
                ) {
                    StatusBanner(status = state.status, rejectionReason = state.rejectionReason)

                    if (state.status != "verified") {
                        Text(
                            "We need your business credentials before you can list spare parts or equipment for sale.",
                            color = Ink500,
                            fontSize = 13.sp,
                        )
                        OutlinedTextField(
                            value = state.gstNumber,
                            onValueChange = viewModel::onGstChange,
                            label = { Text("GSTIN (15 chars)") },
                            placeholder = { Text("29ABCDE1234F1Z5") },
                            singleLine = true,
                            enabled = !state.submitting,
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                            modifier = Modifier.fillMaxWidth(),
                        )
                        LicencePickerRow(
                            fileName = state.licenceFileName,
                            enabled = !state.submitting,
                            onPick = { licencePicker.launch("*/*") },
                        )
                        if (state.errorMessage != null) {
                            Text(state.errorMessage!!, color = ErrorRed, fontSize = 13.sp)
                        }
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = { viewModel.onSubmit(context, onDone = onBack) },
                            enabled = !state.submitting,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(if (state.submitting) "Submitting…" else "Submit for review")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusBanner(status: String, rejectionReason: String?) {
    val (icon, bg, fg, title, body) = when (status) {
        "verified" -> StatusInfo(
            Icons.Filled.CheckCircle,
            BrandGreen50,
            BrandGreenDark,
            "Verified",
            "Your organisation can list parts and equipment.",
        )
        "rejected" -> StatusInfo(
            Icons.Filled.Warning,
            Color(0xFFFCE7E7),
            ErrorRed,
            "Submission rejected",
            rejectionReason ?: "Please re-upload corrected documents.",
        )
        else -> StatusInfo(
            Icons.Filled.HourglassTop,
            WarningBg,
            Warning,
            "Pending review",
            "Founder team will review your documents shortly.",
        )
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(36.dp).clip(CircleShape).background(Surface0),
            contentAlignment = Alignment.Center,
        ) { Icon(icon, contentDescription = null, tint = fg) }
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(title, fontWeight = FontWeight.Bold, color = fg)
            Text(body, fontSize = 12.sp, color = Ink900)
        }
    }
}

private data class StatusInfo(
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val bg: Color,
    val fg: Color,
    val title: String,
    val body: String,
)

@Composable
private fun LicencePickerRow(fileName: String?, enabled: Boolean, onPick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(12.dp))
            .clickable(enabled = enabled, onClick = onPick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.UploadFile, contentDescription = null, tint = BrandGreen)
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                fileName ?: "Upload trade licence (PDF / JPG / PNG)",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink900,
            )
            Text(
                "Stored securely in private kyc-docs bucket",
                fontSize = 12.sp,
                color = Ink500,
            )
        }
    }
}
