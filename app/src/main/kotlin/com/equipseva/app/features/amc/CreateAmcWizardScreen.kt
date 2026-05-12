package com.equipseva.app.features.amc

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
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
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.data.engineers.DirectorySortMode
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.payments.RazorpayCheckoutLauncher
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class CreateAmcWizardViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: AmcRepository,
    private val engineerRepo: EngineerDirectoryRepository,
    private val auth: AuthRepository,
    private val launcher: RazorpayCheckoutLauncher,
) : ViewModel() {

    private val primaryEngineerId: String =
        savedStateHandle[Routes.CREATE_AMC_ARG_ENGINEER_ID] ?: ""

    enum class Step { Scope, FrequencyFee, Sla, Engineer }

    data class FallbackOption(
        val engineerId: String,
        val name: String,
        val city: String?,
    )

    data class UiState(
        val step: Step = Step.Scope,
        val primaryEngineerId: String = "",
        val primaryEngineerName: String = "",
        // Step 1
        val equipmentCategories: List<String> = emptyList(),
        val scopeText: String = "",
        // Step 2
        val visitFrequency: String = "monthly",
        val visitsPerYear: Int = 12,
        val monthlyFeeRupees: String = DEFAULT_MONTHLY_FEE_RUPEES,
        // Step 3
        val responseTimeStandardHours: String = "24",
        val responseTimeEmergencyHours: String = "4",
        // Step 4
        val fallbackEngineers: List<FallbackOption> = emptyList(),
        val pickerOpen: Boolean = false,
        val pickerQuery: String = "",
        val pickerLoading: Boolean = false,
        val pickerResults: List<FallbackOption> = emptyList(),
        // Submit
        val submitting: Boolean = false,
        val createdContractId: String? = null,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState(primaryEngineerId = primaryEngineerId))
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        loadPrimaryName()
    }

    private fun loadPrimaryName() {
        if (primaryEngineerId.isBlank()) return
        viewModelScope.launch {
            engineerRepo.fetchPublicProfile(primaryEngineerId)
                .onSuccess { p ->
                    _state.update { it.copy(primaryEngineerName = p?.fullName ?: "Engineer") }
                }
        }
    }

    fun setStep(s: Step) = _state.update { it.copy(step = s) }
    fun next() = _state.update { it.copy(step = next(it.step)) }
    fun back() = _state.update { it.copy(step = back(it.step)) }

    private fun next(s: Step): Step = when (s) {
        Step.Scope -> Step.FrequencyFee
        Step.FrequencyFee -> Step.Sla
        Step.Sla -> Step.Engineer
        Step.Engineer -> Step.Engineer
    }

    private fun back(s: Step): Step = when (s) {
        Step.Scope -> Step.Scope
        Step.FrequencyFee -> Step.Scope
        Step.Sla -> Step.FrequencyFee
        Step.Engineer -> Step.Sla
    }

    fun toggleCategory(c: String) = _state.update { st ->
        val s = st.equipmentCategories.toMutableList()
        if (s.contains(c)) s.remove(c) else s.add(c)
        st.copy(equipmentCategories = s)
    }

    fun setScopeText(v: String) = _state.update { it.copy(scopeText = v) }
    fun setFrequency(v: String) = _state.update { it.copy(visitFrequency = v, visitsPerYear = derive(v)) }
    fun setVisitsPerYear(v: String) = _state.update {
        it.copy(visitsPerYear = v.toIntOrNull()?.coerceIn(1, 52) ?: it.visitsPerYear)
    }
    fun setMonthlyFeeRupees(v: String) = _state.update { it.copy(monthlyFeeRupees = v) }
    fun setStandardHours(v: String) = _state.update { it.copy(responseTimeStandardHours = v) }
    fun setEmergencyHours(v: String) = _state.update { it.copy(responseTimeEmergencyHours = v) }

    fun openPicker() = _state.update { it.copy(pickerOpen = true, pickerQuery = "") }
    fun closePicker() = _state.update { it.copy(pickerOpen = false) }
    fun setPickerQuery(q: String) {
        _state.update { it.copy(pickerQuery = q, pickerLoading = true) }
        viewModelScope.launch {
            engineerRepo.search(query = q.takeIf { it.isNotBlank() }, sortMode = DirectorySortMode.Rating)
                .onSuccess { rows ->
                    _state.update { st ->
                        st.copy(
                            pickerLoading = false,
                            pickerResults = rows
                                .filter { it.engineerId != st.primaryEngineerId }
                                .filter { row ->
                                    st.fallbackEngineers.none { it.engineerId == row.engineerId }
                                }
                                .map { row ->
                                    FallbackOption(
                                        engineerId = row.engineerId,
                                        name = row.fullName,
                                        city = row.city,
                                    )
                                },
                        )
                    }
                }
                .onFailure { _state.update { st -> st.copy(pickerLoading = false) } }
        }
    }

    fun addFallback(option: FallbackOption) = _state.update { st ->
        if (st.fallbackEngineers.any { it.engineerId == option.engineerId }) st
        else st.copy(
            fallbackEngineers = st.fallbackEngineers + option,
            pickerResults = st.pickerResults.filterNot { it.engineerId == option.engineerId },
        )
    }

    fun removeFallback(engineerId: String) = _state.update { st ->
        st.copy(fallbackEngineers = st.fallbackEngineers.filterNot { it.engineerId == engineerId })
    }

    /**
     * Persist the contract via [AmcRepository.createContract] then run
     * the Razorpay first-month upfront via [AmcPaymentViewModel.runCheckout].
     * On verified success, calls [onSuccess] with the contract id so the
     * caller can navigate into [AmcDetailScreen].
     */
    fun submitAndPay(
        activity: Activity,
        onSuccess: (contractId: String) -> Unit,
        onShowMessage: (String) -> Unit,
    ) {
        if (_state.value.submitting) return
        val s = _state.value
        val fee = s.monthlyFeeRupees.toDoubleOrNull()
        if (fee == null || fee <= 0) {
            _state.update { it.copy(error = "Monthly fee must be a positive number") }
            return
        }
        val emergency = s.responseTimeEmergencyHours.toIntOrNull()?.coerceAtLeast(1) ?: 4
        val standard = s.responseTimeStandardHours.toIntOrNull()?.coerceAtLeast(1) ?: 24

        // Default term = 1 year. start = today (UTC ISO date), end = +365d.
        val today = java.time.LocalDate.now()
        val start = today.toString()
        val end = today.plusDays(DEFAULT_CONTRACT_DAYS).toString()

        _state.update { it.copy(submitting = true, error = null) }
        viewModelScope.launch {
            repo.createContract(
                primaryEngineerId = s.primaryEngineerId,
                visitFrequency = s.visitFrequency,
                visitsPerYear = s.visitsPerYear,
                monthlyFeeRupees = fee,
                startDate = start,
                endDate = end,
                equipmentCategories = s.equipmentCategories,
                scopeText = s.scopeText.takeIf { it.isNotBlank() },
                responseTimeEmergencyHours = emergency,
                responseTimeStandardHours = standard,
                // Auto-renew is opt-in: the wizard never prompts the user
                // for it, so default to false. Earlier hardcoded `true` made
                // every contract render the "Auto-renew" pill on detail
                // even though the hospital never agreed to it. When the
                // wizard adds a renewal step, flip this back.
                autoRenew = false,
                renewalTermMonths = 12,
                fallbackEngineerIds = s.fallbackEngineers.map { it.engineerId },
            ).fold(
                onSuccess = { newId ->
                    _state.update { it.copy(createdContractId = newId) }
                    // Immediately fire first-month upfront. If the user
                    // cancels Razorpay we still keep the contract — pool
                    // is just at zero so the contract is paused on first
                    // visit complete. Hospital can top up from detail.
                    val ok = runCheckout(
                        activity = activity,
                        amcContractId = newId,
                        months = 1,
                        engineerName = s.primaryEngineerName,
                    )
                    _state.update { it.copy(submitting = false) }
                    if (ok) {
                        onShowMessage("Contract created and first month paid.")
                    } else {
                        onShowMessage("Contract created. Top up to activate the pool.")
                    }
                    onSuccess(newId)
                },
                onFailure = { e ->
                    _state.update { it.copy(submitting = false, error = e.message) }
                    onShowMessage(e.message ?: "Couldn't create contract")
                },
            )
        }
    }

    private fun derive(freq: String): Int = when (freq) {
        "weekly" -> 52
        "biweekly" -> 26
        "monthly" -> 12
        "quarterly" -> 4
        else -> 12
    }

    /**
     * End-to-end Razorpay flow used by the wizard's first-month upfront
     * payment. Mirrors [AmcPaymentViewModel.runCheckout] verbatim — kept
     * inline here so we don't have to constructor-inject another
     * @HiltViewModel (Hilt forbids that). Callers from outside the
     * wizard use [AmcPaymentViewModel].
     */
    private suspend fun runCheckout(
        activity: Activity,
        amcContractId: String,
        months: Int,
        engineerName: String,
    ): Boolean {
        val orderRes = repo.createPaymentOrder(amcContractId, months)
        if (orderRes.isFailure) return false
        val order = orderRes.getOrThrow()
        val session = auth.sessionState
            .filterIsInstance<AuthSession.SignedIn>()
            .firstOrNull()
        val email = session?.email
        val result = runCatching {
            launcher.startPayment(
                activity = activity,
                amountPaise = order.amountPaise,
                currency = order.currency,
                name = "EquipSeva AMC",
                description = "$months month${if (months == 1) "" else "s"} for $engineerName",
                prefillEmail = email,
                prefillContact = null,
                razorpayOrderId = order.razorpayOrderId,
                keyId = order.keyId,
            )
        }.getOrElse { return false }
        return when (result) {
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Cancelled -> false
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Failed -> false
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Success -> {
                repo.verifyPayment(
                    paymentOrderId = order.paymentOrderId,
                    razorpayOrderId = result.razorpayOrderId.ifBlank { order.razorpayOrderId },
                    razorpayPaymentId = result.razorpayPaymentId,
                    razorpaySignature = result.razorpaySignature,
                ).isSuccess
            }
        }
    }

    private companion object {
        // Pre-fills Step 2 fee field; engineer can edit before submit.
        const val DEFAULT_MONTHLY_FEE_RUPEES: String = "5000"
        // AMC default term is 1 year (365 days). Server is the authority on
        // the actual end date — this is only the wizard pre-fill.
        const val DEFAULT_CONTRACT_DAYS: Long = 365L
    }
}

private val DEFAULT_CATEGORIES = listOf(
    "patient_monitoring",
    "ventilator",
    "ultrasound",
    "x_ray",
    "ct_scan",
    "mri",
    "anaesthesia",
    "surgical",
    "laboratory",
    "icu",
    "emergency",
    "life_support",
)


@Composable
fun CreateAmcWizardScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onCreated: (contractId: String) -> Unit,
    viewModel: CreateAmcWizardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "New maintenance contract",
                subtitle = stepLabel(state.step),
                onBack = onBack,
            )
            Box(modifier = Modifier.weight(1f)) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                ) {
                    when (state.step) {
                        CreateAmcWizardViewModel.Step.Scope -> ScopeStep(state, viewModel)
                        CreateAmcWizardViewModel.Step.FrequencyFee -> FrequencyFeeStep(state, viewModel)
                        CreateAmcWizardViewModel.Step.Sla -> SlaStep(state, viewModel)
                        CreateAmcWizardViewModel.Step.Engineer -> EngineerStep(
                            state = state,
                            onAddFallback = { viewModel.openPicker() },
                            onRemoveFallback = viewModel::removeFallback,
                        )
                    }
                    Spacer(Modifier.height(80.dp))
                }
            }
            // Sticky footer: Back + Next/Submit
            Surface(color = Color.White) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(BorderDefault),
                    )
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        EsBtn(
                            text = "Back",
                            onClick = {
                                if (state.step == CreateAmcWizardViewModel.Step.Scope) onBack()
                                else viewModel.back()
                            },
                            kind = EsBtnKind.Secondary,
                            size = EsBtnSize.Lg,
                        )
                        Box(modifier = Modifier.weight(1f)) {
                            val isLast = state.step == CreateAmcWizardViewModel.Step.Engineer
                            EsBtn(
                                text = when {
                                    state.submitting -> "Submitting…"
                                    isLast -> "Create + pay first month"
                                    else -> "Next"
                                },
                                onClick = {
                                    if (isLast) {
                                        if (activity == null) {
                                            onShowMessage("Couldn't open Razorpay — please try again.")
                                            return@EsBtn
                                        }
                                        scope.launch {
                                            // No-op wrapper: ViewModel handles its own scope.
                                        }
                                        viewModel.submitAndPay(
                                            activity = activity,
                                            onSuccess = onCreated,
                                            onShowMessage = onShowMessage,
                                        )
                                    } else viewModel.next()
                                },
                                kind = EsBtnKind.Primary,
                                size = EsBtnSize.Lg,
                                full = true,
                                disabled = state.submitting,
                            )
                        }
                    }
                }
            }
        }
    }

    if (state.pickerOpen) {
        FallbackPickerSheet(
            query = state.pickerQuery,
            results = state.pickerResults,
            loading = state.pickerLoading,
            onQueryChange = viewModel::setPickerQuery,
            onPick = { opt ->
                viewModel.addFallback(opt)
                viewModel.closePicker()
            },
            onClose = viewModel::closePicker,
        )
    }
}

@Composable
private fun ScopeStep(state: CreateAmcWizardViewModel.UiState, vm: CreateAmcWizardViewModel) {
    EsSection(title = "Equipment categories") {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            Text(
                "Pick everything this contract covers. Engineers in the rotation must service at least one of these.",
                color = SevaInk500,
                fontSize = 12.sp,
            )
            Spacer(Modifier.height(10.dp))
            CategoryFlow(
                items = DEFAULT_CATEGORIES,
                selected = state.equipmentCategories,
                onToggle = vm::toggleCategory,
            )
        }
    }
    EsSection(title = "Scope notes") {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            EsField(
                value = state.scopeText,
                onChange = vm::setScopeText,
                placeholder = "What's covered? (e.g., quarterly calibration, OT equipment)",
                type = EsFieldType.Multiline,
            )
        }
    }
}

@Composable
private fun FrequencyFeeStep(state: CreateAmcWizardViewModel.UiState, vm: CreateAmcWizardViewModel) {
    EsSection(title = "Visit cadence") {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(
                    "weekly" to "Weekly",
                    "biweekly" to "2 weeks",
                    "monthly" to "Monthly",
                    "quarterly" to "Quarterly",
                ).forEach { (k, label) ->
                    EsChip(
                        text = label,
                        active = state.visitFrequency == k,
                        onClick = { vm.setFrequency(k) },
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            EsField(
                value = state.visitsPerYear.toString(),
                onChange = vm::setVisitsPerYear,
                label = "Visits per year",
                type = EsFieldType.Number,
                hint = "Auto-derived from cadence; tweak if needed.",
            )
        }
    }
    EsSection(title = "Monthly fee") {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            EsField(
                value = state.monthlyFeeRupees,
                onChange = vm::setMonthlyFeeRupees,
                label = "Monthly fee (₹)",
                type = EsFieldType.Number,
                hint = "Per-month rate. First month charged now; top up later from contract details.",
            )
        }
    }
}

@Composable
private fun SlaStep(state: CreateAmcWizardViewModel.UiState, vm: CreateAmcWizardViewModel) {
    EsSection(title = "Response time targets") {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            EsField(
                value = state.responseTimeStandardHours,
                onChange = vm::setStandardHours,
                label = "Standard (hours)",
                type = EsFieldType.Number,
                hint = "Default 24h. SLA breach auto-issues a goodwill credit if exceeded.",
            )
            EsField(
                value = state.responseTimeEmergencyHours,
                onChange = vm::setEmergencyHours,
                label = "Emergency (hours)",
                type = EsFieldType.Number,
                hint = "Default 4h. Used when contract covers ICU / life-support categories.",
            )
        }
    }
}

@Composable
private fun EngineerStep(
    state: CreateAmcWizardViewModel.UiState,
    onAddFallback: () -> Unit,
    onRemoveFallback: (engineerId: String) -> Unit,
) {
    EsSection(title = "Primary engineer") {
        Box(
            modifier = Modifier
                .padding(horizontal = 16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(Paper2)
                .padding(14.dp),
        ) {
            Column {
                Text(
                    state.primaryEngineerName.ifBlank { "Selected engineer" },
                    color = SevaInk900,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    "Primary is the engineer whose profile launched this wizard.",
                    color = SevaInk500,
                    fontSize = 12.sp,
                )
            }
        }
    }
    EsSection(
        title = "Fallback engineers",
        action = "Add",
        onAction = onAddFallback,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (state.fallbackEngineers.isEmpty()) {
                Text(
                    "Optional. Backup engineers get auto-assigned if the primary is unavailable.",
                    color = SevaInk500,
                    fontSize = 12.sp,
                )
            } else {
                state.fallbackEngineers.forEachIndexed { idx, opt ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White)
                            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(opt.name, color = SevaInk900, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            opt.city?.takeIf { it.isNotBlank() }?.let {
                                Text(it, color = SevaInk500, fontSize = 11.sp)
                            }
                        }
                        Pill(text = "Priority ${idx + 2}", kind = PillKind.Neutral)
                        Box(
                            modifier = Modifier
                                .clickable { onRemoveFallback(opt.engineerId) }
                                .padding(6.dp),
                        ) {
                            Icon(
                                Icons.Outlined.Close,
                                contentDescription = "Remove",
                                tint = SevaInk700,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FallbackPickerSheet(
    query: String,
    results: List<CreateAmcWizardViewModel.FallbackOption>,
    loading: Boolean,
    onQueryChange: (String) -> Unit,
    onPick: (CreateAmcWizardViewModel.FallbackOption) -> Unit,
    onClose: () -> Unit,
) {
    EsBottomSheet(onClose = onClose, title = "Add a fallback engineer") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            EsField(
                value = query,
                onChange = onQueryChange,
                placeholder = "Search by name, brand, or specialization",
            )
            Box(modifier = Modifier.height(280.dp).fillMaxWidth()) {
                when {
                    loading -> Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }
                    results.isEmpty() -> Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            if (query.isBlank()) "Type a search query above" else "No engineers match",
                            color = SevaInk500,
                            fontSize = 13.sp,
                        )
                    }
                    else -> LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        items(results, key = { it.engineerId }) { opt ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(Color.White)
                                    .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                                    .clickable { onPick(opt) }
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        opt.name,
                                        color = SevaInk900,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                    opt.city?.takeIf { it.isNotBlank() }?.let {
                                        Text(it, color = SevaInk500, fontSize = 11.sp)
                                    }
                                }
                                Text("Add", color = SevaGreen700, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CategoryFlow(
    items: List<String>,
    selected: List<String>,
    onToggle: (String) -> Unit,
) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items.forEach { c ->
            EsChip(
                text = amcCategoryLabel(c),
                active = selected.contains(c),
                onClick = { onToggle(c) },
            )
        }
    }
}

private fun stepLabel(s: CreateAmcWizardViewModel.Step): String = when (s) {
    CreateAmcWizardViewModel.Step.Scope -> "Step 1 of 4 · Scope"
    CreateAmcWizardViewModel.Step.FrequencyFee -> "Step 2 of 4 · Frequency + Fee"
    CreateAmcWizardViewModel.Step.Sla -> "Step 3 of 4 · SLA"
    CreateAmcWizardViewModel.Step.Engineer -> "Step 4 of 4 · Engineer"
}
