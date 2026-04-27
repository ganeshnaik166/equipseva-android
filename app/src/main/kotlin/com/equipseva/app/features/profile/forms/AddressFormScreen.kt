package com.equipseva.app.features.profile.forms

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.addresses.AddressRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.location.LocationFetcher
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import androidx.compose.foundation.text.KeyboardOptions

@HiltViewModel
class AddressFormViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repo: AddressRepository,
    private val locationFetcher: LocationFetcher,
) : ViewModel() {
    data class Form(
        val id: String? = null,
        val label: String = "",
        val fullName: String = "",
        val phone: String = "",
        val line1: String = "",
        val line2: String = "",
        val landmark: String = "",
        val city: String = "",
        val state: String = "",
        val pincode: String = "",
        val isDefault: Boolean = false,
        val latitude: Double? = null,
        val longitude: Double? = null,
    )

    data class UiState(
        val loading: Boolean = false,
        val saving: Boolean = false,
        val locating: Boolean = false,
        val error: String? = null,
        val form: Form = Form(),
        val saved: Boolean = false,
    )

    private val addressId: String? = savedStateHandle[Routes.PROFILE_ADDRESS_FORM_ARG_ID]
    private val _state = MutableStateFlow(UiState(loading = addressId != null))
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        if (addressId != null) {
            viewModelScope.launch {
                repo.list().onSuccess { rows ->
                    val row = rows.firstOrNull { it.id == addressId }
                    if (row != null) {
                        _state.update {
                            it.copy(
                                loading = false,
                                form = Form(
                                    id = row.id,
                                    label = row.label.orEmpty(),
                                    fullName = row.fullName,
                                    phone = row.phone,
                                    line1 = row.line1,
                                    line2 = row.line2.orEmpty(),
                                    landmark = row.landmark.orEmpty(),
                                    city = row.city,
                                    state = row.state,
                                    pincode = row.pincode,
                                    isDefault = row.isDefault,
                                    latitude = row.latitude,
                                    longitude = row.longitude,
                                ),
                            )
                        }
                    } else {
                        _state.update { it.copy(loading = false, error = "Address not found") }
                    }
                }.onFailure { e ->
                    _state.update { it.copy(loading = false, error = e.message) }
                }
            }
        }
    }

    fun update(transform: (Form) -> Form) {
        _state.update { it.copy(form = transform(it.form), error = null) }
    }

    fun useCurrentLocation() {
        if (_state.value.locating) return
        if (!locationFetcher.hasPermission()) {
            _state.update { it.copy(error = "Permission needed; tap again after granting.") }
            return
        }
        _state.update { it.copy(locating = true, error = null) }
        viewModelScope.launch {
            val coords = locationFetcher.currentCoords()
            if (coords == null) {
                _state.update { it.copy(locating = false, error = "Couldn't read location. Try again outdoors.") }
                return@launch
            }
            val resolved = locationFetcher.reverseGeocode(coords)
            _state.update { st ->
                val current = st.form
                st.copy(
                    locating = false,
                    form = current.copy(
                        line1 = resolved?.line1?.takeIf { it.isNotBlank() } ?: current.line1,
                        line2 = resolved?.line2?.takeIf { it.isNotBlank() } ?: current.line2,
                        landmark = resolved?.landmark?.takeIf { it.isNotBlank() } ?: current.landmark,
                        city = resolved?.city?.takeIf { it.isNotBlank() } ?: current.city,
                        state = resolved?.state?.takeIf { it.isNotBlank() } ?: current.state,
                        pincode = resolved?.pincode?.takeIf { it.isNotBlank() } ?: current.pincode,
                        latitude = coords.lat,
                        longitude = coords.lng,
                    ),
                )
            }
        }
    }

    fun save() {
        val f = _state.value.form
        if (f.fullName.isBlank() || f.phone.isBlank() || f.line1.isBlank()
            || f.city.isBlank() || f.state.isBlank() || f.pincode.isBlank()) {
            _state.update { it.copy(error = "Name, phone, line 1, city, state, pincode are required.") }
            return
        }
        if (f.pincode.length !in 4..10) {
            _state.update { it.copy(error = "Pincode must be 4-10 chars.") }
            return
        }
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val payload = AddressRepository.UserAddress(
                id = f.id,
                label = f.label.takeIf { it.isNotBlank() },
                fullName = f.fullName.trim(),
                phone = f.phone.trim(),
                line1 = f.line1.trim(),
                line2 = f.line2.trim().takeIf { it.isNotBlank() },
                landmark = f.landmark.trim().takeIf { it.isNotBlank() },
                city = f.city.trim(),
                state = f.state.trim(),
                pincode = f.pincode.trim(),
                isDefault = f.isDefault,
                latitude = f.latitude,
                longitude = f.longitude,
            )
            repo.upsert(payload)
                .onSuccess { saved ->
                    if (f.isDefault && saved.id != null) {
                        repo.setDefault(saved.id)
                    }
                    _state.update { it.copy(saving = false, saved = true) }
                }
                .onFailure { e -> _state.update { it.copy(saving = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun AddressFormScreen(
    onBack: () -> Unit,
    viewModel: AddressFormViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { results ->
        if (results.values.any { it }) {
            viewModel.useCurrentLocation()
        }
    }

    LaunchedEffect(state.saved) {
        if (state.saved) onBack()
    }

    Scaffold(topBar = {
        ESBackTopBar(
            title = if (state.form.id == null) "Add address" else "Edit address",
            onBack = onBack,
        )
    }) { padding ->
        if (state.loading) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Surface50)
                .verticalScroll(rememberScrollState())
                .padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            OutlinedButton(
                onClick = {
                    permissionLauncher.launch(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                        ),
                    )
                },
                enabled = !state.saving && !state.locating,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Filled.MyLocation, contentDescription = null, modifier = Modifier.size(18.dp))
                Text(
                    if (state.locating) "Reading your location…" else "Use my current location",
                    modifier = Modifier.padding(start = 6.dp),
                )
            }

            FormField(state.form.label, "Label (Home, HQ — optional)") { v ->
                viewModel.update { it.copy(label = v) }
            }
            FormField(state.form.fullName, "Full name") { v ->
                viewModel.update { it.copy(fullName = v) }
            }
            FormField(state.form.phone, "Phone", keyboardType = KeyboardType.Phone) { v ->
                viewModel.update { it.copy(phone = v.filter { ch -> ch.isDigit() || ch == '+' }) }
            }
            FormField(state.form.line1, "Address line 1") { v ->
                viewModel.update { it.copy(line1 = v) }
            }
            FormField(state.form.line2, "Line 2 (optional)") { v ->
                viewModel.update { it.copy(line2 = v) }
            }
            FormField(state.form.landmark, "Landmark (optional)") { v ->
                viewModel.update { it.copy(landmark = v) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Box(modifier = Modifier.weight(1f)) {
                    FormField(state.form.city, "City") { v ->
                        viewModel.update { it.copy(city = v) }
                    }
                }
                Box(modifier = Modifier.weight(1f)) {
                    FormField(state.form.state, "State") { v ->
                        viewModel.update { it.copy(state = v) }
                    }
                }
            }
            FormField(state.form.pincode, "Pincode", keyboardType = KeyboardType.Number) { v ->
                viewModel.update { it.copy(pincode = v.filter { ch -> ch.isDigit() }) }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Set as default", color = Ink700, modifier = Modifier.weight(1f))
                Switch(
                    checked = state.form.isDefault,
                    onCheckedChange = { v -> viewModel.update { it.copy(isDefault = v) } },
                    enabled = !state.saving,
                )
            }

            if (state.form.latitude != null && state.form.longitude != null) {
                Text(
                    "Coords captured: ${"%.5f".format(state.form.latitude)}, ${"%.5f".format(state.form.longitude)}",
                    color = AccentLime.let { _ -> BrandGreenDeep },
                    fontSize = 11.sp,
                )
            }

            state.error?.let {
                Text(
                    it,
                    color = MaterialTheme.colorScheme.error,
                    fontSize = 13.sp,
                )
            }

            Button(
                onClick = { viewModel.save() },
                enabled = !state.saving && !state.locating,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (state.saving) "Saving…" else if (state.form.id == null) "Save address" else "Save changes")
            }

            Text(
                "Lat/lng captured here is used later for delivery-zone routing. You can edit any field after autofill.",
                color = Ink500,
                fontSize = 11.sp,
            )
        }
    }
}

@Composable
private fun FormField(
    value: String,
    label: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    onChange: (String) -> Unit,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
    )
}
