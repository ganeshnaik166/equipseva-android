package com.equipseva.app.features.scan

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

/**
 * AI-driven identification is not live yet. Until the Vision Edge Function
 * ships, the screen captures a photo for the user's reference and lets them
 * type the brand/model themselves so they can jump into the parts marketplace
 * with a real query. No fabricated results — it asks rather than guesses.
 */
@HiltViewModel
class ScanEquipmentViewModel @Inject constructor() : ViewModel() {

    data class ManualEntry(
        val brand: String = "",
        val model: String = "",
    ) {
        val canSearch: Boolean get() = brand.isNotBlank() || model.isNotBlank()
        val searchQuery: String
            get() = listOf(brand, model).map { it.trim() }.filter { it.isNotBlank() }.joinToString(" ")
    }

    data class UiState(
        val thumbnail: Bitmap? = null,
        val captured: Boolean = false,
        val entry: ManualEntry = ManualEntry(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onCaptured(bitmap: Bitmap?) {
        if (bitmap == null) return
        _state.update { it.copy(thumbnail = bitmap, captured = true) }
    }

    fun onBrandChange(value: String) {
        _state.update { it.copy(entry = it.entry.copy(brand = value)) }
    }

    fun onModelChange(value: String) {
        _state.update { it.copy(entry = it.entry.copy(model = value)) }
    }

    fun onRetake() {
        _state.update { UiState() }
    }
}
