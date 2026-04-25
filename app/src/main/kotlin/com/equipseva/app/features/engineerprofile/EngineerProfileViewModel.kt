package com.equipseva.app.features.engineerprofile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.receiveAsFlow
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
        val ratingAvg: Double? = null,
        val totalJobs: Int? = null,
        val completionRate: Double? = null,
    ) {
        val canSave: Boolean
            get() = !saving && !loading && validate() == null

        fun validate(): String? {
            val rate = hourlyRate.trim().toDoubleOrNull()
            if (rate == null || rate <= 0.0) return "Enter an hourly rate greater than 0."
            val years = yearsExperience.trim().toIntOrNull()
            if (years == null || years !in 0..60) return "Years of experience must be between 0 and 60."
            if (parseList(serviceAreas).isEmpty()) return "Add at least one service area (comma-separated)."
            if (parseList(specializations).isEmpty()) return "Add at least one specialization (comma-separated)."
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

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    private var userId: String? = null

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
        // Allow only digits + a single decimal point.
        val sanitized = value.filter { it.isDigit() || it == '.' }
            .let { v ->
                val first = v.indexOf('.')
                if (first == -1) v else v.substring(0, first + 1) + v.substring(first + 1).replace(".", "")
            }
        _state.update { it.copy(hourlyRate = sanitized, errorMessage = null) }
    }

    fun onYearsChange(value: String) {
        _state.update { it.copy(yearsExperience = value.filter { c -> c.isDigit() }, errorMessage = null) }
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
                _effects.send(Effect.ShowMessage("Profile saved"))
                _effects.send(Effect.NavigateBack)
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
                    _state.update { it.copy(loading = false) }
                } else {
                    _state.update {
                        it.copy(
                            loading = false,
                            hourlyRate = engineer.hourlyRate?.let(::formatRate) ?: "",
                            yearsExperience = engineer.yearsExperience?.toString() ?: "",
                            serviceAreas = engineer.serviceAreas.joinToString(", "),
                            // Specializations on the existing row are typed enums (from KYC). Render them as
                            // their storage keys so the engineer can edit-as-text without losing prior choices.
                            specializations = engineer.specializations.joinToString(", ") { spec -> spec.storageKey },
                            bio = engineer.bio.orEmpty(),
                            isAvailable = engineer.isAvailable,
                            ratingAvg = engineer.ratingAvg,
                            totalJobs = engineer.totalJobs,
                            completionRate = engineer.completionRate,
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
