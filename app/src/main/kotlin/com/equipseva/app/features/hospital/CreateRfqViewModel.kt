package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.rfq.RfqInsertDto
import com.equipseva.app.core.data.rfq.RfqRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
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
class CreateRfqViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val rfqRepository: RfqRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    data class UiState(
        val title: String = "",
        val description: String = "",
        val equipmentType: String = "",
        val quantity: String = "1",
        val budgetMin: String = "",
        val budgetMax: String = "",
        // ISO-8601 date string ("yyyy-MM-dd") or null when not set.
        val expectedDeliveryIso: String? = null,
        val deliveryLocation: String = "",
        val submitting: Boolean = false,
        val showValidationErrors: Boolean = false,
        val errorMessage: String? = null,
        val titleError: String? = null,
        val descriptionError: String? = null,
        val equipmentTypeError: String? = null,
        val quantityError: String? = null,
        val budgetError: String? = null,
        val deliveryError: String? = null,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data object NavigateBack : Effect
    }

    private val _state = MutableStateFlow(
        UiState(
            title = savedStateHandle
                .get<String>(Routes.HOSPITAL_CREATE_RFQ_ARG_TITLE).orEmpty(),
            equipmentType = savedStateHandle
                .get<String>(Routes.HOSPITAL_CREATE_RFQ_ARG_TYPE).orEmpty(),
            description = savedStateHandle
                .get<String>(Routes.HOSPITAL_CREATE_RFQ_ARG_DESC).orEmpty(),
        )
    )
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

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

    fun onTitleChange(value: String) = _state.update { it.copy(title = value, titleError = null, errorMessage = null) }

    fun onDescriptionChange(value: String) =
        _state.update { it.copy(description = value, descriptionError = null, errorMessage = null) }

    fun onEquipmentTypeChange(value: String) =
        _state.update { it.copy(equipmentType = value, equipmentTypeError = null, errorMessage = null) }

    fun onQuantityChange(value: String) {
        val sanitized = value.filter { it.isDigit() }.take(6)
        _state.update { it.copy(quantity = sanitized, quantityError = null, errorMessage = null) }
    }

    fun onBudgetMinChange(value: String) =
        _state.update { it.copy(budgetMin = sanitizeMoney(value), budgetError = null, errorMessage = null) }

    fun onBudgetMaxChange(value: String) =
        _state.update { it.copy(budgetMax = sanitizeMoney(value), budgetError = null, errorMessage = null) }

    fun onDeliveryDateSelected(iso: String?) =
        _state.update { it.copy(expectedDeliveryIso = iso, deliveryError = null, errorMessage = null) }

    fun onDeliveryLocationChange(value: String) =
        _state.update { it.copy(deliveryLocation = value, errorMessage = null) }

    fun onSubmit() {
        val current = _state.value
        if (current.submitting) return

        val title = current.title.trim()
        val description = current.description.trim()
        val equipmentType = current.equipmentType.trim()
        val quantity = current.quantity.toIntOrNull()
        val budgetMin = current.budgetMin.toDoubleOrNullSafe()
        val budgetMax = current.budgetMax.toDoubleOrNullSafe()
        val deliveryIso = current.expectedDeliveryIso

        val titleError = if (title.isBlank()) "Title is required." else null
        val descriptionError = when {
            description.isBlank() -> "Description is required."
            description.length < 20 -> "Add at least 20 characters of detail."
            else -> null
        }
        val equipmentTypeError = if (equipmentType.isBlank()) "Equipment type is required." else null
        val quantityError = when {
            quantity == null -> "Enter a valid quantity."
            quantity < 1 -> "Quantity must be at least 1."
            else -> null
        }
        val budgetError = when {
            current.budgetMin.isNotBlank() && budgetMin == null -> "Min budget is not a valid number."
            current.budgetMax.isNotBlank() && budgetMax == null -> "Max budget is not a valid number."
            budgetMin != null && budgetMax != null && budgetMin > budgetMax ->
                "Min budget can't exceed max budget."
            else -> null
        }
        val deliveryError = if (deliveryIso == null) "Pick an expected delivery date." else null

        val anyError = listOf(
            titleError,
            descriptionError,
            equipmentTypeError,
            quantityError,
            budgetError,
            deliveryError,
        ).any { it != null }

        if (anyError) {
            _state.update {
                it.copy(
                    showValidationErrors = true,
                    titleError = titleError,
                    descriptionError = descriptionError,
                    equipmentTypeError = equipmentTypeError,
                    quantityError = quantityError,
                    budgetError = budgetError,
                    deliveryError = deliveryError,
                )
            }
            return
        }

        val uid = userId
        val oid = orgId
        if (uid == null) {
            _state.update { it.copy(errorMessage = "Sign in again and retry.") }
            return
        }
        if (oid == null) {
            _state.update {
                it.copy(errorMessage = "Your account isn't linked to a hospital. Update your profile and try again.")
            }
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            val payload = RfqInsertDto(
                requesterOrgId = oid,
                requesterUserId = uid,
                title = title,
                description = description,
                equipmentCategory = equipmentType,
                quantity = quantity ?: 1,
                budgetRangeMin = budgetMin,
                budgetRangeMax = budgetMax,
                deliveryDeadline = deliveryIso,
                deadline = deliveryIso!!,
                deliveryLocation = current.deliveryLocation.trim().ifBlank { null },
            )
            rfqRepository.createRfq(payload)
                .onSuccess {
                    _effects.send(Effect.ShowMessage("RFQ created"))
                    _effects.send(Effect.NavigateBack)
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(submitting = false, errorMessage = error.toUserMessage())
                    }
                }
        }
    }

    private fun sanitizeMoney(value: String): String {
        // Allow digits + a single decimal point.
        var seenDot = false
        val sb = StringBuilder()
        for (c in value) {
            when {
                c.isDigit() -> sb.append(c)
                c == '.' && !seenDot -> {
                    seenDot = true
                    sb.append(c)
                }
            }
        }
        return sb.toString().take(12)
    }

    private fun String.toDoubleOrNullSafe(): Double? =
        if (isBlank()) null else toDoubleOrNull()
}
