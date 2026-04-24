package com.equipseva.app.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Storefront
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
import com.equipseva.app.features.home.HomeScreen
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
import com.equipseva.app.features.notifications.NotificationsScreen
import com.equipseva.app.features.marketplace.MarketplaceScreen
import com.equipseva.app.features.marketplace.PartDetailScreen
import com.equipseva.app.features.mybids.MyBidsScreen
import com.equipseva.app.features.orders.OrderDetailScreen
import com.equipseva.app.features.orders.OrdersScreen
import com.equipseva.app.features.profile.ProfileScreen
import com.equipseva.app.features.repair.RepairJobDetailScreen
import com.equipseva.app.features.repair.RepairJobsScreen
import com.equipseva.app.features.scan.ScanEquipmentScreen
import com.equipseva.app.features.security.ChangePasswordScreen
import com.equipseva.app.features.supplier.AddListingScreen
import com.equipseva.app.features.supplier.MyListingsScreen
import com.equipseva.app.features.supplier.StockAlertsScreen
import com.equipseva.app.features.supplier.SupplierOrdersScreen
import com.equipseva.app.features.supplier.SupplierRfqsScreen
import kotlinx.coroutines.launch

private data class TabItem(val route: String, val label: String, val icon: ImageVector)

private val tabs = listOf(
    TabItem(Routes.HOME, "Home", Icons.Filled.Home),
    TabItem(Routes.MARKETPLACE, "Parts", Icons.Filled.Storefront),
    TabItem(Routes.REPAIR, "Repair", Icons.Filled.Build),
    TabItem(Routes.ORDERS, "Orders", Icons.Filled.Receipt),
    TabItem(Routes.PROFILE, "Profile", Icons.Filled.Person),
)

/** Routes that take over the screen and should hide the bottom navigation bar. */
private val fullScreenRoutePrefixes = listOf(
    Routes.MARKETPLACE_DETAIL,
    Routes.CART,
    Routes.CHECKOUT,
    Routes.ORDER_DETAIL,
    Routes.REPAIR_DETAIL,
    Routes.CONVERSATIONS,
    Routes.CHAT_DETAIL,
    Routes.KYC,
    Routes.ABOUT,
    Routes.CHANGE_PASSWORD,
    Routes.MY_BIDS,
    Routes.EARNINGS,
    Routes.ACTIVE_WORK,
    Routes.MY_LISTINGS,
    Routes.STOCK_ALERTS,
    Routes.SUPPLIER_ORDERS,
    Routes.SUPPLIER_RFQS,
    Routes.RFQS_ASSIGNED,
    Routes.LEAD_PIPELINE,
    Routes.ANALYTICS,
    Routes.PICKUP_QUEUE,
    Routes.ACTIVE_DELIVERIES,
    Routes.COMPLETED_TODAY,
    Routes.REQUEST_SERVICE,
    Routes.ENGINEER_PROFILE,
    Routes.SUPPLIER_ADD_LISTING,
    Routes.HOSPITAL_CREATE_RFQ,
    Routes.HOSPITAL_ACTIVE_JOBS,
    Routes.HOSPITAL_MY_RFQS,
    Routes.HOSPITAL_RFQ_DETAIL,
    Routes.SCAN_EQUIPMENT,
    Routes.NOTIFICATIONS,
    Routes.FAVORITES,
)

@Composable
fun MainNavGraph(
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
            }
        }
    }

    val isFullScreenRoute = currentRoute != null &&
        fullScreenRoutePrefixes.any { currentRoute.startsWith(it) }

    Scaffold(
        bottomBar = {
            if (!isFullScreenRoute) {
                NavigationBar {
                    tabs.forEach { tab ->
                        val selected = backStack?.destination?.hierarchy?.any { it.route == tab.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
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
            startDestination = Routes.HOME,
            modifier = Modifier.padding(padding),
        ) {
            composable(Routes.HOME) {
                HomeScreen(
                    onShowMessage = showSnackbar,
                    onCardClick = { key ->
                        val tabRoute = when (key) {
                            "browse_parts" -> Routes.MARKETPLACE
                            "jobs_nearby" -> Routes.REPAIR
                            "order_history" -> Routes.ORDERS
                            else -> null
                        }
                        val subRoute = when (key) {
                            "request_service" -> Routes.REQUEST_SERVICE
                            "hospital_create_rfq" -> Routes.HOSPITAL_CREATE_RFQ
                            "active_jobs" -> Routes.HOSPITAL_ACTIVE_JOBS
                            "my_rfqs", "hospital_rfqs" -> Routes.HOSPITAL_MY_RFQS
                            // "scan_equipment" entry hidden for v1 — route kept registered for deep links.
                            "my_bids" -> Routes.MY_BIDS
                            "earnings" -> Routes.EARNINGS
                            "active_work" -> Routes.ACTIVE_WORK
                            "engineer_profile" -> Routes.ENGINEER_PROFILE
                            "my_listings" -> Routes.MY_LISTINGS
                            "supplier_add_listing" -> Routes.SUPPLIER_ADD_LISTING
                            "stock_alerts" -> Routes.STOCK_ALERTS
                            "incoming_orders" -> Routes.SUPPLIER_ORDERS
                            "rfqs", "supplier_rfqs" -> Routes.SUPPLIER_RFQS
                            "rfqs_assigned", "matched_rfqs" -> Routes.RFQS_ASSIGNED
                            "lead_pipeline", "leads" -> Routes.LEAD_PIPELINE
                            "analytics" -> Routes.ANALYTICS
                            "pickup_queue", "pickups" -> Routes.PICKUP_QUEUE
                            "active_deliveries", "deliveries" -> Routes.ACTIVE_DELIVERIES
                            "completed_today", "completed" -> Routes.COMPLETED_TODAY
                            else -> null
                        }
                        when {
                            tabRoute != null -> navController.navigate(tabRoute) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                            subRoute != null -> navController.navigate(subRoute)
                        }
                    },
                )
            }
            composable(Routes.MARKETPLACE) {
                MarketplaceScreen(
                    onPartClick = { partId ->
                        navController.navigate(Routes.marketplaceDetailRoute(partId))
                    },
                    onOpenCart = { navController.navigate(Routes.CART) },
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
                )
            }
            composable(Routes.REPAIR) {
                RepairJobsScreen(
                    onJobClick = { jobId ->
                        navController.navigate(Routes.repairJobDetailRoute(jobId))
                    },
                )
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
            composable(Routes.PROFILE) {
                ProfileScreen(
                    onShowMessage = showSnackbar,
                    onOpenMessages = { navController.navigate(Routes.CONVERSATIONS) },
                    onOpenVerification = { navController.navigate(Routes.KYC) },
                    onOpenAbout = { navController.navigate(Routes.ABOUT) },
                    onOpenFavorites = { navController.navigate(Routes.FAVORITES) },
                    onOpenNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                    onOpenChangePassword = { navController.navigate(Routes.CHANGE_PASSWORD) },
                )
            }
            composable(Routes.NOTIFICATIONS) {
                NotificationsScreen(
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
            composable(Routes.HOSPITAL_CREATE_RFQ) {
                CreateRfqScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.HOSPITAL_ACTIVE_JOBS) {
                HospitalActiveJobsScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                )
            }
            composable(Routes.HOSPITAL_MY_RFQS) {
                HospitalMyRfqsScreen(
                    onBack = { navController.popBackStack() },
                    onRfqClick = { rfqId ->
                        navController.navigate(Routes.hospitalRfqDetailRoute(rfqId))
                    },
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
                )
            }
        }
    }
}
