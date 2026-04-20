package com.equipseva.app.features.hospital

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJobDraft
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobUrgency
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
class RequestServiceViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val jobRepository: RepairJobRepository,
) : ViewModel() {

    data class UiState(
        val category: RepairEquipmentCategory = RepairEquipmentCategory.ImagingRadiology,
        val urgency: RepairJobUrgency = RepairJobUrgency.Scheduled,
        val brand: String = "",
        val model: String = "",
        val issue: String = "",
        val submitting: Boolean = false,
        val errorMessage: String? = null,
        val issueError: String? = null,
    )

    sealed interface Effect {
        data object Submitted : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val effectChannel = Channel<Effect>(Channel.BUFFERED)
    val effects = effectChannel.receiveAsFlow()

    private var userId: String? = null
    private var orgId: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    orgId = profileRepository.fetchById(session.userId).getOrNull()?.organizationId
                }
        }
    }

    fun onCategoryChange(value: RepairEquipmentCategory) = _state.update { it.copy(category = value) }
    fun onUrgencyChange(value: RepairJobUrgency) = _state.update { it.copy(urgency = value) }
    fun onBrandChange(value: String) = _state.update { it.copy(brand = value) }
    fun onModelChange(value: String) = _state.update { it.copy(model = value) }
    fun onIssueChange(value: String) = _state.update { it.copy(issue = value, issueError = null) }

    fun onSubmit() {
        val uid = userId
        if (uid == null) {
            _state.update { it.copy(errorMessage = "Sign in again and retry.") }
            return
        }
        val current = _state.value
        val issue = current.issue.trim()
        if (issue.length < 10) {
            _state.update { it.copy(issueError = "Please describe the issue (10 characters or more).") }
            return
        }
        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            val draft = RepairJobDraft(
                hospitalUserId = uid,
                hospitalOrgId = orgId,
                issueDescription = issue,
                equipmentCategory = current.category,
                equipmentBrand = current.brand.trim().ifBlank { null },
                equipmentModel = current.model.trim().ifBlank { null },
                urgency = current.urgency.takeIf { it != RepairJobUrgency.Unknown } ?: RepairJobUrgency.Scheduled,
            )
            jobRepository.create(draft)
                .onSuccess {
                    _state.update {
                        UiState()
                    }
                    effectChannel.trySend(Effect.Submitted)
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(submitting = false, errorMessage = error.toUserMessage())
                    }
                }
        }
    }
}
