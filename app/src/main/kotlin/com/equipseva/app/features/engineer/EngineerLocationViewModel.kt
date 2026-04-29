package com.equipseva.app.features.engineer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerLocationViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val saving: Boolean = false,
        val errorMessage: String? = null,
        val savedLatitude: Double? = null,
        val savedLongitude: Double? = null,
        val pickedLatitude: Double? = null,
        val pickedLongitude: Double? = null,
    ) {
        val canSave: Boolean
            get() = !loading && !saving &&
                pickedLatitude != null && pickedLongitude != null &&
                (pickedLatitude != savedLatitude || pickedLongitude != savedLongitude)
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
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            if (session == null) {
                _state.update { it.copy(loading = false) }
                return@launch
            }
            userId = session.userId
            engineerRepository.fetchByUserId(session.userId)
                .onSuccess { engineer ->
                    _state.update {
                        it.copy(
                            loading = false,
                            savedLatitude = engineer?.latitude,
                            savedLongitude = engineer?.longitude,
                            pickedLatitude = engineer?.latitude,
                            pickedLongitude = engineer?.longitude,
                        )
                    }
                }
                .onFailure { ex ->
                    _state.update { it.copy(loading = false, errorMessage = ex.toUserMessage()) }
                }
        }
    }

    fun onPick(latitude: Double, longitude: Double) {
        _state.update {
            it.copy(
                pickedLatitude = latitude,
                pickedLongitude = longitude,
                errorMessage = null,
            )
        }
    }

    fun onSave() {
        val current = _state.value
        if (!current.canSave) return
        val uid = userId ?: return
        val lat = current.pickedLatitude ?: return
        val lng = current.pickedLongitude ?: return
        _state.update { it.copy(saving = true, errorMessage = null) }
        viewModelScope.launch {
            engineerRepository.updateBaseLocation(uid, lat, lng)
                .onSuccess {
                    _state.update {
                        it.copy(
                            saving = false,
                            savedLatitude = lat,
                            savedLongitude = lng,
                        )
                    }
                    _effects.send(Effect.ShowMessage("Service location updated"))
                    _effects.send(Effect.NavigateBack)
                }
                .onFailure { ex ->
                    _state.update { it.copy(saving = false, errorMessage = ex.toUserMessage()) }
                }
        }
    }
}
