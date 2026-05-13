package com.equipseva.app.features.engineerprofile

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
) : ViewModel() {

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

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

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
        // ASCII digits + a single decimal point. Char.isDigit() would
        // also accept Devanagari / Arabic codepoints, which the server
        // toDoubleOrNull can't parse — the field would look filled
        // while save fails with "amount required".
        val sanitized = value.filter { it in '0'..'9' || it == '.' }
            .let { v ->
                val first = v.indexOf('.')
                if (first == -1) v else v.substring(0, first + 1) + v.substring(first + 1).replace(".", "")
            }
        _state.update { it.copy(hourlyRate = sanitized, errorMessage = null) }
    }

    fun onYearsChange(value: String) {
        _state.update { it.copy(yearsExperience = value.filter { c -> c in '0'..'9' }, errorMessage = null) }
    }

    fun onServiceAreasChange(value: String) {
        _state.update { it.copy(serviceAreas = value, errorMessage = null) }
    }

    fun onSpecializationsChange(value: String) {
        _state.update { it.copy(specializations = value, errorMessage = null) }
    }

    fun onBioChange(value: String) {
        _state.update { it.copy(bio = value, errorMessage = null) }
    }

    fun onAvailableChange(value: Boolean) {
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
            .onFailure { error ->
                _state.update { it.copy(loading = false, errorMessage = error.toUserMessage()) }
            }
    }

}

internal const val BIO_MIN_LEN = 20

private fun parseList(raw: String): List<String> =
    raw.split(',').map { it.trim() }.filter { it.isNotBlank() }

// Strip trailing zero noise from "75.0" -> "75" while keeping "75.5".
private fun formatRate(value: Double): String {
    val asLong = value.toLong()
    return if (value == asLong.toDouble()) asLong.toString() else value.toString()
}
