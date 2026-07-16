package com.equipseva.app.features.repair

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.invoice.GstInvoicePayloadRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
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

@HiltViewModel
class GstInvoiceViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: GstInvoicePayloadRepository,
) : ViewModel() {
    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.GST_INVOICE_ARG_JOB_ID)) {
            "GstInvoiceViewModel requires arg ${Routes.GST_INVOICE_ARG_JOB_ID}"
        }

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: GstInvoicePayloadRepository.InvoicePayload? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            repo.fetch(jobId)
                .onSuccess { d -> _state.update { it.copy(loading = false, data = d) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Structured GST tax invoice for a completed job (r1412): invoice number/date,
 * the hospital buyer block (GSTIN + address), the equipment line item, and the
 * CGST/SGST/IGST breakdown. Read-only; surfaces get_repair_invoice_payload().
 * Reached from the job "Records" section on completed jobs; complements the
 * downloadable PDF invoice.
 */
@Composable
fun GstInvoiceScreen(
    onBack: () -> Unit,
    viewModel: GstInvoiceViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Tax invoice", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.ReceiptLong,
                    title = "Couldn't load invoice",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.ReceiptLong,
                    title = "No invoice yet",
                    subtitle = "A GST tax invoice is generated once the job is completed.",
                )
                else -> {
                    val d = state.data!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        HeaderCard(d)
                        SectionHeader("Billed to")
                        Card {
                            KeyLine(d.hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital", bold = true)
                            d.hospitalGstin?.takeIf { it.isNotBlank() }?.let { KeyLine("GSTIN: $it") }
                            invoiceAddressLine(d.hospitalAddress, d.hospitalCity, d.hospitalState, d.hospitalPincode)
                                .takeIf { it.isNotBlank() }?.let { KeyLine(it) }
                        }
                        SectionHeader("Service")
                        Card {
                            equipmentLine(d.equipmentType, d.equipmentBrand, d.equipmentModel)
                                .takeIf { it.isNotBlank() }?.let { KeyLine(it, bold = true) }
                            d.equipmentSerial?.takeIf { it.isNotBlank() }?.let { KeyLine("Serial: $it") }
                            (d.serviceDescription ?: d.workDone)?.takeIf { it.isNotBlank() }?.let { KeyLine(it) }
                            d.hsnSacCode?.takeIf { it.isNotBlank() }?.let { KeyLine("HSN/SAC: $it") }
                        }
                        SectionHeader("Amount")
                        Card {
                            AmountRow("Taxable value", d.taxableValue)
                            if (d.cgst > 0) AmountRow("CGST", d.cgst)
                            if (d.sgst > 0) AmountRow("SGST", d.sgst)
                            if (d.igst > 0) AmountRow("IGST", d.igst)
                            AmountRow("GST total", d.gstTotal)
                            AmountRow("Total", d.grossRupees, emphasise = true)
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun HeaderCard(d: GstInvoicePayloadRepository.InvoicePayload) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(d.invoiceNumber.ifBlank { "Tax invoice" }, style = EsType.H5, color = SevaInk900)
        val meta = listOfNotNull(
            d.invoiceDate?.takeIf { it.isNotBlank() }?.let { prettyDate(it) },
            d.jobNumber?.takeIf { it.isNotBlank() }?.let { "Job $it" },
        ).joinToString(" · ")
        if (meta.isNotEmpty()) Text(meta, style = EsType.Caption, color = SevaInk500)
    }
}

@Composable
private fun Card(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        content = content,
    )
}

@Composable
private fun SectionHeader(label: String) {
    Text(label, style = EsType.H5, color = SevaInk900, modifier = Modifier.padding(top = 4.dp))
}

@Composable
private fun KeyLine(text: String, bold: Boolean = false) {
    Text(
        text,
        style = if (bold) EsType.Body.copy(fontWeight = FontWeight.Medium) else EsType.Body,
        color = if (bold) SevaInk900 else SevaInk700,
    )
}

@Composable
private fun AmountRow(label: String, value: Double, emphasise: Boolean = false) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            label,
            style = if (emphasise) EsType.Body.copy(fontWeight = FontWeight.Bold) else EsType.Body,
            color = if (emphasise) SevaInk900 else SevaInk700,
        )
        Text(
            formatRupees(value),
            style = if (emphasise) EsType.Body.copy(fontWeight = FontWeight.Bold) else EsType.Body,
            color = SevaInk900,
        )
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Buyer address line: address, city, state, pincode — blanks omitted. */
internal fun invoiceAddressLine(address: String?, city: String?, state: String?, pincode: String?): String =
    listOfNotNull(
        address?.takeIf { it.isNotBlank() },
        city?.takeIf { it.isNotBlank() },
        state?.takeIf { it.isNotBlank() },
        pincode?.takeIf { it.isNotBlank() },
    ).joinToString(", ")

/** Equipment descriptor: type · brand · model — blanks omitted. */
internal fun equipmentLine(type: String?, brand: String?, model: String?): String =
    listOfNotNull(
        type?.takeIf { it.isNotBlank() },
        brand?.takeIf { it.isNotBlank() },
        model?.takeIf { it.isNotBlank() },
    ).joinToString(" · ")
