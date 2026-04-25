package com.equipseva.app.features.profile.forms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.userprefs.UserSettingsRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.contentOrNull

/** Field type drives the OutlinedTextField keyboard + validation hints. */
internal enum class FieldKind { TEXT, NUMBER, EMAIL, PHONE, MULTILINE, SWITCH }

internal data class FieldSpec(
    val key: String,
    val label: String,
    val kind: FieldKind = FieldKind.TEXT,
    val placeholder: String? = null,
    val helper: String? = null,
)

@HiltViewModel(assistedFactory = ProfileFormViewModel.Factory::class)
class ProfileFormViewModel @AssistedInject constructor(
    @Assisted private val settingsKey: String,
    private val repo: UserSettingsRepository,
) : ViewModel() {

    @AssistedFactory
    interface Factory {
        fun create(settingsKey: String): ProfileFormViewModel
    }

    data class UiState(
        val loading: Boolean = true,
        val saving: Boolean = false,
        val values: Map<String, String> = emptyMap(),
        val switches: Map<String, Boolean> = emptyMap(),
        val errorMessage: String? = null,
    )

    sealed interface Effect { data class ShowMessage(val text: String) : Effect }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        load()
    }

    private fun load() {
        viewModelScope.launch {
            repo.get(settingsKey)
                .onSuccess { obj ->
                    val texts = mutableMapOf<String, String>()
                    val switches = mutableMapOf<String, Boolean>()
                    obj?.forEach { (k, v) ->
                        when {
                            v is JsonPrimitive && v.booleanOrNull != null -> switches[k] = v.boolean
                            v is JsonPrimitive -> texts[k] = v.contentOrNull.orEmpty()
                            else -> texts[k] = v.toString()
                        }
                    }
                    _state.update {
                        it.copy(loading = false, values = texts, switches = switches)
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(loading = false, errorMessage = e.message) }
                }
        }
    }

    fun onTextChange(key: String, value: String) {
        _state.update { it.copy(values = it.values + (key to value)) }
    }

    fun onSwitchChange(key: String, value: Boolean) {
        _state.update { it.copy(switches = it.switches + (key to value)) }
    }

    fun onSave(onDone: () -> Unit) {
        if (_state.value.saving) return
        _state.update { it.copy(saving = true, errorMessage = null) }
        viewModelScope.launch {
            val payload = buildMap<String, kotlinx.serialization.json.JsonElement> {
                _state.value.values.forEach { (k, v) -> put(k, JsonPrimitive(v)) }
                _state.value.switches.forEach { (k, v) -> put(k, JsonPrimitive(v)) }
            }
            repo.put(settingsKey, JsonObject(payload))
                .onSuccess {
                    _state.update { it.copy(saving = false) }
                    _effects.send(Effect.ShowMessage("Saved"))
                    onDone()
                }
                .onFailure { e ->
                    _state.update { it.copy(saving = false, errorMessage = e.message) }
                    _effects.send(Effect.ShowMessage("Save failed: ${e.message}"))
                }
        }
    }
}

@Composable
internal fun ProfileFormScaffold(
    title: String,
    subtitle: String?,
    settingsKey: String,
    fields: List<FieldSpec>,
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
) {
    val viewModel: ProfileFormViewModel = hiltViewModel(
        creationCallback = { factory: ProfileFormViewModel.Factory ->
            factory.create(settingsKey)
        },
    )
    val state by viewModel.state.collectAsState()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is ProfileFormViewModel.Effect.ShowMessage -> onShowMessage(e.text)
            }
        }
    }

    Scaffold(topBar = { ESBackTopBar(title = title, onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            if (state.loading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(Spacing.lg),
                    verticalArrangement = Arrangement.spacedBy(Spacing.md),
                ) {
                    if (!subtitle.isNullOrBlank()) {
                        Text(
                            subtitle,
                            color = Ink500,
                            fontSize = 13.sp,
                        )
                    }
                    fields.forEach { field ->
                        when (field.kind) {
                            FieldKind.SWITCH -> SwitchRow(
                                label = field.label,
                                helper = field.helper,
                                checked = state.switches[field.key] ?: false,
                                onCheckedChange = { viewModel.onSwitchChange(field.key, it) },
                            )
                            else -> OutlinedTextField(
                                value = state.values[field.key].orEmpty(),
                                onValueChange = { viewModel.onTextChange(field.key, it) },
                                label = { Text(field.label) },
                                placeholder = field.placeholder?.let { { Text(it) } },
                                supportingText = field.helper?.let { { Text(it) } },
                                singleLine = field.kind != FieldKind.MULTILINE,
                                minLines = if (field.kind == FieldKind.MULTILINE) 3 else 1,
                                keyboardOptions = KeyboardOptions(
                                    keyboardType = when (field.kind) {
                                        FieldKind.NUMBER -> KeyboardType.Number
                                        FieldKind.EMAIL -> KeyboardType.Email
                                        FieldKind.PHONE -> KeyboardType.Phone
                                        else -> KeyboardType.Text
                                    },
                                    capitalization = if (field.kind == FieldKind.TEXT)
                                        KeyboardCapitalization.Sentences
                                    else KeyboardCapitalization.None,
                                ),
                                enabled = !state.saving,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                    if (state.errorMessage != null) {
                        Text(
                            state.errorMessage!!,
                            color = androidx.compose.material3.MaterialTheme.colorScheme.error,
                            fontSize = 13.sp,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Button(
                        onClick = { viewModel.onSave(onDone = onBack) },
                        enabled = !state.saving,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (state.saving) "Saving…" else "Save")
                    }
                }
            }
        }
    }
}

@Composable
private fun SwitchRow(
    label: String,
    helper: String?,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Ink900)
            if (!helper.isNullOrBlank()) {
                Text(helper, fontSize = 12.sp, color = Ink500)
            }
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

/* ----------------------- 10 sub-screen wrappers ----------------------- */

@Composable
fun BankDetailsScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Bank details",
        subtitle = "Where we send your payouts. We never display your full account number after saving.",
        settingsKey = "bank_details",
        fields = listOf(
            FieldSpec("account_holder", "Account holder name"),
            FieldSpec("account_number", "Account number", FieldKind.NUMBER),
            FieldSpec("ifsc", "IFSC code", placeholder = "HDFC0000123"),
            FieldSpec("bank_name", "Bank name"),
            FieldSpec("branch", "Branch"),
            FieldSpec("default_payout", "Default payout account", kind = FieldKind.SWITCH, helper = "Used when you have multiple accounts"),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun HospitalAddressesScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Addresses",
        subtitle = "Default delivery + service-call address. Edit any time.",
        settingsKey = "hospital_address",
        fields = listOf(
            FieldSpec("label", "Label", placeholder = "Main building / ICU wing"),
            FieldSpec("street", "Street + locality", kind = FieldKind.MULTILINE),
            FieldSpec("city", "City"),
            FieldSpec("state", "State"),
            FieldSpec("pincode", "PIN code", FieldKind.NUMBER),
            FieldSpec("contact_phone", "Reception phone", FieldKind.PHONE),
            FieldSpec("default_shipping", "Default shipping address", kind = FieldKind.SWITCH),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun HospitalSettingsScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Hospital settings",
        subtitle = "Org-wide preferences for buyers, billing, and approvals.",
        settingsKey = "hospital_settings",
        fields = listOf(
            FieldSpec("auto_approve_under", "Auto-approve orders under (₹)", FieldKind.NUMBER, helper = "Larger orders need biomed sign-off"),
            FieldSpec("departments", "Departments served", FieldKind.MULTILINE, helper = "Comma-separated"),
            FieldSpec("billing_email", "Billing email", FieldKind.EMAIL),
            FieldSpec("gstin", "GSTIN"),
            FieldSpec("biomed_contact", "Biomed contact phone", FieldKind.PHONE),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun StorefrontSettingsScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Storefront settings",
        subtitle = "How your shop reads to hospital buyers.",
        settingsKey = "supplier_storefront",
        fields = listOf(
            FieldSpec("display_name", "Storefront name"),
            FieldSpec("tagline", "Tagline", placeholder = "Genuine OEM spares since 2014"),
            FieldSpec("about", "About the supplier", FieldKind.MULTILINE),
            FieldSpec("hours", "Operating hours", placeholder = "Mon–Sat · 9am – 7pm"),
            FieldSpec("auto_quote_repeat", "Auto-quote for repeat buyers", kind = FieldKind.SWITCH),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun GstSettingsScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "GST details",
        subtitle = "Tax registration + invoice template.",
        settingsKey = "supplier_gst",
        fields = listOf(
            FieldSpec("gstin", "GSTIN"),
            FieldSpec("business_name", "Registered business name"),
            FieldSpec("pan", "PAN"),
            FieldSpec("invoice_prefix", "Invoice prefix", placeholder = "ESV-"),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun BrandPortfolioScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Brand portfolio",
        subtitle = "Brands and product categories you manufacture.",
        settingsKey = "manufacturer_portfolio",
        fields = listOf(
            FieldSpec("brands", "Brands you make", FieldKind.MULTILINE, helper = "Comma-separated"),
            FieldSpec("categories", "Equipment categories", FieldKind.MULTILINE),
            FieldSpec("regions", "Distribution regions", FieldKind.MULTILINE),
            FieldSpec("years_in_business", "Years in business", FieldKind.NUMBER),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun TaxDetailsScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Tax details",
        subtitle = "GST + import-export codes.",
        settingsKey = "manufacturer_tax",
        fields = listOf(
            FieldSpec("gstin", "GSTIN"),
            FieldSpec("iec", "IEC (Importer Exporter Code)"),
            FieldSpec("default_tax_slab", "Default GST rate (%)", FieldKind.NUMBER),
            FieldSpec("pan", "PAN"),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun VehicleDetailsScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Vehicle details",
        subtitle = "Logistics partner vehicle registration + capacity.",
        settingsKey = "logistics_vehicle",
        fields = listOf(
            FieldSpec("plate_number", "Plate number", placeholder = "TN09AB1234"),
            FieldSpec("vehicle_type", "Vehicle type", placeholder = "Bike / Van / Mini truck"),
            FieldSpec("capacity_kg", "Cargo capacity (kg)", FieldKind.NUMBER),
            FieldSpec("rc_number", "RC number"),
            FieldSpec("insurance_expiry", "Insurance expiry (YYYY-MM-DD)"),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun LicenceScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Driving licence",
        subtitle = "Verification status + expiry tracking.",
        settingsKey = "logistics_licence",
        fields = listOf(
            FieldSpec("licence_number", "Licence number"),
            FieldSpec("vehicle_class", "Class of vehicle", placeholder = "LMV / HMV"),
            FieldSpec("issue_date", "Issue date (YYYY-MM-DD)"),
            FieldSpec("expiry_date", "Expiry date (YYYY-MM-DD)"),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )

@Composable
fun ServiceAreasScreen(onBack: () -> Unit, onShowMessage: (String) -> Unit) =
    ProfileFormScaffold(
        title = "Service areas",
        subtitle = "PIN codes / regions you cover.",
        settingsKey = "logistics_service_areas",
        fields = listOf(
            FieldSpec("primary_pincodes", "Primary PIN codes", FieldKind.MULTILINE, helper = "Comma-separated"),
            FieldSpec("regions", "Regions covered", FieldKind.MULTILINE),
            FieldSpec("max_radius_km", "Max delivery radius (km)", FieldKind.NUMBER),
        ),
        onBack = onBack,
        onShowMessage = onShowMessage,
    )
