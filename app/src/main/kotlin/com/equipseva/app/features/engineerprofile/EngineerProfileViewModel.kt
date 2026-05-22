package com.equipseva.app.features.engineerprofile

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class EngineerProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    // Round 457 — process-death safe edit drafts. Engineer profile is
    // a single-screen form with bio (1500 chars) + service areas /
    // specializations text — non-trivial work. Without persistence an
    // OS kill while the user is in another app drops everything they
    // typed since the last server load.
    private object SavedKeys {
        const val HOURLY_RATE = "engPro.hourlyRate"
        const val YEARS = "engPro.years"
        const val SERVICE_AREAS = "engPro.serviceAreas"
        const val SPECIALIZATIONS = "engPro.specializations"
        const val BIO = "engPro.bio"
        const val AVAILABLE = "engPro.isAvailable"
    }

    data class UiState(
        val loading: Boolean = true,
        val saving: Boolean = false,
        val errorMessage: String? = null,
        val hourlyRate: String = "",
        val yearsExperience: String = "",
        val serviceAreas: String = "",
        val specializations: String = "",
        val bio: String = "",
        val isAvailable: Boolean = true,
    ) {
        val canSave: Boolean
            get() = !saving && !loading && validate() == null

        fun validate(): String? {
            val rate = hourlyRate.trim().toDoubleOrNull()
            if (rate == null || rate <= 0.0) return "Enter an hourly rate greater than 0."
            val years = yearsExperience.trim().toIntOrNull()
            if (years == null || years !in 0..60) return "Years of experience must be between 0 and 60."
            if (parseList(serviceAreas).isEmpty()) return "Add at least one service area (comma-separated)."
            if (parseList(specializations).isEmpty()) return "Pick at least one specialization."
            if (bio.trim().length < BIO_MIN_LEN) return "Bio must be at least $BIO_MIN_LEN characters."
            return null
        }
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data object NavigateBack : Effect
    }

    private val _state = MutableStateFlow(restoredInitialState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private fun restoredInitialState(): UiState =
        UiState(
            // loading is true until either restore-only completes (no
            // server values yet) or load() finishes. Leave at default
            // so the initial spinner doesn't flash for users without
            // any saved draft.
            loading = true,
            hourlyRate = savedStateHandle.get<String>(SavedKeys.HOURLY_RATE).orEmpty(),
            yearsExperience = savedStateHandle.get<String>(SavedKeys.YEARS).orEmpty(),
            serviceAreas = savedStateHandle.get<String>(SavedKeys.SERVICE_AREAS).orEmpty(),
            specializations = savedStateHandle.get<String>(SavedKeys.SPECIALIZATIONS).orEmpty(),
            bio = savedStateHandle.get<String>(SavedKeys.BIO).orEmpty(),
            isAvailable = savedStateHandle.get<Boolean>(SavedKeys.AVAILABLE) ?: true,
        )

    private fun hasDraft(): Boolean =
        savedStateHandle.contains(SavedKeys.HOURLY_RATE) ||
            savedStateHandle.contains(SavedKeys.YEARS) ||
            savedStateHandle.contains(SavedKeys.SERVICE_AREAS) ||
            savedStateHandle.contains(SavedKeys.SPECIALIZATIONS) ||
            savedStateHandle.contains(SavedKeys.BIO) ||
            savedStateHandle.contains(SavedKeys.AVAILABLE)

    private fun clearSavedDraft() {
        savedStateHandle.remove<String>(SavedKeys.HOURLY_RATE)
        savedStateHandle.remove<String>(SavedKeys.YEARS)
        savedStateHandle.remove<String>(SavedKeys.SERVICE_AREAS)
        savedStateHandle.remove<String>(SavedKeys.SPECIALIZATIONS)
        savedStateHandle.remove<String>(SavedKeys.BIO)
        savedStateHandle.remove<Boolean>(SavedKeys.AVAILABLE)
    }

    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    private var userId: String? = null

    // Snapshot of the loaded profile, used by onSave to detect a no-op
    // submit so we don't burn an audit-log row + server round-trip when
    // the user just taps Save without editing anything.
    private data class LoadedSnapshot(
        val hourlyRate: String,
        val yearsExperience: String,
        val serviceAreas: String,
        val specializations: String,
        val bio: String,
        val isAvailable: Boolean,
    )
    private var loadedSnapshot: LoadedSnapshot? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    load(session.userId)
                }
        }
    }

    fun onHourlyRateChange(value: String) {
        val sanitized = sanitizeHourlyRateInput(value)
        savedStateHandle[SavedKeys.HOURLY_RATE] = sanitized
        _state.update { it.copy(hourlyRate = sanitized, errorMessage = null) }
    }

    fun onYearsChange(value: String) {
        val sanitized = sanitizeYearsInput(value)
        savedStateHandle[SavedKeys.YEARS] = sanitized
        _state.update { it.copy(yearsExperience = sanitized, errorMessage = null) }
    }

    fun onServiceAreasChange(value: String) {
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SERVICE_AREAS] = capped
        _state.update { it.copy(serviceAreas = capped, errorMessage = null) }
    }

    fun onSpecializationsChange(value: String) {
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SPECIALIZATIONS] = capped
        _state.update { it.copy(specializations = capped, errorMessage = null) }
    }

    fun onBioChange(value: String) {
        // 1500 chars matches the rest of the long-form text caps in this
        // module — paste of a 10 KB blob otherwise either truncates
        // server-side (silent corruption) or wedges save on the row's
        // effective varchar limit.
        val capped = value.take(1500)
        savedStateHandle[SavedKeys.BIO] = capped
        _state.update { it.copy(bio = capped, errorMessage = null) }
    }

    fun onAvailableChange(value: Boolean) {
        savedStateHandle[SavedKeys.AVAILABLE] = value
        _state.update { it.copy(isAvailable = value) }
    }

    fun onSave() {
        val current = _state.value
        if (!current.canSave) return
        val uid = userId ?: return
        val validationError = current.validate()
        if (validationError != null) {
            _state.update { it.copy(errorMessage = validationError) }
            return
        }
        val rate = current.hourlyRate.trim().toDouble()
        val years = current.yearsExperience.trim().toInt()
        val areas = parseList(current.serviceAreas)
        val specs = parseList(current.specializations)
        val bio = current.bio.trim()

        // No-op submit short-circuit. The save button isn't gated on
        // dirty-state (text inputs need to validate first), so a user
        // can land on this screen and tap Save with zero edits — that
        // used to round-trip the server + write an audit log row for
        // no change. Compare against the snapshot captured at load and
        // navigate back silently.
        loadedSnapshot?.let { snap ->
            if (snap.hourlyRate == current.hourlyRate.trim() &&
                snap.yearsExperience == current.yearsExperience.trim() &&
                snap.serviceAreas == current.serviceAreas.trim() &&
                snap.specializations == current.specializations.trim() &&
                snap.bio == bio &&
                snap.isAvailable == current.isAvailable
            ) {
                viewModelScope.launch {
                    _effects.emit(Effect.NavigateBack)
                }
                return
            }
        }

        _state.update { it.copy(saving = true, errorMessage = null) }
        viewModelScope.launch {
            engineerRepository.upsertProfile(
                userId = uid,
                hourlyRate = rate,
                yearsExperience = years,
                serviceAreas = areas,
                specializations = specs,
                bio = bio,
                isAvailable = current.isAvailable,
            ).onSuccess {
                clearSavedDraft()
                _state.update { it.copy(saving = false) }
                _effects.emit(Effect.ShowMessage("Profile saved"))
                _effects.emit(Effect.NavigateBack)
            }.onFailure { error ->
                _state.update { it.copy(saving = false, errorMessage = error.toUserMessage()) }
            }
        }
    }

    private suspend fun load(uid: String) {
        _state.update { it.copy(loading = true, errorMessage = null) }
        engineerRepository.fetchByUserId(uid)
            .onSuccess { engineer ->
                if (engineer == null) {
                    loadedSnapshot = null
                    _state.update { it.copy(loading = false) }
                } else {
                    val rate = engineer.hourlyRate?.let(::formatRate) ?: ""
                    val years = engineer.yearsExperience?.toString() ?: ""
                    val areas = engineer.serviceAreas.joinToString(", ")
                    // Specializations on the existing row are typed enums (from KYC). Render them as
                    // their storage keys so the engineer can edit-as-text without losing prior choices.
                    val specs = engineer.specializations.joinToString(", ") { spec -> spec.storageKey }
                    val bio = engineer.bio.orEmpty()
                    loadedSnapshot = LoadedSnapshot(
                        hourlyRate = rate,
                        yearsExperience = years,
                        serviceAreas = areas,
                        specializations = specs,
                        bio = bio,
                        isAvailable = engineer.isAvailable,
                    )
                    // Round 457 — drafts win over server values. If the
                    // user was mid-edit and got process-killed, restore
                    // their typed values from SavedStateHandle rather
                    // than clobbering with the older server snapshot.
                    if (hasDraft()) {
                        _state.update { it.copy(loading = false) }
                    } else {
                        _state.update {
                            it.copy(
                                loading = false,
                                hourlyRate = rate,
                                yearsExperience = years,
                                serviceAreas = areas,
                                specializations = specs,
                                bio = bio,
                                isAvailable = engineer.isAvailable,
                            )
                        }
                    }
                }
            }
            .onFailure { error ->
                _state.update { it.copy(loading = false, errorMessage = error.toUserMessage()) }
            }
    }

}

internal const val BIO_MIN_LEN = 20

internal fun parseList(raw: String): List<String> =
    raw.split(',').map { it.trim() }.filter { it.isNotBlank() }

// Strip trailing zero noise from "75.0" -> "75" while keeping "75.5".
internal fun formatRate(value: Double): String {
    val asLong = value.toLong()
    return if (value == asLong.toDouble()) asLong.toString() else value.toString()
}

/**
 * Sanitise the hourly-rate input field. Keep ASCII 0-9 + a single
 * decimal point; reject Devanagari / Arabic digits (Char.isDigit()
 * accepts them but Double.toDoubleOrNull doesn't, so the field would
 * look filled while save fails as "amount required").
 *
 * After-the-first-dot logic: keep the first '.' but strip any
 * subsequent dots (no rate is "75.5.5").
 */
internal fun sanitizeHourlyRateInput(value: String): String {
    val filtered = value.filter { it in '0'..'9' || it == '.' }
    val first = filtered.indexOf('.')
    return if (first == -1) {
        filtered
    } else {
        filtered.substring(0, first + 1) + filtered.substring(first + 1).replace(".", "")
    }
}

/**
 * Sanitise the years-of-experience input — ASCII digits only.
 * Same Devanagari / Arabic / decimal rejection as hourly rate, but
 * a whole-number gate (no fractional years).
 */
internal fun sanitizeYearsInput(value: String): String =
    value.filter { c -> c in '0'..'9' }
