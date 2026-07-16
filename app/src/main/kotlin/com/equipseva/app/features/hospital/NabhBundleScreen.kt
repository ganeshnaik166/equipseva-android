package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.hospital.NabhBundleRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class NabhBundleViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val repo: NabhBundleRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<NabhBundleRepository.NabhDsr> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var loadedSerial: String? = null

    /** Idempotent per serial so the composable's LaunchedEffect can call it freely. */
    fun load(serial: String, force: Boolean = false) {
        if (!force && serial == loadedSerial && state.value.error == null) return
        loadedSerial = serial
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val uid = (session as? AuthSession.SignedIn)?.userId
            if (uid == null) {
                _state.update { it.copy(loading = false, error = "Sign in again to view this bundle.") }
                return@launch
            }
            repo.fetch(hospitalUserId = uid, equipmentSerial = serial)
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * NABH audit bundle (r1414): the Digital Service Reports for one asset over the
 * last 24 months — signatures + signer, IEC 62353 / calibration pass flags —
 * a read-only accreditation preview. Surfaces nabh_bundle_for_equipment()
 * (round 494). Drill-down from Asset history.
 */
@Composable
fun NabhBundleScreen(
    serial: String,
    title: String,
    onBack: () -> Unit,
    viewModel: NabhBundleViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(serial) { viewModel.load(serial) }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = title.ifBlank { "NABH bundle" }, onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.VerifiedUser,
                    title = "Couldn't load bundle",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.load(serial, force = true) },
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.VerifiedUser,
                    title = "No signed reports yet",
                    subtitle = "Signed service reports for SN $serial from the last 24 months will appear here for NABH audits.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(key = "sn") {
                        Text(
                            "SN $serial · ${state.rows.size} report${if (state.rows.size == 1) "" else "s"}",
                            style = EsType.Caption,
                            color = SevaInk500,
                            modifier = Modifier.padding(horizontal = 2.dp, vertical = 2.dp),
                        )
                    }
                    items(state.rows, key = { it.dsrId }) { dsr -> NabhRow(dsr) }
                }
            }
        }
    }
}

@Composable
private fun NabhRow(dsr: NabhBundleRepository.NabhDsr) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                nabhSignOffStatus(dsr.engineerSignatureAt, dsr.hospitalSignatureAt),
                style = EsType.Body.copy(fontWeight = FontWeight.Medium),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            val signedAt = dsr.hospitalSignatureAt ?: dsr.engineerSignatureAt
            signedAt?.takeIf { it.isNotBlank() }?.let {
                Text(prettyDate(it), style = EsType.Caption, color = SevaInk500)
            }
        }
        dsr.hospitalSignerName?.takeIf { it.isNotBlank() }?.let { name ->
            val role = dsr.hospitalSignerRole?.takeIf { it.isNotBlank() }
            Text(if (role != null) "$name · $role" else name, style = EsType.Caption, color = SevaInk700)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            val (iecText, iecKind) = nabhCheckPill("IEC 62353", dsr.iec62353Passed)
            Pill(text = iecText, kind = iecKind)
            val (calText, calKind) = nabhCheckPill("Calibration", dsr.calibrationWithinOem)
            Pill(text = calText, kind = calKind)
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Sign-off status from the two signature timestamps. */
internal fun nabhSignOffStatus(engineerAt: String?, hospitalAt: String?): String {
    val eng = !engineerAt.isNullOrBlank()
    val hos = !hospitalAt.isNullOrBlank()
    return when {
        eng && hos -> "Both signed"
        eng -> "Engineer signed"
        hos -> "Hospital signed"
        else -> "Unsigned"
    }
}

/** Labelled compliance-check pill: "<label> ✓/✗/—". */
internal fun nabhCheckPill(label: String, passed: Boolean?): Pair<String, PillKind> = when (passed) {
    true -> "$label ✓" to PillKind.Success
    false -> "$label ✗" to PillKind.Danger
    null -> "$label —" to PillKind.Neutral
}
