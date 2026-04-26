package com.equipseva.app.features.supplier

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.catalog.CatalogReferenceRepository
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.core.data.parts.SparePartInsertDto
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AddListingViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val partsRepository: SparePartsRepository,
    private val storage: StorageRepository,
    private val catalogRepo: CatalogReferenceRepository,
) : ViewModel() {

    companion object {
        const val MAX_IMAGES = 5
    }

    data class FormState(
        val name: String = "",
        val partNumber: String = "",
        val category: PartCategory = PartCategory.Other,
        val priceText: String = "",
        val stockQuantityText: String = "",
        val description: String = "",
        val mrpText: String = "",
        val gstRateText: String = "18.0",
        val warrantyMonthsText: String = "0",
        val sku: String = "",
        val hsnCode: String = "",
        val isGenuine: Boolean = false,
        val isOem: Boolean = false,
        val discountPercentText: String = "0",
        val compatibleBrandsText: String = "",
        val compatibleModelsText: String = "",
        val compatibleEquipmentCategoriesText: String = "",
        /** "spare_part" or "equipment" — drives which fields are emphasised + DB column. */
        val listingType: String = "spare_part",
    ) {
        val nameError: String?
            get() = if (name.isBlank()) "Required" else null
        val partNumberError: String?
            get() = if (partNumber.isBlank()) "Required" else null
        val priceError: String?
            get() = when {
                priceText.isBlank() -> "Required"
                priceText.toDoubleOrNull() == null -> "Enter a valid number"
                (priceText.toDoubleOrNull() ?: 0.0) <= 0.0 -> "Must be greater than 0"
                else -> null
            }
        val stockQuantityError: String?
            get() = when {
                stockQuantityText.isBlank() -> "Required"
                stockQuantityText.toIntOrNull() == null -> "Enter a whole number"
                (stockQuantityText.toIntOrNull() ?: -1) < 0 -> "Cannot be negative"
                else -> null
            }
        // Optional fields — only flag if user typed garbage.
        val mrpError: String?
            get() = if (mrpText.isBlank()) null
            else if (mrpText.toDoubleOrNull() == null) "Enter a valid number" else null
        val gstRateError: String?
            get() = if (gstRateText.isBlank()) null
            else if (gstRateText.toDoubleOrNull() == null) "Enter a valid number" else null
        val warrantyMonthsError: String?
            get() = if (warrantyMonthsText.isBlank()) null
            else if (warrantyMonthsText.toIntOrNull() == null) "Enter a whole number" else null

        val discountPercentError: String?
            get() = if (discountPercentText.isBlank()) null
            else {
                val v = discountPercentText.toIntOrNull()
                if (v == null) "Enter a whole number"
                else if (v !in 0..99) "Must be 0–99"
                else null
            }

        val isValid: Boolean
            get() = listOf(
                nameError, partNumberError, priceError, stockQuantityError,
                mrpError, gstRateError, warrantyMonthsError, discountPercentError,
            ).all { it == null }
    }

    data class UiState(
        val form: FormState = FormState(),
        val submitting: Boolean = false,
        val showValidationErrors: Boolean = false,
        val noOrgWarning: Boolean = false,
        val errorMessage: String? = null,
        /** True after the verification gate fails (server says seller_can_list=false). */
        val verificationGate: Boolean = false,
        val imageUrls: List<String> = emptyList(),
        val uploadingImage: Boolean = false,
        /** Catalog picker bottom-sheet state. */
        val catalogPickerOpen: Boolean = false,
        val catalogQuery: String = "",
        val catalogResults: List<CatalogReferenceRepository.Item> = emptyList(),
        val catalogSearching: Boolean = false,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data object NavigateBack : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    private var userId: String? = null
    private var supplierOrgId: String? = null

    init {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            userId = session.userId
            // Resolve supplier_org_id from the user's profile (matches the pattern
            // used by MyListingsViewModel — Profile.organizationId is the supplier org).
            // If null, RLS will reject the insert and we'll surface the error.
            val orgId = profileRepository.fetchById(session.userId).getOrNull()?.organizationId
            supplierOrgId = orgId
            if (orgId.isNullOrBlank()) {
                _state.update { it.copy(noOrgWarning = true) }
            }
        }
    }

    fun onNameChange(value: String) = updateForm { it.copy(name = value) }
    fun onPartNumberChange(value: String) = updateForm { it.copy(partNumber = value) }
    fun onCategoryChange(category: PartCategory) = updateForm { it.copy(category = category) }
    fun onPriceChange(value: String) = updateForm { it.copy(priceText = value.filterDecimal()) }
    fun onStockQuantityChange(value: String) =
        updateForm { it.copy(stockQuantityText = value.filter { c -> c.isDigit() }) }
    fun onDescriptionChange(value: String) = updateForm { it.copy(description = value) }
    fun onMrpChange(value: String) = updateForm { it.copy(mrpText = value.filterDecimal()) }
    fun onGstRateChange(value: String) = updateForm { it.copy(gstRateText = value.filterDecimal()) }
    fun onWarrantyMonthsChange(value: String) =
        updateForm { it.copy(warrantyMonthsText = value.filter { c -> c.isDigit() }) }
    fun onSkuChange(value: String) = updateForm { it.copy(sku = value) }
    fun onHsnCodeChange(value: String) = updateForm { it.copy(hsnCode = value) }
    fun onIsGenuineChange(value: Boolean) = updateForm { it.copy(isGenuine = value) }
    fun onIsOemChange(value: Boolean) = updateForm { it.copy(isOem = value) }
    fun onDiscountPercentChange(value: String) =
        updateForm { it.copy(discountPercentText = value.filter { c -> c.isDigit() }.take(2)) }
    fun onCompatibleBrandsChange(value: String) = updateForm { it.copy(compatibleBrandsText = value) }
    fun onCompatibleModelsChange(value: String) = updateForm { it.copy(compatibleModelsText = value) }
    fun onCompatibleEquipmentCategoriesChange(value: String) =
        updateForm { it.copy(compatibleEquipmentCategoriesText = value) }
    fun onListingTypeChange(type: String) =
        updateForm { it.copy(listingType = if (type == "equipment") "equipment" else "spare_part") }

    // ─────────────────────────────────────────────────────────────────────────
    // Catalog picker (modal bottom sheet) — lets the seller pull a row from
    // catalog_reference_items and prefill the listing form. Saves them
    // re-typing brand / model / specs that we already have on the server.

    private var catalogJob: Job? = null

    fun openCatalogPicker() {
        _state.update { it.copy(catalogPickerOpen = true) }
        // Seed with a generic search so the sheet isn't empty when it opens.
        searchCatalog("")
    }

    fun closeCatalogPicker() {
        catalogJob?.cancel()
        _state.update { it.copy(catalogPickerOpen = false, catalogQuery = "", catalogResults = emptyList()) }
    }

    fun onCatalogQueryChange(query: String) {
        _state.update { it.copy(catalogQuery = query) }
        catalogJob?.cancel()
        catalogJob = viewModelScope.launch {
            delay(250)
            searchCatalog(query)
        }
    }

    private fun searchCatalog(query: String) {
        catalogJob?.cancel()
        catalogJob = viewModelScope.launch {
            _state.update { it.copy(catalogSearching = true) }
            catalogRepo.search(query = query, limit = 30)
                .onSuccess { rows ->
                    _state.update { it.copy(catalogSearching = false, catalogResults = rows) }
                }
                .onFailure { ex ->
                    _state.update { it.copy(catalogSearching = false, errorMessage = ex.toUserMessage()) }
                }
        }
    }

    fun applyFromCatalog(item: CatalogReferenceRepository.Item) {
        // Map the wide-net catalogue category to our 5-bucket spare-part enum.
        val mappedCategory = when (item.category) {
            "Imaging" -> PartCategory.ImagingRadiology
            "ICU & Critical Care" -> PartCategory.LifeSupport
            "Surgical & OR" -> PartCategory.LifeSupport
            "Laboratory" -> PartCategory.Other
            "Ward & Allied" -> PartCategory.PatientMonitoring
            "Spare Parts & Consumables" -> PartCategory.Other
            else -> PartCategory.Other
        }
        // Capital Equipment + Refurbished Capital → list as "equipment".
        val listingType = when (item.type) {
            "Capital Equipment", "Refurbished Capital" -> "equipment"
            else -> "spare_part"
        }
        _state.update { s ->
            s.copy(
                form = s.form.copy(
                    name = item.itemName,
                    partNumber = item.model.orEmpty(),
                    category = mappedCategory,
                    listingType = listingType,
                    description = item.keySpecifications.orEmpty(),
                    compatibleBrandsText = item.brand.orEmpty(),
                    compatibleEquipmentCategoriesText = item.subCategory.orEmpty(),
                ),
                catalogPickerOpen = false,
                catalogQuery = "",
                catalogResults = emptyList(),
            )
        }
        emit(Effect.ShowMessage("Prefilled from catalogue: ${item.itemName}"))
    }

    fun addImage(fileName: String, bytes: ByteArray, contentType: String?) {
        val orgId = supplierOrgId
        if (orgId.isNullOrBlank()) {
            emit(Effect.ShowMessage("Link a supplier organization before uploading images."))
            return
        }
        val snap = _state.value
        if (snap.imageUrls.size >= MAX_IMAGES) {
            emit(Effect.ShowMessage("Up to $MAX_IMAGES images per listing."))
            return
        }
        if (snap.uploadingImage) return
        _state.update { it.copy(uploadingImage = true) }
        viewModelScope.launch {
            val safe = fileName.substringAfterLast('/').ifBlank { "image" }
                .replace(Regex("[^A-Za-z0-9._-]"), "_")
            val path = "$orgId/${System.currentTimeMillis()}-$safe"
            storage.upload(
                bucket = StorageRepository.Buckets.CATALOG_IMAGES,
                path = path,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = {
                    val url = storage.publicUrl(StorageRepository.Buckets.CATALOG_IMAGES, path)
                    _state.update {
                        it.copy(uploadingImage = false, imageUrls = it.imageUrls + url)
                    }
                },
                onFailure = { ex ->
                    _state.update { it.copy(uploadingImage = false) }
                    emit(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    fun removeImage(url: String) {
        _state.update { it.copy(imageUrls = it.imageUrls.filterNot { u -> u == url }) }
    }

    fun onSave() {
        val snap = _state.value
        if (!snap.form.isValid) {
            _state.update { it.copy(showValidationErrors = true) }
            return
        }
        val form = snap.form
        val payload = SparePartInsertDto(
            supplierOrgId = supplierOrgId,
            name = form.name.trim(),
            partNumber = form.partNumber.trim(),
            category = form.category.storageKey,
            price = form.priceText.toDouble(),
            stockQuantity = form.stockQuantityText.toInt(),
            description = form.description.trim().takeIf { it.isNotBlank() },
            compatibleBrands = form.compatibleBrandsText.toTagList().takeIf { it.isNotEmpty() },
            compatibleModels = form.compatibleModelsText.toTagList().takeIf { it.isNotEmpty() },
            compatibleEquipmentCategories = form.compatibleEquipmentCategoriesText.toTagList().takeIf { it.isNotEmpty() },
            mrp = form.mrpText.toDoubleOrNull(),
            gstRate = form.gstRateText.toDoubleOrNull() ?: 18.0,
            warrantyMonths = form.warrantyMonthsText.toIntOrNull() ?: 0,
            sku = form.sku.trim().takeIf { it.isNotBlank() },
            hsnCode = form.hsnCode.trim().takeIf { it.isNotBlank() },
            isGenuine = form.isGenuine,
            isOem = form.isOem,
            discountPercentage = form.discountPercentText.toIntOrNull() ?: 0,
            listingType = form.listingType,
            images = snap.imageUrls.takeIf { it.isNotEmpty() },
        )

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            partsRepository.insertListing(payload)
                .onSuccess {
                    _state.update { it.copy(submitting = false) }
                    emit(Effect.ShowMessage("Listing added"))
                    emit(Effect.NavigateBack)
                }
                .onFailure { error ->
                    val message = error.toUserMessage()
                    _state.update {
                        it.copy(submitting = false, errorMessage = message)
                    }
                    emit(Effect.ShowMessage(message))
                }
        }
    }

    private fun updateForm(block: (FormState) -> FormState) {
        _state.update { it.copy(form = block(it.form)) }
    }

    private fun emit(effect: Effect) {
        viewModelScope.launch { _effects.send(effect) }
    }

    /** Split a comma-separated string into a trimmed, non-blank list of tags. */
    private fun String.toTagList(): List<String> =
        split(',').map { it.trim() }.filter { it.isNotBlank() }

    /** Keep digits and at most one decimal point — guards against bogus input. */
    private fun String.filterDecimal(): String {
        val cleaned = filter { it.isDigit() || it == '.' }
        val firstDot = cleaned.indexOf('.')
        return if (firstDot == -1) cleaned
        else cleaned.substring(0, firstDot + 1) +
            cleaned.substring(firstDot + 1).filter { it.isDigit() }
    }
}
