package com.equipseva.app.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CardTravel
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Factory
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.equipseva.app.features.about.AboutScreen
import com.equipseva.app.features.activework.ActiveWorkScreen
import com.equipseva.app.features.cart.CartScreen
import com.equipseva.app.features.chat.ChatScreen
import com.equipseva.app.features.chat.ConversationsScreen
import com.equipseva.app.features.checkout.CheckoutScreen
import com.equipseva.app.features.earnings.EarningsScreen
import com.equipseva.app.features.engineerprofile.EngineerProfileScreen
import com.equipseva.app.features.favorites.FavoritesScreen
import com.equipseva.app.features.hospital.CreateRfqScreen
import com.equipseva.app.features.hospital.HospitalActiveJobsScreen
import com.equipseva.app.features.hospital.HospitalMyRfqsScreen
import com.equipseva.app.features.hospital.HospitalRfqDetailScreen
import com.equipseva.app.features.hospital.RequestServiceScreen
import com.equipseva.app.features.kyc.KycScreen
import com.equipseva.app.features.logistics.ActiveDeliveriesScreen
import com.equipseva.app.features.logistics.CompletedTodayScreen
import com.equipseva.app.features.logistics.PickupQueueScreen
import com.equipseva.app.features.manufacturer.AnalyticsScreen
import com.equipseva.app.features.manufacturer.LeadPipelineScreen
import com.equipseva.app.features.manufacturer.RfqsAssignedScreen
import com.equipseva.app.features.notifications.NotificationSettingsScreen
import com.equipseva.app.features.notifications.NotificationsScreen
import com.equipseva.app.features.onboarding.TourScreen
import com.equipseva.app.features.marketplace.MarketplaceScreen
import com.equipseva.app.features.marketplace.PartDetailScreen
import com.equipseva.app.features.mybids.MyBidsScreen
import com.equipseva.app.features.orders.OrderDetailScreen
import com.equipseva.app.features.orders.OrdersScreen
import com.equipseva.app.features.orders.RateOrderScreen
import com.equipseva.app.features.profile.ProfileScreen
import com.equipseva.app.features.repair.RepairJobDetailScreen
import com.equipseva.app.features.repair.RepairJobsScreen
import com.equipseva.app.features.scan.ScanEquipmentScreen
import com.equipseva.app.features.security.ChangeEmailScreen
import com.equipseva.app.features.security.ChangePasswordScreen
import com.equipseva.app.features.supplier.AddListingScreen
import com.equipseva.app.features.supplier.MyListingsScreen
import com.equipseva.app.features.supplier.StockAlertsScreen
import com.equipseva.app.features.supplier.SupplierOrdersScreen
import com.equipseva.app.features.supplier.SupplierRfqsScreen
import kotlinx.coroutines.launch

private data class TabItem(val route: String, val label: String, val icon: ImageVector)

/**
 * v1: bottom nav is the same for every user — buyer-shaped (Home / Buy-Sell
 * / Repair / Profile). Persona-specific tabs (Listings, Supplier Orders,
 * Supplier RFQs, RFQs Assigned, Lead Pipeline, Analytics, Pickup Queue,
 * Active Deliveries, Completed Today, Active Work, Earnings) are still
 * routable but never surfaced on the bottom nav — old per-role layouts
 * crashed for users whose accounts had no organization linked.
 *
 * The `role` parameter stays for ABI compatibility with existing call
 * sites; it's intentionally unused.
 */
@Suppress("UNUSED_PARAMETER")
private fun tabsForRole(role: com.equipseva.app.features.auth.UserRole?): List<TabItem> = listOf(
    TabItem(Routes.HOME, "Home", Icons.Filled.Home),
    TabItem(Routes.MARKETPLACE, "Buy/Sell", Icons.Filled.Storefront),
    TabItem(Routes.REPAIR, "Repair", Icons.Filled.Build),
    TabItem(Routes.PROFILE, "Profile", Icons.Filled.Person),
)

/** Routes that take over the screen and should hide the bottom navigation bar.
 *  Per-role tab destinations (ACTIVE_WORK, EARNINGS, MY_LISTINGS, SUPPLIER_ORDERS,
 *  SUPPLIER_RFQS, RFQS_ASSIGNED, LEAD_PIPELINE, ANALYTICS, PICKUP_QUEUE,
 *  ACTIVE_DELIVERIES, COMPLETED_TODAY) are intentionally NOT in this list so
 *  the bottom nav stays visible when those routes are reached as tabs. */
private val fullScreenRoutePrefixes = listOf(
    Routes.MARKETPLACE_DETAIL,
    Routes.CART,
    Routes.CHECKOUT,
    Routes.ORDER_DETAIL,
    Routes.RATE_ORDER,
    Routes.REPAIR_DETAIL,
    Routes.ENGINEER_DIRECTORY,
    Routes.ENGINEER_PUBLIC_PROFILE,
    Routes.ENGINEER_JOBS_HUB,
    Routes.CONVERSATIONS,
    Routes.CHAT_DETAIL,
    Routes.KYC,
    Routes.ABOUT,
    Routes.CHANGE_PASSWORD,
    Routes.CHANGE_EMAIL,
    Routes.MY_BIDS,
    Routes.STOCK_ALERTS,
    Routes.REQUEST_SERVICE,
    Routes.ENGINEER_PROFILE,
    Routes.SUPPLIER_ADD_LISTING,
    Routes.HOSPITAL_CREATE_RFQ,
    Routes.HOSPITAL_ACTIVE_JOBS,
    Routes.HOSPITAL_MY_RFQS,
    Routes.HOSPITAL_RFQ_DETAIL,
    Routes.SCAN_EQUIPMENT,
    Routes.NOTIFICATIONS,
    Routes.NOTIFICATION_SETTINGS,
    Routes.FAVORITES,
    Routes.TOUR,
    Routes.FOUNDER_DASHBOARD,
    Routes.FOUNDER_KYC_QUEUE,
    Routes.FOUNDER_REPORTS_QUEUE,
    Routes.FOUNDER_USERS,
    Routes.FOUNDER_PAYMENTS,
    Routes.FOUNDER_INTEGRITY,
    Routes.FOUNDER_CATEGORIES,
    Routes.FOUNDER_BUYER_KYC,
    Routes.FOUNDER_CATALOG_IMAGES,
    Routes.CATALOG_BROWSER,
    Routes.PROFILE_BANK_DETAILS,
    Routes.PROFILE_ADDRESSES,
    Routes.PROFILE_HOSPITAL_SETTINGS,
    Routes.PROFILE_STOREFRONT,
    Routes.PROFILE_GST,
    Routes.PROFILE_BRAND_PORTFOLIO,
    Routes.PROFILE_TAX_DETAILS,
    Routes.PROFILE_VEHICLE_DETAILS,
    Routes.PROFILE_LICENCE,
    Routes.PROFILE_SERVICE_AREAS,
    Routes.PROFILE_SELLER_VERIFICATION,
)

@Composable
fun MainNavGraph(
    showTour: Boolean = false,
    onSignIn: () -> Unit = {},
    deepLinkHost: DeepLinkHost = hiltViewModel<DeepLinkHost>(),
) {
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val snackbarHost = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    val showSnackbar: (String) -> Unit = { msg ->
        scope.launch { snackbarHost.showSnackbar(msg) }
    }

    // First-run tour: if user hasn't seen it yet, push it on top of HOME.
    // Tour pops itself on finish/skip, leaving HOME as the root.
    LaunchedEffect(showTour) {
        if (showTour) {
            navController.navigate(Routes.TOUR) {
                launchSingleTop = true
            }
        }
    }

    LaunchedEffect(Unit) {
        deepLinkHost.events.collect { event ->
            when (event) {
                is DeepLinkHost.VerifiedEvent.OpenOrder -> {
                    navController.navigate(Routes.orderDetailRoute(event.orderId))
                }
                DeepLinkHost.VerifiedEvent.OrderNotFound -> {
                    navController.navigate(Routes.ORDERS)
                    showSnackbar("Order not found")
                }
                is DeepLinkHost.VerifiedEvent.OpenRoute -> {
                    // Route comes pre-resolved from NotificationDeepLink; the
                    // server-emitted (kind, data) was mapped to a known
                    // Routes helper before the PendingIntent fired.
                    navController.navigate(event.route)
                }
            }
        }
    }

    val isFullScreenRoute = currentRoute != null &&
        fullScreenRoutePrefixes.any { currentRoute.startsWith(it) }

    val activeRoleKey by deepLinkHost.activeRole.collectAsStateWithLifecycle(initialValue = null)
    val activeRole = activeRoleKey?.let { com.equipseva.app.features.auth.UserRole.fromKey(it) }
    val visibleTabs = tabsForRole(activeRole)

    Scaffold(
        bottomBar = {
            if (!isFullScreenRoute) {
                NavigationBar {
                    visibleTabs.forEach { tab ->
                        val selected = backStack?.destination?.hierarchy?.any { it.route == tab.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                android.util.Log.d("BottomNav", "tab tapped: ${tab.route}")
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                        inclusive = false
                                    }
                                    launchSingleTop = true
                                    restoreState = (tab.route != Routes.PROFILE)
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                        )
                    }
                }
            }
        },
        snackbarHost = { SnackbarHost(snackbarHost) },
    ) { padding ->
        NavHost(
            navController = navController,
            // v1: cold-start lands on the Home tab — the new 3-card Hub
            // (Marketplace / Book Repair / Engineer Jobs + optional Founder).
            startDestination = Routes.HOME,
            modifier = Modifier.padding(padding),
        ) {
            composable(Routes.TOUR) {
                TourScreen(
                    onFinish = {
                        // Pop tour off the stack — back to HOME. Pref flip in
                        // VM also prevents the LaunchedEffect from re-pushing.
                        if (!navController.popBackStack(Routes.TOUR, inclusive = true)) {
                            navController.navigate(Routes.HOME) {
                                popUpTo(Routes.HOME) { inclusive = false }
                                launchSingleTop = true
                            }
                        }
                    },
                )
            }
            composable(Routes.HOME) {
                // v1: Home tab is the new 3-card landing — Marketplace /
                // Book Repair / Engineer Jobs (+ Founder Admin tile when
                // signed in as the pinned founder). The old role-dispatched
                // HomeScreen + per-role dashboards stay in the repo as dead
                // UI; cleanup ships in a follow-up loop.
                com.equipseva.app.features.home.HomeHubScreen(
                    onOpenMarketplace = {
                        navController.navigate(Routes.MARKETPLACE) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    onOpenBookRepair = { navController.navigate(Routes.ENGINEER_DIRECTORY) },
                    onOpenEngineerJobs = { navController.navigate(Routes.ENGINEER_JOBS_HUB) },
                    onOpenFounder = { navController.navigate(Routes.FOUNDER_DASHBOARD) },
                )
            }
            composable(Routes.MARKETPLACE) {
                // v1: Buy/Sell tab shows every active listing (equipment + spare
                // parts mixed). The Spare Parts tab is gone from the bottom nav.
                MarketplaceScreen(
                    onPartClick = { partId ->
                        navController.navigate(Routes.marketplaceDetailRoute(partId))
                    },
                    onOpenCart = { navController.navigate(Routes.CART) },
                    onOpenCatalog = { navController.navigate(Routes.CATALOG_BROWSE) },
                    onListItem = { navController.navigate(Routes.SUPPLIER_ADD_LISTING) },
                )
            }
            // Routes.SPARE_PARTS is intentionally kept routable but unused on
            // the bottom nav for v1. The Buy/Sell tab serves both equipment
            // and spare-parts in a mixed feed.
            composable(Routes.SPARE_PARTS) {
                MarketplaceScreen(
                    onPartClick = { partId ->
                        navController.navigate(Routes.marketplaceDetailRoute(partId))
                    },
                    onOpenCart = { navController.navigate(Routes.CART) },
                    onOpenCatalog = { navController.navigate(Routes.CATALOG_BROWSE) },
                    onListItem = { navController.navigate(Routes.SUPPLIER_ADD_LISTING) },
                )
            }
            composable(
                route = "${Routes.MARKETPLACE_DETAIL}/{${Routes.MARKETPLACE_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.MARKETPLACE_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                PartDetailScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                    onOpenCart = { navController.navigate(Routes.CART) },
                )
            }
            composable(Routes.ORDERS) {
                OrdersScreen(
                    onShowMessage = showSnackbar,
                    onOrderClick = { orderId ->
                        navController.navigate(Routes.orderDetailRoute(orderId))
                    },
                    onShopMarketplace = {
                        navController.navigate(Routes.MARKETPLACE) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
            composable(
                route = "${Routes.ORDER_DETAIL}/{${Routes.ORDER_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.ORDER_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                OrderDetailScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                    onRateOrder = { orderId ->
                        navController.navigate(Routes.rateOrderRoute(orderId))
                    },
                )
            }
            composable(
                route = "${Routes.RATE_ORDER}/{${Routes.RATE_ORDER_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.RATE_ORDER_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                RateOrderScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.REPAIR) {
                // Role-dispatched Repair tab. Engineers see the available-jobs
                // feed; hospital users land on the active-requests list with a
                // CTA to raise a new request; suppliers / manufacturers see an
                // empty state because Repair isn't part of their workflow;
                // logistics partners get redirected to their pickup queue.
                val activeRoleKey by deepLinkHost.activeRole.collectAsStateWithLifecycle(initialValue = null)
                val role = activeRoleKey?.let { com.equipseva.app.features.auth.UserRole.fromKey(it) }
                when (role) {
                    com.equipseva.app.features.auth.UserRole.ENGINEER, null ->
                        RepairJobsScreen(
                            onJobClick = { jobId ->
                                navController.navigate(Routes.repairJobDetailRoute(jobId))
                            },
                        )
                    com.equipseva.app.features.auth.UserRole.HOSPITAL ->
                        HospitalActiveJobsScreen(
                            onBack = {},
                            onJobClick = { jobId ->
                                navController.navigate(Routes.repairJobDetailRoute(jobId))
                            },
                            onRequestRepair = { navController.navigate(Routes.REQUEST_SERVICE) },
                        )
                    com.equipseva.app.features.auth.UserRole.LOGISTICS -> {
                        androidx.compose.runtime.LaunchedEffect(Unit) {
                            navController.navigate(Routes.PICKUP_QUEUE) {
                                popUpTo(Routes.HOME) { saveState = true }
                                launchSingleTop = true
                            }
                        }
                    }
                    com.equipseva.app.features.auth.UserRole.SUPPLIER,
                    com.equipseva.app.features.auth.UserRole.MANUFACTURER -> {
                        com.equipseva.app.designsystem.components.EmptyStateView(
                            icon = androidx.compose.material.icons.Icons.Filled.Build,
                            title = "Repair isn't part of your workflow",
                            subtitle = "Repair jobs are routed to engineers and hospitals. Use the Marketplace and Profile tabs.",
                        )
                    }
                }
            }
            composable(
                route = "${Routes.REPAIR_DETAIL}/{${Routes.REPAIR_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.REPAIR_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                RepairJobDetailScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                    onOpenChat = { id -> navController.navigate(Routes.chatRoute(id)) },
                )
            }
            composable(Routes.ENGINEER_JOBS_HUB) {
                com.equipseva.app.features.engineer.EngineerJobsHubScreen(
                    onBack = { navController.popBackStack() },
                    onAvailableJobs = { navController.navigate(Routes.REPAIR) },
                    onMyBids = { navController.navigate(Routes.MY_BIDS) },
                    onActiveWork = { navController.navigate(Routes.ACTIVE_WORK) },
                    onEarnings = { navController.navigate(Routes.EARNINGS) },
                    onEditProfile = { navController.navigate(Routes.ENGINEER_PROFILE) },
                    onSubmitKyc = { navController.navigate(Routes.KYC) },
                    onSignIn = { onSignIn() },
                )
            }
            composable(Routes.ENGINEER_DIRECTORY) {
                com.equipseva.app.features.repair.directory.EngineerDirectoryScreen(
                    onBack = { navController.popBackStack() },
                    onOpenProfile = { id ->
                        navController.navigate(Routes.engineerPublicProfileRoute(id))
                    },
                    onAnyEngineer = { navController.navigate(Routes.REQUEST_SERVICE) },
                )
            }
            composable(
                route = "${Routes.ENGINEER_PUBLIC_PROFILE}/{${Routes.ENGINEER_PUBLIC_PROFILE_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.ENGINEER_PUBLIC_PROFILE_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                com.equipseva.app.features.repair.directory.EngineerPublicProfileScreen(
                    onBack = { navController.popBackStack() },
                    onRequestService = { _ ->
                        navController.navigate(Routes.REQUEST_SERVICE)
                    },
                )
            }
            composable(Routes.PROFILE) {
                ProfileScreen(
                    onShowMessage = showSnackbar,
                    onOpenMessages = { navController.navigate(Routes.CONVERSATIONS) },
                    onOpenVerification = { navController.navigate(Routes.KYC) },
                    onOpenAbout = { navController.navigate(Routes.ABOUT) },
                    onOpenFavorites = { navController.navigate(Routes.FAVORITES) },
                    onOpenNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                    onOpenChangePassword = { navController.navigate(Routes.CHANGE_PASSWORD) },
                    onOpenChangeEmail = { navController.navigate(Routes.CHANGE_EMAIL) },
                    onOpenFounderDashboard = { navController.navigate(Routes.FOUNDER_DASHBOARD) },
                    onOpenBankDetails = { navController.navigate(Routes.PROFILE_BANK_DETAILS) },
                    onOpenAddresses = { navController.navigate(Routes.PROFILE_ADDRESSES) },
                    onOpenHospitalSettings = { navController.navigate(Routes.PROFILE_HOSPITAL_SETTINGS) },
                    onOpenOrders = { navController.navigate(Routes.ORDERS) },
                    onOpenSellerVerification = { navController.navigate(Routes.PROFILE_SELLER_VERIFICATION) },
                    onSignIn = onSignIn,
                )
            }
            composable(Routes.NOTIFICATIONS) {
                NotificationsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenSettings = { navController.navigate(Routes.NOTIFICATION_SETTINGS) },
                    onOpenRoute = { route ->
                        // Resolver already produced a valid Routes.* string —
                        // hand it straight to NavController.
                        navController.navigate(route)
                    },
                    onOpenDeepLink = { link ->
                        // Legacy path for rows that pre-date kind-based push
                        // (server PR #192). Only honour app-internal shapes
                        // we already trust; anything else falls through
                        // silently — the row tap already marked it read.
                        routeNotificationDeepLink(link, navController, showSnackbar)
                    },
                )
            }
            composable(Routes.NOTIFICATION_SETTINGS) {
                NotificationSettingsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.KYC) {
                KycScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.ABOUT) {
                AboutScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.CHANGE_PASSWORD) {
                ChangePasswordScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.CHANGE_EMAIL) {
                ChangeEmailScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.CART) {
                CartScreen(
                    onBack = { navController.popBackStack() },
                    onCheckout = { navController.navigate(Routes.CHECKOUT) },
                    onBrowseParts = {
                        navController.navigate(Routes.MARKETPLACE) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
            composable(Routes.CONVERSATIONS) {
                ConversationsScreen(
                    onBack = { navController.popBackStack() },
                    onConversationClick = { id -> navController.navigate(Routes.chatRoute(id)) },
                )
            }
            composable(
                route = "${Routes.CHAT_DETAIL}/{${Routes.CHAT_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.CHAT_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                ChatScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.CHECKOUT) {
                CheckoutScreen(
                    onBack = { navController.popBackStack() },
                    onOrderPlaced = { orderId ->
                        navController.navigate(Routes.orderDetailRoute(orderId)) {
                            popUpTo(Routes.HOME) { saveState = true }
                            launchSingleTop = true
                        }
                    },
                )
            }
            composable(Routes.MY_BIDS) {
                MyBidsScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                )
            }
            composable(Routes.EARNINGS) {
                EarningsScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                )
            }
            composable(Routes.ACTIVE_WORK) {
                ActiveWorkScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                )
            }
            composable(Routes.MY_LISTINGS) {
                MyListingsScreen(
                    onBack = { navController.popBackStack() },
                    onPartClick = { partId -> navController.navigate(Routes.marketplaceDetailRoute(partId)) },
                )
            }
            composable(Routes.STOCK_ALERTS) {
                StockAlertsScreen(
                    onBack = { navController.popBackStack() },
                    onPartClick = { partId -> navController.navigate(Routes.marketplaceDetailRoute(partId)) },
                )
            }
            composable(Routes.SUPPLIER_ORDERS) {
                SupplierOrdersScreen(
                    onBack = { navController.popBackStack() },
                    onOrderClick = { orderId -> navController.navigate(Routes.orderDetailRoute(orderId)) },
                )
            }
            composable(Routes.SUPPLIER_RFQS) {
                SupplierRfqsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.RFQS_ASSIGNED) {
                RfqsAssignedScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.LEAD_PIPELINE) {
                LeadPipelineScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.ANALYTICS) {
                AnalyticsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.PICKUP_QUEUE) {
                PickupQueueScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.ACTIVE_DELIVERIES) {
                ActiveDeliveriesScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.COMPLETED_TODAY) {
                CompletedTodayScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.REQUEST_SERVICE) {
                RequestServiceScreen(
                    onBack = { navController.popBackStack() },
                    onSubmitted = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(
                route = Routes.HOSPITAL_CREATE_RFQ +
                    "?${Routes.HOSPITAL_CREATE_RFQ_ARG_TITLE}={${Routes.HOSPITAL_CREATE_RFQ_ARG_TITLE}}" +
                    "&${Routes.HOSPITAL_CREATE_RFQ_ARG_TYPE}={${Routes.HOSPITAL_CREATE_RFQ_ARG_TYPE}}" +
                    "&${Routes.HOSPITAL_CREATE_RFQ_ARG_DESC}={${Routes.HOSPITAL_CREATE_RFQ_ARG_DESC}}",
                arguments = listOf(
                    navArgument(Routes.HOSPITAL_CREATE_RFQ_ARG_TITLE) {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                    navArgument(Routes.HOSPITAL_CREATE_RFQ_ARG_TYPE) {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                    navArgument(Routes.HOSPITAL_CREATE_RFQ_ARG_DESC) {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
            ) {
                CreateRfqScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.CATALOG_BROWSE) {
                val openRfqForItem: (com.equipseva.app.core.data.catalog.CatalogReferenceRepository.Item) -> Unit = { item ->
                    val title = "Quote: ${item.itemName}"
                    val type = item.category
                    val desc = buildString {
                        append("Looking for: ")
                        append(item.itemName)
                        if (!item.brand.isNullOrBlank() || !item.model.isNullOrBlank()) {
                            append(" (")
                            append(listOfNotNull(item.brand, item.model).joinToString(" "))
                            append(")")
                        }
                        if (!item.keySpecifications.isNullOrBlank()) {
                            append("\n\nSpecs: ").append(item.keySpecifications)
                        }
                        append("\n\nReference catalogue id: ").append(item.id)
                    }
                    navController.navigate(
                        Routes.hospitalCreateRfqRoute(
                            title = title,
                            equipmentType = type,
                            description = desc,
                        )
                    )
                }
                com.equipseva.app.features.catalog.CatalogBrowseScreen(
                    onBack = { navController.popBackStack() },
                    onOpenDetail = { item ->
                        navController.navigate(Routes.catalogDetailRoute(item.id))
                    },
                    onRequestQuote = openRfqForItem,
                )
            }
            composable(
                route = "${Routes.CATALOG_DETAIL}/{${Routes.CATALOG_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.CATALOG_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                com.equipseva.app.features.catalog.CatalogDetailScreen(
                    onBack = { navController.popBackStack() },
                    onRequestQuote = { item ->
                        val title = "Quote: ${item.itemName}"
                        val type = item.category
                        val desc = buildString {
                            append("Looking for: ")
                            append(item.itemName)
                            if (!item.brand.isNullOrBlank() || !item.model.isNullOrBlank()) {
                                append(" (")
                                append(listOfNotNull(item.brand, item.model).joinToString(" "))
                                append(")")
                            }
                            if (!item.keySpecifications.isNullOrBlank()) {
                                append("\n\nSpecs: ").append(item.keySpecifications)
                            }
                            append("\n\nReference catalogue id: ").append(item.id)
                        }
                        navController.navigate(
                            Routes.hospitalCreateRfqRoute(
                                title = title,
                                equipmentType = type,
                                description = desc,
                            )
                        )
                    },
                )
            }
            composable(Routes.HOSPITAL_ACTIVE_JOBS) {
                HospitalActiveJobsScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                    onRequestRepair = { navController.navigate(Routes.REQUEST_SERVICE) },
                )
            }
            composable(Routes.HOSPITAL_MY_RFQS) {
                HospitalMyRfqsScreen(
                    onBack = { navController.popBackStack() },
                    onRfqClick = { rfqId ->
                        navController.navigate(Routes.hospitalRfqDetailRoute(rfqId))
                    },
                    onCreateRfq = { navController.navigate(Routes.HOSPITAL_CREATE_RFQ) },
                )
            }
            composable(
                route = "${Routes.HOSPITAL_RFQ_DETAIL}/{${Routes.HOSPITAL_RFQ_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.HOSPITAL_RFQ_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                HospitalRfqDetailScreen(
                    onBack = { navController.popBackStack() },
                    onNavigateToChat = { conversationId ->
                        navController.navigate(Routes.chatRoute(conversationId))
                    },
                )
            }
            composable(Routes.SCAN_EQUIPMENT) {
                ScanEquipmentScreen(
                    onBack = { navController.popBackStack() },
                    onFindParts = {
                        navController.navigate(Routes.MARKETPLACE) {
                            popUpTo(Routes.HOME)
                        }
                    },
                )
            }
            composable(Routes.ENGINEER_PROFILE) {
                EngineerProfileScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.SUPPLIER_ADD_LISTING) {
                AddListingScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FAVORITES) {
                FavoritesScreen(
                    onBack = { navController.popBackStack() },
                    onOpenPart = { partId ->
                        navController.navigate(Routes.marketplaceDetailRoute(partId))
                    },
                    onFindParts = {
                        navController.navigate(Routes.MARKETPLACE) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
            // Founder admin dashboard surfaces. Email-pinned via
            // Profile.isFounder(); the Profile screen renders a "Founder
            // dashboard" row only for the founder, so non-founders never
            // navigate here. Server-side `is_founder()` SQL gate is the
            // ultimate enforcement.
            composable(Routes.FOUNDER_DASHBOARD) {
                com.equipseva.app.features.founder.FounderDashboardScreen(
                    onOpenKycQueue = { navController.navigate(Routes.FOUNDER_KYC_QUEUE) },
                    onOpenReportsQueue = { navController.navigate(Routes.FOUNDER_REPORTS_QUEUE) },
                    onOpenUsers = { navController.navigate(Routes.FOUNDER_USERS) },
                    onOpenPayments = { navController.navigate(Routes.FOUNDER_PAYMENTS) },
                    onOpenIntegrityFlags = { navController.navigate(Routes.FOUNDER_INTEGRITY) },
                    onOpenCategories = { navController.navigate(Routes.FOUNDER_CATEGORIES) },
                    onOpenBuyerKyc = { navController.navigate(Routes.FOUNDER_BUYER_KYC) },
                    onOpenCatalogImages = { navController.navigate(Routes.FOUNDER_CATALOG_IMAGES) },
                )
            }
            composable(Routes.FOUNDER_KYC_QUEUE) {
                com.equipseva.app.features.founder.FounderKycQueueScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_REPORTS_QUEUE) {
                com.equipseva.app.features.founder.FounderReportsQueueScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_USERS) {
                com.equipseva.app.features.founder.FounderUsersScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_PAYMENTS) {
                com.equipseva.app.features.founder.FounderPaymentsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_INTEGRITY) {
                com.equipseva.app.features.founder.FounderIntegrityScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_CATEGORIES) {
                com.equipseva.app.features.founder.FounderCategoriesScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_BUYER_KYC) {
                com.equipseva.app.features.founder.FounderBuyerKycQueueScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_CATALOG_IMAGES) {
                com.equipseva.app.features.founder.FounderCatalogImagesScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.CATALOG_BROWSER) {
                com.equipseva.app.features.catalog.CatalogBrowserScreen(
                    onBack = { navController.popBackStack() },
                    onRequestQuote = { _, _ ->
                        // Routes to existing CreateRfq flow. Prefill via SavedStateHandle
                        // is a follow-up; for now we just open the create-rfq form.
                        navController.navigate(Routes.HOSPITAL_CREATE_RFQ)
                    },
                )
            }

            // Per-role profile sub-screen placeholders. Each row in
            // ProfileScreen now navigates to a real destination; the
            // forms inside flesh out per-role next.
            composable(Routes.PROFILE_BANK_DETAILS) {
                com.equipseva.app.features.profile.forms.BankDetailsScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_ADDRESSES) {
                com.equipseva.app.features.profile.forms.AddressBookScreen(
                    onBack = { navController.popBackStack() },
                    onAdd = { navController.navigate(Routes.addressFormRoute(null)) },
                    onEdit = { id -> navController.navigate(Routes.addressFormRoute(id)) },
                )
            }
            composable(
                route = "${Routes.PROFILE_ADDRESS_FORM}?${Routes.PROFILE_ADDRESS_FORM_ARG_ID}={${Routes.PROFILE_ADDRESS_FORM_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.PROFILE_ADDRESS_FORM_ARG_ID) {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
            ) {
                com.equipseva.app.features.profile.forms.AddressFormScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.PROFILE_HOSPITAL_SETTINGS) {
                com.equipseva.app.features.profile.forms.HospitalSettingsScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_STOREFRONT) {
                com.equipseva.app.features.profile.forms.StorefrontSettingsScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_GST) {
                com.equipseva.app.features.profile.forms.GstSettingsScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_BRAND_PORTFOLIO) {
                com.equipseva.app.features.profile.forms.BrandPortfolioScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_TAX_DETAILS) {
                com.equipseva.app.features.profile.forms.TaxDetailsScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_VEHICLE_DETAILS) {
                com.equipseva.app.features.profile.forms.VehicleDetailsScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_LICENCE) {
                com.equipseva.app.features.profile.forms.LicenceScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_SERVICE_AREAS) {
                com.equipseva.app.features.profile.forms.ServiceAreasScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.PROFILE_SELLER_VERIFICATION) {
                com.equipseva.app.features.profile.seller.SellerVerificationScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
        }
    }
}

/**
 * Resolve a notification's `data.deep_link` (or legacy `action_url`) into a
 * concrete in-app navigation. The notification payload comes from server-side
 * push code; we only honour shapes the app already understands and silently
 * drop anything else so a malformed payload never crashes the inbox.
 *
 * Recognised forms:
 *  - `app://orders/<orderId>`      → order detail
 *  - `app://repair/<jobId>`        → repair job detail
 *  - `app://chat/<conversationId>` → chat thread
 *  - `app://rfq/<rfqId>`           → hospital RFQ detail
 *  - `equipseva://...`             → same suffixes (alternative scheme)
 *  - `<top-level route>`           → already a known route string (e.g. "orders")
 */
private fun routeNotificationDeepLink(
    link: String,
    navController: androidx.navigation.NavHostController,
    showSnackbar: (String) -> Unit,
) {
    val trimmed = link.trim().ifBlank { return }

    val uuidRegex =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

    val target = when {
        trimmed.startsWith("app://") || trimmed.startsWith("equipseva://") -> {
            val rest = trimmed.substringAfter("://")
            val parts = rest.split('/').filter { it.isNotBlank() }
            when {
                parts.size >= 2 && parts[0] == "orders" && uuidRegex.matches(parts[1]) ->
                    Routes.orderDetailRoute(parts[1])
                parts.size >= 2 && parts[0] == "repair" && uuidRegex.matches(parts[1]) ->
                    Routes.repairJobDetailRoute(parts[1])
                parts.size >= 2 && parts[0] == "chat" && uuidRegex.matches(parts[1]) ->
                    Routes.chatRoute(parts[1])
                parts.size >= 2 && parts[0] == "rfq" && uuidRegex.matches(parts[1]) ->
                    Routes.hospitalRfqDetailRoute(parts[1])
                parts.size == 1 -> when (parts[0]) {
                    "orders", "marketplace", "repair", "home", "profile" -> parts[0]
                    "chat" -> Routes.CONVERSATIONS
                    "favorites" -> Routes.FAVORITES
                    else -> null
                }
                else -> null
            }
        }
        trimmed in setOf(
            Routes.HOME, Routes.ORDERS, Routes.MARKETPLACE, Routes.REPAIR,
            Routes.PROFILE, Routes.CONVERSATIONS, Routes.FAVORITES,
        ) -> trimmed
        else -> null
    }

    if (target == null) {
        showSnackbar("Couldn't open that link")
        return
    }
    navController.navigate(target)
}
