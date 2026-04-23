package com.equipseva.app.features.scan

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ScanEquipmentViewModel @Inject constructor() : ViewModel() {

    data class ScanResult(
        val brand: String,
        val model: String,
        val category: String,
        val confidence: Float,
    )

    data class UiState(
        val thumbnail: Bitmap? = null,
        val scanning: Boolean = false,
        val result: ScanResult? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onCaptured(bitmap: Bitmap?) {
        if (bitmap == null) {
            _state.update { it.copy(scanning = false) }
            return
        }
        _state.update { it.copy(thumbnail = bitmap, scanning = true, result = null) }
        viewModelScope.launch {
            // Phase 2: mocked identification. Real Claude vision call lands in Phase 3.
            delay(1200)
            _state.update {
                it.copy(
                    scanning = false,
                    result = mockResults.random(),
                )
            }
        }
    }

    fun onRetake() {
        _state.update { UiState() }
    }

    private companion object {
        val mockResults = listOf(
            ScanResult("GE Healthcare", "LOGIQ E9", "Ultrasound", confidence = 0.92f),
            ScanResult("Philips", "IntelliVue MX550", "Patient Monitor", confidence = 0.88f),
            ScanResult("Siemens", "ACUSON X700", "Ultrasound", confidence = 0.81f),
            ScanResult("Dräger", "Savina 300", "Ventilator", confidence = 0.79f),
            ScanResult("Mindray", "BeneHeart D6", "Defibrillator", confidence = 0.84f),
        )
    }
}
