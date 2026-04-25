package com.equipseva.app.features.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.logistics.LogisticsJobRepository
import com.equipseva.app.core.data.orders.OrderRepository
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.rfq.RfqRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
    private val repairJobRepository: RepairJobRepository,
    private val repairBidRepository: RepairBidRepository,
    private val orderRepository: OrderRepository,
    private val sparePartsRepository: SparePartsRepository,
    private val rfqRepository: RfqRepository,
    private val logisticsJobRepository: LogisticsJobRepository,
) : ViewModel() {

    /** Per-role aggregated counts/sums shown across the dashboards. */
    data class DashboardData(
        // Hospital
        val activeRequestsCount: Int = 0,
        val recentOrdersCount: Int = 0,
        val deliveredOrdersCount: Int = 0,
        // Engineer
        val nearbyJobsCount: Int = 0,
        val activeWorkCount: Int = 0,
        val myBidsCount: Int = 0,
        val earningsRupees: Double = 0.0,
        val verified: Boolean = false,
        // Supplier
        val todayRevenueRupees: Double = 0.0,
        val pendingOrdersCount: Int = 0,
        val stockAlertsCount: Int = 0,
        val rfqInboxCount: Int = 0,
        val listingsCount: Int = 0,
        // Manufacturer
        val winRatePct: Int = 0,
        val assignedRfqsCount: Int = 0,
        val pipelineValueRupees: Double = 0.0,
        // Logistics
        val pickupQueueCount: Int = 0,
        val activeDeliveriesCount: Int = 0,
        val completedTodayCount: Int = 0,
        val loaded: Boolean = false,
    )

    data class UiState(
        val loading: Boolean = true,
        val greetingName: String = "there",
        val role: UserRole? = null,
        val errorMessage: String? = null,
        val dashboardData: DashboardData = DashboardData(),
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        viewModelScope.launch {
            combine(
                authRepository.sessionState
                    .filterIsInstance<AuthSession.SignedIn>(),
                userPrefs.activeRole.distinctUntilChanged(),
            ) { session, activeRoleKey -> session.userId to activeRoleKey }
                .distinctUntilChanged()
                .collect { (userId, activeRoleKey) ->
                    load(userId, activeRoleOverride = activeRoleKey)
                }
        }
    }

    fun onRetry() {
        viewModelScope.launch {
            val current = authRepository.sessionState.first()
            if (current is AuthSession.SignedIn) {
                val activeRole = userPrefs.activeRole.first()
                load(current.userId, activeRoleOverride = activeRole)
            }
        }
    }

    private suspend fun load(userId: String, activeRoleOverride: String?) {
        _state.update { it.copy(loading = true, errorMessage = null) }
        profileRepository.fetchById(userId)
            .onSuccess { profile ->
                val cachedRole = activeRoleOverride
                    ?.takeIf { it.isNotBlank() }
                    ?.let { UserRole.fromKey(it) }
                val effectiveRole = cachedRole ?: profile?.role
                _state.update {
                    it.copy(
                        loading = false,
                        greetingName = profile?.displayName ?: "there",
                        role = effectiveRole,
                        errorMessage = null,
                    )
                }
                if (profile != null && effectiveRole != null) {
                    loadDashboardData(profile, effectiveRole)
                }
            }
            .onFailure { error ->
                val msg = error.toUserMessage()
                _state.update { it.copy(loading = false, errorMessage = msg) }
                _effects.send(Effect.ShowMessage(msg))
            }
    }

    private suspend fun loadDashboardData(profile: Profile, role: UserRole) {
        val data = runCatching { fetchData(profile, role) }.getOrNull() ?: return
        _state.update { it.copy(dashboardData = data.copy(loaded = true)) }
    }

    private suspend fun fetchData(profile: Profile, role: UserRole): DashboardData = coroutineScope {
        when (role) {
            UserRole.HOSPITAL -> {
                val jobsAsync = async { repairJobRepository.fetchByHospitalUser(profile.id) }
                val ordersAsync = async { orderRepository.fetchMine(profile.id, page = 0, pageSize = 50) }
                val jobs = jobsAsync.await().getOrDefault(emptyList())
                val orders = ordersAsync.await().getOrDefault(emptyList())
                DashboardData(
                    activeRequestsCount = jobs.count {
                        it.status in listOf(
                            RepairJobStatus.Requested,
                            RepairJobStatus.Assigned,
                            RepairJobStatus.EnRoute,
                            RepairJobStatus.InProgress,
                        )
                    },
                    recentOrdersCount = orders.count {
                        it.status in listOf(
                            OrderStatus.PLACED,
                            OrderStatus.CONFIRMED,
                            OrderStatus.SHIPPED,
                        )
                    },
                    deliveredOrdersCount = orders.count { it.status == OrderStatus.DELIVERED },
                )
            }
            UserRole.ENGINEER -> {
                val nearbyAsync = async { repairJobRepository.fetchNearbyJobs(radiusKm = 10.0, limit = 100) }
                val activeAsync = async { repairJobRepository.fetchAssignedToMe() }
                val bidsAsync = async { repairBidRepository.fetchMyBids() }
                val nearby = nearbyAsync.await().getOrDefault(emptyList())
                val active = activeAsync.await().getOrDefault(emptyList())
                val bids = bidsAsync.await().getOrDefault(emptyList())
                val earnings = bids
                    .filter { it.status == RepairBidStatus.Accepted }
                    .sumOf { it.amountRupees }
                DashboardData(
                    nearbyJobsCount = nearby.size,
                    activeWorkCount = active.count {
                        it.status in listOf(RepairJobStatus.EnRoute, RepairJobStatus.InProgress)
                    },
                    myBidsCount = bids.count { it.status == RepairBidStatus.Pending },
                    earningsRupees = earnings,
                    verified = false, // engineer verification fetched lazily by EngineerProfile flow.
                )
            }
            UserRole.SUPPLIER -> {
                val orgId = profile.organizationId ?: return@coroutineScope DashboardData()
                val ordersAsync = async { orderRepository.fetchForSupplier(orgId) }
                val lowStockAsync = async { sparePartsRepository.fetchLowStockBySupplier(orgId, threshold = 5) }
                val listingsAsync = async { sparePartsRepository.fetchBySupplier(orgId) }
                val rfqAsync = async { rfqRepository.fetchOpen() }
                val orders = ordersAsync.await().getOrDefault(emptyList())
                val low = lowStockAsync.await().getOrDefault(emptyList())
                val listings = listingsAsync.await().getOrDefault(emptyList())
                val rfqs = rfqAsync.await().getOrDefault(emptyList())
                val now = java.time.Instant.now()
                val startOfDay = now.atZone(java.time.ZoneId.systemDefault())
                    .toLocalDate()
                    .atStartOfDay(java.time.ZoneId.systemDefault())
                    .toInstant()
                val todayRevenue = orders
                    .filter { it.status == OrderStatus.DELIVERED }
                    .filter { it.createdAtInstant?.isAfter(startOfDay) == true }
                    .sumOf { it.totalAmount }
                DashboardData(
                    todayRevenueRupees = todayRevenue,
                    pendingOrdersCount = orders.count {
                        it.status in listOf(OrderStatus.PLACED, OrderStatus.CONFIRMED)
                    },
                    stockAlertsCount = low.size,
                    rfqInboxCount = rfqs.size,
                    listingsCount = listings.size,
                )
            }
            UserRole.MANUFACTURER -> {
                val orgId = profile.organizationId ?: return@coroutineScope DashboardData()
                val bidsAsync = async { rfqRepository.fetchBidsByManufacturer(orgId) }
                val rfqAsync = async { rfqRepository.fetchOpen() }
                val bids = bidsAsync.await().getOrDefault(emptyList())
                val rfqs = rfqAsync.await().getOrDefault(emptyList())
                val accepted = bids.count { it.status.equals("accepted", ignoreCase = true) }
                val winRate = if (bids.isEmpty()) 0 else (accepted * 100) / bids.size
                DashboardData(
                    winRatePct = winRate,
                    assignedRfqsCount = rfqs.size,
                    pipelineValueRupees = bids
                        .filter { it.status.equals("pending", ignoreCase = true) || it.status.equals("submitted", ignoreCase = true) }
                        .sumOf { it.totalPriceRupees },
                )
            }
            UserRole.LOGISTICS -> {
                val orgId = profile.organizationId ?: return@coroutineScope DashboardData()
                val pickupsAsync = async {
                    logisticsJobRepository.fetchByPartnerAndStatuses(orgId, listOf("pending", "scheduled"))
                }
                val activeAsync = async {
                    logisticsJobRepository.fetchByPartnerAndStatuses(orgId, listOf("in_transit", "picked_up"))
                }
                val completedAsync = async {
                    logisticsJobRepository.fetchByPartnerAndStatuses(orgId, listOf("delivered"))
                }
                val pickups = pickupsAsync.await().getOrDefault(emptyList())
                val active = activeAsync.await().getOrDefault(emptyList())
                val completed = completedAsync.await().getOrDefault(emptyList())
                val today = java.time.LocalDate.now().toString()
                DashboardData(
                    pickupQueueCount = pickups.size,
                    activeDeliveriesCount = active.size,
                    completedTodayCount = completed.count {
                        it.actualDeliveryAtIso?.startsWith(today) == true
                    },
                )
            }
            else -> DashboardData()
        }
    }
}
