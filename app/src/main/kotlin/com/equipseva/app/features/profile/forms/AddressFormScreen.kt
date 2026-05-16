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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import com.equipseva.app.core.data.location.IndiaLocations
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.location.LocationFetcher
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EsDropdown
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
        /** Transient feedback after "Use my current location" — summarises which
         *  address fields the geocoder actually filled. Cleared on next edit. */
        val locationInfo: String? = null,
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
                    _state.update { it.copy(loading = false, error = e.toUserMessage()) }
                }
            }
        }
    }

    fun update(transform: (Form) -> Form) {
        _state.update { it.copy(form = transform(it.form), error = null, locationInfo = null) }
    }

    fun hasLocationPermission(): Boolean = locationFetcher.hasPermission()

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
                val filledFields = buildList {
                    if (!resolved?.line1.isNullOrBlank() && current.line1.isBlank()) add("line 1")
                    if (!resolved?.city.isNullOrBlank() && current.city.isBlank()) add("city")
                    if (!resolved?.state.isNullOrBlank() && current.state.isBlank()) add("state")
                    if (!resolved?.pincode.isNullOrBlank() && current.pincode.isBlank()) add("pincode")
                }
                val info = when {
                    filledFields.isNotEmpty() -> "Filled ${filledFields.joinToString()} from your GPS pin."
                    resolved != null -> "Saved your GPS pin — fill the address fields manually."
                    else -> "Saved your GPS pin (couldn't read a street address here)."
                }
                // Only fill BLANK fields — never overwrite text the user
                // already typed. The geocoder is best-effort; preserving
                // user input matters more than freshness.
                fun fill(current: String, resolved: String?): String =
                    if (current.isBlank()) resolved?.takeIf { it.isNotBlank() } ?: current else current
                st.copy(
                    locating = false,
                    locationInfo = info,
                    form = current.copy(
                        line1 = fill(current.line1, resolved?.line1),
                        line2 = fill(current.line2, resolved?.line2),
                        landmark = fill(current.landmark, resolved?.landmark),
                        city = fill(current.city, resolved?.city),
                        state = fill(current.state, resolved?.state),
                        pincode = fill(current.pincode, resolved?.pincode),
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
        // India-only flow (city / state cascade is hard-coded to Indian
        // states), so the pincode is exactly 6 digits. The earlier 4..10
        // window let through international formats that the rest of the
        // form can't actually deliver to.
        if (f.pincode.length != 6 || !f.pincode.all { it in '0'..'9' }) {
            _state.update { it.copy(error = "Pincode must be 6 digits.") }
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
    val state by viewModel.state.collectAsStateWithLifecycle()

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
                    // Skip the permission dialog if we already have it — go
                    // straight to the fetch. The dialog used to fire on every
                    // tap, which on Android 14+ devices either auto-dismisses
                    // or shows a stale "Allowed once" prompt that confuses
                    // users into thinking nothing happened.
                    if (viewModel.hasLocationPermission()) {
                        viewModel.useCurrentLocation()
                    } else {
                        permissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                            ),
                        )
                    }
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

            state.locationInfo?.let { info ->
                Text(
                    text = info,
                    fontSize = 12.sp,
                    color = com.equipseva.app.designsystem.theme.SevaInk500,
                )
            }

            // Server CHECKs (20260704200000_round281) bound label at 80,
            // full_name at 200. Cap here so a paste of a multi-MB blob
            // doesn't either silently truncate (without these caps) or
            // fail save with a confusing 23514 constraint-violation toast.
            FormField(state.form.label, "Label (Home, HQ — optional)") { v ->
                viewModel.update { it.copy(label = v.take(80)) }
            }
            FormField(state.form.fullName, "Full name") { v ->
                viewModel.update { it.copy(fullName = v.take(200)) }
            }
            FormField(state.form.phone, "Phone", keyboardType = KeyboardType.Phone) { v ->
                // ASCII-digit filter (Kotlin's Char.isDigit() also accepts
                // Devanagari/Arabic digits and the DB ends up storing
                // non-ASCII strings). At most one leading '+' so callers
                // can't smuggle "++91…" into the row.
                val ascii = v.filter { ch -> ch in '0'..'9' || ch == '+' }
                val hasPlus = ascii.startsWith('+')
                val digits = ascii.filter { ch -> ch in '0'..'9' }
                viewModel.update { it.copy(phone = if (hasPlus) "+$digits" else digits) }
            }
            // 200/100/100 caps mirror the bounds used in the engineer
            // KYC address fields (PR #609 family) — keeps a single full
            // address line from being paste-bombed with a multi-screen
            // novel and silently growing user_addresses.line1 unbounded.
            FormField(state.form.line1, "Address line 1") { v ->
                viewModel.update { it.copy(line1 = v.take(200)) }
            }
            FormField(state.form.line2, "Line 2 (optional)") { v ->
                viewModel.update { it.copy(line2 = v.take(100)) }
            }
            FormField(state.form.landmark, "Landmark (optional)") { v ->
                viewModel.update { it.copy(landmark = v.take(100)) }
            }
            // State must be from the curated IndiaLocations.STATES list —
            // free-text here was the source of "Telangana, 508207" style
            // garbage values surfacing later in engineer directory cards.
            // Treat legacy non-canonical values as unset so the dropdown
            // shows the placeholder instead of an unselectable string.
            EsDropdown(
                value = state.form.state.takeIf { it in IndiaLocations.STATES },
                onValueChange = { picked ->
                    viewModel.update {
                        // Clear city when state changes so a previously-picked
                        // district from another state doesn't leak through.
                        if (it.state == picked) it else it.copy(state = picked, city = "")
                    }
                },
                options = IndiaLocations.STATES,
                label = "State",
                placeholder = "Select state",
            )
            // City stays free-text — district list is too coarse for
            // hospital addresses — but accept only ASCII letters /
            // whitespace / hyphen / apostrophe / period. Char.isLetter()
            // would let Devanagari, Tamil, Arabic codepoints through,
            // which the backend's case-insensitive ASCII matching can't
            // round-trip. Same Unicode-leak class that bit pincode/phone.
            FormField(state.form.city, "City") { v ->
                val cleaned = v.filter { ch ->
                    ch in 'a'..'z' || ch in 'A'..'Z' || ch.isWhitespace() ||
                        ch == '-' || ch == '\'' || ch == '.'
                }
                // Server CHECK (round281) caps at 120 chars.
                viewModel.update { it.copy(city = cleaned.take(120)) }
            }
            FormField(state.form.pincode, "Pincode", keyboardType = KeyboardType.Number) { v ->
                // ASCII-only digits — Char.isDigit() accepts Arabic /
                // Devanagari digits which would round-trip through Postgres
                // and break the length-6 validator downstream.
                viewModel.update { it.copy(pincode = v.filter { ch -> ch in '0'..'9' }) }
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
                    "Coords captured: ${"%.5f".format(java.util.Locale.US, state.form.latitude)}, ${"%.5f".format(java.util.Locale.US, state.form.longitude)}",
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

            // Mirror the required-field check that VM.save() runs server-side
            // so the user sees the button as disabled instead of tapping
            // through to a generic "fields are required" toast.
            val f = state.form
            // VM.save() rejects anything other than exactly 6 digits (India-only
            // flow). The earlier 4..10 window let the button look enabled for
            // a 4-digit pincode and only failed at submit-time toast.
            val canSave = f.fullName.isNotBlank() && f.phone.isNotBlank() &&
                f.line1.isNotBlank() && f.city.isNotBlank() &&
                f.state.isNotBlank() &&
                f.pincode.length == 6 && f.pincode.all { it in '0'..'9' }
            Button(
                onClick = { viewModel.save() },
                enabled = !state.saving && !state.locating && canSave,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (state.saving) "Saving…" else if (state.form.id == null) "Save address" else "Save changes")
            }

            Text(
                "Lat/lng captured here is used to match nearby engineers and show distances. You can edit any field after autofill.",
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
