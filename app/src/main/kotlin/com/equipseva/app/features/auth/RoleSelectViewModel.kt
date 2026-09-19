package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.transform
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.IOException
import javax.inject.Inject

@HiltViewModel
class RoleSelectViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    enum class RoleSelectError { SessionUnavailable, Network, SaveFailed }
    sealed interface RoleSelectEffect {
        /** The host must re-fetch the profile before choosing the next gate. */
        data object RoleSaved : RoleSelectEffect
    }

    data class RoleSelectState(
        val roles: List<UserRole> = activeRoles,
        val selected: UserRole? = null,
        val form: FormUiState = FormUiState(),
        val error: RoleSelectError? = null,
        val saved: Boolean = false,
    ) {
        val canConfirm: Boolean
            get() = selected in activeRoles && !form.submitting && !saved
    }

    /**
     * AuthSession has no stable login ID. These generations cover observed
     * SignedOut/account changes, including same-account ABA. An upstream
     * StateFlow can conflate a whole boundary; local code cannot recover an
     * unobserved login identity or bind an already-started RPC's auth token.
     * Ownership and state changes are confined to viewModelScope's Main.
     */
    private data class Login(val userId: String, val generation: Long)
    private data class SaveRequest(val login: Login, val revision: Long, val role: UserRole)

    private var observedSession: AuthSession = AuthSession.Unknown
    private var loginGeneration = 0L
    private var currentLogin: Login? = null
    private var saveRevision = 0L
    private var activeRequest: SaveRequest? = null
    private var savedRequest: SaveRequest? = null
    private var saveJob: Job? = null

    private val _state = MutableStateFlow(RoleSelectState())
    val state: StateFlow<RoleSelectState> = _state.asStateFlow()

    private val _savedEffects = MutableSharedFlow<SaveRequest>(extraBufferCapacity = 4)
    // No replay. Check ownership at delivery too: an event may be queued while
    // the auth source changes before the screen's collector is scheduled.
    val effects: Flow<RoleSelectEffect> = _savedEffects.transform { request ->
        if (isSavedRequestLive(request)) emit(RoleSelectEffect.RoleSaved)
    }

    // Every field is initialized before Main.immediate can begin collecting.
    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                val previous = observedSession
                observedSession = session
                when (session) {
                    AuthSession.Unknown -> {
                        cancelRequest()
                        _state.value = _state.value.copy(
                            form = FormUiState(),
                            error = if (currentLogin != null) RoleSelectError.SessionUnavailable else _state.value.error,
                        )
                    }
                    AuthSession.SignedOut -> {
                        if (previous != AuthSession.SignedOut || currentLogin != null) {
                            resetLogin(null, RoleSelectError.SessionUnavailable)
                        }
                    }
                    is AuthSession.SignedIn -> {
                        if (session.userId.isBlank()) {
                            resetLogin(null, RoleSelectError.SessionUnavailable)
                        } else if (currentLogin?.userId != session.userId) {
                            resetLogin(session.userId, null)
                        } else if (_state.value.error == RoleSelectError.SessionUnavailable) {
                            // Unknown cancels a save, retains this login/choice,
                            // and allows a deliberate retry once auth resolves.
                            _state.value = _state.value.copy(error = null)
                        }
                    }
                }
            }
        }
    }

    private fun resetLogin(userId: String?, error: RoleSelectError?) {
        ++loginGeneration
        currentLogin = userId?.let { Login(it, loginGeneration) }
        savedRequest = null
        cancelRequest()
        _state.value = RoleSelectState(error = error)
    }

    private fun cancelRequest() {
        activeRequest = null
        saveJob?.cancel()
        saveJob = null
    }

    fun onRoleSelected(role: UserRole) {
        val current = _state.value
        if (role !in activeRoles || current.form.submitting || current.saved) return
        _state.value = current.copy(selected = role, error = null, form = FormUiState())
    }

    fun onConfirm() {
        val current = _state.value
        if (!current.canConfirm) return
        val role = current.selected ?: return
        val login = currentLogin
        if (login == null || observedSession !is AuthSession.SignedIn) {
            _state.value = current.copy(form = FormUiState(), error = RoleSelectError.SessionUnavailable)
            return
        }
        val request = SaveRequest(login, ++saveRevision, role)
        activeRequest = request
        _state.value = current.copy(form = FormUiState(submitting = true), error = null)
        saveJob = viewModelScope.launch {
            try {
                // Read one current emission, never wait for a future SignedIn.
                if (!isRequestLive(request)) return@launch
                // add_role is the allowed server operation and confirms the
                // role there. No device-global prefs or navigation authority.
                val result = profileRepository.addRole(role.storageKey)
                currentCoroutineContext().ensureActive()
                (result.exceptionOrNull() as? CancellationException)?.let { throw it }
                if (!isRequestLive(request)) return@launch
                if (result.isSuccess) {
                    savedRequest = request
                    _state.value = _state.value.copy(form = FormUiState(), error = null, saved = true)
                    if (isSavedRequestLive(request)) _savedEffects.tryEmit(request)
                } else {
                    publishFailure(request, result.exceptionOrNull())
                }
            } catch (ce: CancellationException) {
                throw ce
            } catch (error: Exception) {
                publishFailure(request, error)
            } finally {
                // Cancellation or an old completion cannot release B's save.
                if (ownsRequest(request)) {
                    activeRequest = null
                    saveJob = null
                    _state.value = _state.value.copy(form = FormUiState())
                }
            }
        }
    }

    /** Re-check the saved profile through the host without repeating add_role. */
    fun onCheckSavedRole() {
        val request = savedRequest ?: return
        viewModelScope.launch {
            if (isSavedRequestLive(request)) _savedEffects.tryEmit(request)
        }
    }

    /** Called before the host's explicit sign-out action; no sign-out I/O here. */
    fun cancelPendingSave() {
        cancelRequest()
        savedRequest = null
        _state.value = _state.value.copy(form = FormUiState(), saved = false)
    }

    private fun ownsRequest(request: SaveRequest): Boolean =
        viewModelScope.isActive && currentLogin == request.login && activeRequest == request

    private suspend fun isLoginLive(login: Login): Boolean {
        if (!viewModelScope.isActive || currentLogin != login || observedSession !is AuthSession.SignedIn) {
            return false
        }
        val live = authRepository.sessionState.first()
        currentCoroutineContext().ensureActive()
        return viewModelScope.isActive && currentLogin == login &&
            observedSession is AuthSession.SignedIn &&
            live is AuthSession.SignedIn && live.userId == login.userId
    }

    private suspend fun isRequestLive(request: SaveRequest): Boolean =
        isLoginLive(request.login) && ownsRequest(request)

    private suspend fun isSavedRequestLive(request: SaveRequest): Boolean =
        isLoginLive(request.login) && savedRequest == request && _state.value.saved

    private suspend fun publishFailure(request: SaveRequest, error: Throwable?) {
        if (!isRequestLive(request)) return
        _state.value = _state.value.copy(
            error = if (error is IOException) RoleSelectError.Network else RoleSelectError.SaveFailed,
        )
    }

    companion object {
        private val activeRoles = listOf(UserRole.HOSPITAL, UserRole.ENGINEER)
    }
}
