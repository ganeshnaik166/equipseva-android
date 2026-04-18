package com.equipseva.app.features.marketplace

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PartDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repository: SparePartsRepository,
) : ViewModel() {

    data class PartDetailState(
        val loading: Boolean = true,
        val part: SparePart? = null,
        val errorMessage: String? = null,
        val notFound: Boolean = false,
    )

    private val partId: String =
        checkNotNull(savedState.get<String>(Routes.MARKETPLACE_DETAIL_ARG_ID)) {
            "PartDetailViewModel requires arg ${Routes.MARKETPLACE_DETAIL_ARG_ID}"
        }

    private val _state = MutableStateFlow(PartDetailState())
    val state: StateFlow<PartDetailState> = _state.asStateFlow()

    init {
        load()
    }

    fun retry() = load()

    private fun load() {
        _state.update { it.copy(loading = true, errorMessage = null, notFound = false) }
        viewModelScope.launch {
            repository.fetchById(partId).fold(
                onSuccess = { part ->
                    _state.update {
                        it.copy(
                            loading = false,
                            part = part,
                            notFound = part == null,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update { it.copy(loading = false, errorMessage = ex.toUserMessage()) }
                },
            )
        }
    }
}
