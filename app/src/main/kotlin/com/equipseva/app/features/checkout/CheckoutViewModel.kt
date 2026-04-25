package com.equipseva.app.features.checkout

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.cart.CartItem
import com.equipseva.app.core.data.cart.CartRepository
import com.equipseva.app.core.data.orders.OrderDraft
import com.equipseva.app.core.data.orders.OrderLineItem
import com.equipseva.app.core.data.orders.NonTerminalOrderStatus
import com.equipseva.app.core.data.orders.NonTerminalPaymentStatus
import com.equipseva.app.core.data.orders.OrderRepository
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.payments.PaymentResult
import com.equipseva.app.core.payments.PaymentVerificationRepository
import com.equipseva.app.core.payments.RazorpayLauncher
import com.equipseva.app.core.security.PlayIntegrityClient
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
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
class CheckoutViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val cartRepository: CartRepository,
    private val partsRepository: SparePartsRepository,
    private val orderRepository: OrderRepository,
    private val razorpayLauncher: RazorpayLauncher,
    private val paymentVerification: PaymentVerificationRepository,
    private val playIntegrityClient: PlayIntegrityClient,
) : ViewModel() {

    data class FormState(
        val fullName: String = "",
        val phone: String = "",
        val addressLine: String = "",
        val city: String = "",
        val state: String = "",
        val pincode: String = "",
    ) {
        val fullNameError: String?
            get() = if (fullName.isBlank()) "Required" else null
        val phoneError: String?
            get() = when {
                phone.isBlank() -> "Required"
                phone.filter { it.isDigit() }.length < 10 -> "Enter a 10-digit phone"
                else -> null
            }
        val addressError: String? get() = if (addressLine.isBlank()) "Required" else null
        val cityError: String? get() = if (city.isBlank()) "Required" else null
        val stateError: String? get() = if (state.isBlank()) "Required" else null
        val pincodeError: String?
            get() = when {
                pincode.isBlank() -> "Required"
                pincode.length != 6 || pincode.any { !it.isDigit() } -> "Enter a 6-digit PIN"
                else -> null
            }
        val isValid: Boolean
            get() = listOf(
                fullNameError, phoneError, addressError,
                cityError, stateError, pincodeError,
            ).all { it == null }
    }

    data class UiState(
        val loading: Boolean = true,
        val items: List<CartItem> = emptyList(),
        val snapshot: List<LineSnapshot> = emptyList(),
        val subtotalRupees: Double = 0.0,
        val gstRupees: Double = 0.0,
        val shippingRupees: Double = 0.0,
        val totalRupees: Double = 0.0,
        val form: FormState = FormState(),
        val submitting: Boolean = false,
        val showValidationErrors: Boolean = false,
        val supplierConflict: Boolean = false,
        val prefilledEmail: String? = null,
        val errorMessage: String? = null,
    )

    /** Cart line zipped with the up-to-date part snapshot. */
    data class LineSnapshot(
        val item: CartItem,
        val part: SparePart,
    ) {
        val lineSubtotalRupees: Double get() = (item.unitPriceInPaise / 100.0) * item.quantity
        val lineGstRupees: Double get() = lineSubtotalRupees * (part.gstRatePercent / 100.0)
    }

    sealed interface Effect {
        data class LaunchRazorpay(val request: RazorpayLauncher.CheckoutRequest) : Effect
        data class OpenOrder(val orderId: String) : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    private var profile: Profile? = null
    private var userId: String? = null
    private var pendingOrderId: String? = null

    init {
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .first()
            userId = session.userId
            loadProfileAndCart(session.userId, session.email)
        }
    }

    fun onFullNameChange(value: String) = updateForm { it.copy(fullName = value) }
    fun onPhoneChange(value: String) = updateForm { it.copy(phone = value.filter { c -> c.isDigit() }.take(10)) }
    fun onAddressChange(value: String) = updateForm { it.copy(addressLine = value) }
    fun onCityChange(value: String) = updateForm { it.copy(city = value) }
    fun onStateChange(value: String) = updateForm { it.copy(state = value) }
    fun onPincodeChange(value: String) = updateForm { it.copy(pincode = value.filter { c -> c.isDigit() }.take(6)) }

    fun onPlaceOrder() {
        val snap = _state.value
        if (snap.submitting) return
        if (!snap.form.isValid) {
            _state.update { it.copy(showValidationErrors = true) }
            return
        }
        if (snap.items.isEmpty() || snap.snapshot.isEmpty()) {
            emit(Effect.ShowMessage("Your cart is empty"))
            return
        }
        if (snap.supplierConflict) {
            emit(Effect.ShowMessage("Please order from one supplier at a time"))
            return
        }
        if (!razorpayLauncher.isConfigured()) {
            emit(Effect.ShowMessage("Payments aren't configured. Add RAZORPAY_KEY and rebuild."))
            return
        }
        val supplierOrgId = snap.snapshot.firstOrNull()?.part?.supplierOrgId
        if (supplierOrgId.isNullOrBlank()) {
            emit(Effect.ShowMessage("Supplier info missing for this order"))
            return
        }
        val uid = userId ?: run {
            emit(Effect.ShowMessage("Please sign in to continue"))
            return
        }

        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            // Server-verified Play Integrity check before we mint a Razorpay
            // order. On debug builds [requestVerification] always succeeds so
            // devs can test without Play setup; on release a hard failure
            // aborts checkout with FAILURE_MESSAGE.
            val integrity = playIntegrityClient.requestVerification("checkout")
            val pass = integrity.getOrDefault(false)
            if (!pass) {
                _state.update {
                    it.copy(submitting = false, errorMessage = PlayIntegrityClient.FAILURE_MESSAGE)
                }
                emit(Effect.ShowMessage(PlayIntegrityClient.FAILURE_MESSAGE))
                return@launch
            }
            // Refresh the JWT before talking to create-razorpay-order; the
            // session-status flow auto-refreshes in the background but isn't
            // guaranteed to fire before THIS RPC. Best-effort — if refresh
            // fails, the existing token will be used and Razorpay will return
            // 401 only if it's actually expired.
            runCatching { authRepository.refreshSession() }
            val draft = OrderDraft(
                buyerUserId = uid,
                supplierOrgId = supplierOrgId,
                items = snap.snapshot.map { line ->
                    OrderLineItem(
                        partId = line.part.id,
                        name = line.part.name,
                        partNumber = line.part.partNumber,
                        quantity = line.item.quantity,
                        unitPriceRupees = line.item.unitPriceInPaise / 100.0,
                        gstRatePercent = line.part.gstRatePercent,
                        imageUrl = line.part.primaryImageUrl,
                    )
                },
                subtotalRupees = snap.subtotalRupees,
                gstRupees = snap.gstRupees,
                shippingRupees = snap.shippingRupees,
                totalRupees = snap.totalRupees,
                shippingAddress = snap.form.addressLine,
                shippingCity = snap.form.city,
                shippingState = snap.form.state,
                shippingPincode = snap.form.pincode,
            )
            orderRepository.insert(draft)
                .onSuccess { order ->
                    pendingOrderId = order.id
                    paymentVerification.createRazorpayOrder(
                        PaymentVerificationRepository.CreateRequest(orderId = order.id),
                    )
                        .onSuccess { created ->
                            val expectedPaise = (snap.totalRupees * 100).toLong()
                            if (kotlin.math.abs(created.amount - expectedPaise) > 1L) {
                                // Server saw a different total than the client tallied — either
                                // a price drift between cart view and checkout, or tampering.
                                // Either way, stop and make the user refresh.
                                orderRepository.cancelOrder(order.id)
                                _state.update {
                                    it.copy(
                                        submitting = false,
                                        errorMessage = "Price changed, please retry",
                                    )
                                }
                                emit(Effect.ShowMessage("Price changed, please retry"))
                                return@onSuccess
                            }
                            val request = RazorpayLauncher.CheckoutRequest(
                                orderId = order.id,
                                razorpayOrderId = created.razorpayOrderId,
                                orderNumber = order.orderNumber,
                                amountInPaise = created.amount,
                                buyerName = snap.form.fullName,
                                buyerEmail = snap.prefilledEmail,
                                buyerPhone = snap.form.phone,
                                description = order.orderNumber?.let { "Order $it" } ?: "EquipSeva order",
                            )
                            emit(Effect.LaunchRazorpay(request))
                        }
                        .onFailure { error ->
                            _state.update {
                                it.copy(submitting = false, errorMessage = error.toUserMessage())
                            }
                            emit(Effect.ShowMessage(error.toUserMessage()))
                        }
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(submitting = false, errorMessage = error.toUserMessage())
                    }
                    emit(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    /** Activity-scoped bridge: callers hold the Activity, VM holds the launcher. */
    suspend fun launchRazorpay(
        activity: android.app.Activity,
        request: RazorpayLauncher.CheckoutRequest,
    ): PaymentResult = razorpayLauncher.launch(activity, request)

    fun onPaymentResult(result: PaymentResult) {
        viewModelScope.launch {
            when (result) {
                is PaymentResult.Success -> {
                    paymentVerification.verify(
                        PaymentVerificationRepository.VerifyRequest(
                            orderId = result.orderId,
                            razorpayOrderId = result.razorpayOrderId,
                            razorpayPaymentId = result.razorpayPaymentId,
                            razorpaySignature = result.razorpaySignature,
                        ),
                    )
                        .onSuccess {
                            cartRepository.clear()
                            _state.update { it.copy(submitting = false) }
                            emit(Effect.OpenOrder(result.orderId))
                        }
                        .onFailure { error ->
                            // Signature mismatch or server refusal. Do NOT mark completed
                            // client-side — RLS would refuse and UI would mislead the user.
                            // Order stays in whatever state the server left it; buyer is told
                            // to contact support and routed to the order detail.
                            _state.update { it.copy(submitting = false) }
                            emit(Effect.ShowMessage(
                                "Payment received but verification failed. " +
                                    "Contact support if the amount is debited.",
                            ))
                            emit(Effect.OpenOrder(result.orderId))
                        }
                }
                is PaymentResult.Failure -> {
                    orderRepository.markPaymentOutcome(
                        id = result.orderId,
                        paymentStatus = NonTerminalPaymentStatus.FAILED,
                        orderStatus = null,
                    )
                    _state.update { it.copy(submitting = false) }
                    emit(Effect.ShowMessage("Payment failed: ${result.description}"))
                    emit(Effect.OpenOrder(result.orderId))
                }
                is PaymentResult.Cancelled -> {
                    orderRepository.markPaymentOutcome(
                        id = result.orderId,
                        paymentStatus = NonTerminalPaymentStatus.PENDING,
                        orderStatus = NonTerminalOrderStatus.CANCELLED,
                    )
                    _state.update { it.copy(submitting = false) }
                    emit(Effect.ShowMessage("Payment cancelled"))
                }
            }
        }
    }

    private fun updateForm(block: (FormState) -> FormState) {
        _state.update { it.copy(form = block(it.form)) }
    }

    private fun emit(effect: Effect) {
        viewModelScope.launch { _effects.send(effect) }
    }

    private suspend fun loadProfileAndCart(userId: String, fallbackEmail: String?) {
        val profileResult = profileRepository.fetchById(userId)
        profile = profileResult.getOrNull()
        val items = cartRepository.observe().first()
        val snapshots = buildList {
            items.forEach { item ->
                val part = partsRepository.fetchById(item.partId).getOrNull()
                if (part != null) add(LineSnapshot(item, part))
            }
        }
        val subtotal = snapshots.sumOf { it.lineSubtotalRupees }
        val gst = snapshots.sumOf { it.lineGstRupees }
        val shipping = 0.0
        val total = subtotal + gst + shipping
        val suppliers = snapshots.mapNotNull { it.part.supplierOrgId }.toSet()

        val initialForm = FormState(
            fullName = profile?.fullName.orEmpty(),
            phone = profile?.phone.orEmpty(),
            addressLine = "",
            city = profile?.organizationCity.orEmpty(),
            state = profile?.organizationState.orEmpty(),
            pincode = "",
        )
        _state.update {
            it.copy(
                loading = false,
                items = items,
                snapshot = snapshots,
                subtotalRupees = subtotal,
                gstRupees = gst,
                shippingRupees = shipping,
                totalRupees = total,
                form = initialForm,
                supplierConflict = suppliers.size > 1,
                prefilledEmail = profile?.email ?: fallbackEmail,
            )
        }
    }
}
