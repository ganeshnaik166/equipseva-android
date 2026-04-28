package com.equipseva.app.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import com.equipseva.app.features.chat.ChatScreen
import com.equipseva.app.features.chat.ConversationsScreen
import com.equipseva.app.features.earnings.EarningsScreen
import com.equipseva.app.features.engineerprofile.EngineerProfileScreen
import com.equipseva.app.features.hospital.HospitalActiveJobsScreen
import com.equipseva.app.features.hospital.RequestServiceScreen
import com.equipseva.app.features.kyc.KycScreen
import com.equipseva.app.features.notifications.NotificationSettingsScreen
import com.equipseva.app.features.notifications.NotificationsScreen
import com.equipseva.app.features.onboarding.TourScreen
import com.equipseva.app.features.mybids.MyBidsScreen
import com.equipseva.app.features.profile.ProfileScreen
import com.equipseva.app.features.repair.RepairJobDetailScreen
import com.equipseva.app.features.repair.RepairJobsScreen
import kotlinx.coroutines.launch

private data class TabItem(val route: String, val label: String, val icon: ImageVector)

/**
 * v1: bottom nav is the same for every user — Home / Repair / Profile.
 * Marketplace / Buy-Sell / Orders / Cart / Checkout / Logistics / Manufacturer
 * / Supplier / Favorites / Scan / Hospital-RFQ surfaces were stripped along
 * with the marketplace cleanup; the tabs left over are the engineer-repair
 * core (book repair + take jobs + earnings + KYC).
 *
 * The `role` parameter stays for ABI compatibility with existing call
 * sites; it's intentionally unused.
 */
@Suppress("UNUSED_PARAMETER")
private fun tabsForRole(role: com.equipseva.app.features.auth.UserRole?): List<TabItem> =
    listOf(
        TabItem(Routes.HOME, "Home", Icons.Filled.Home),
        TabItem(Routes.REPAIR, "Repair", Icons.Filled.Build),
        TabItem(Routes.PROFILE, "Profile", Icons.Filled.Person),
    )

/** Routes that take over the screen and should hide the bottom navigation bar. */
private val fullScreenRoutePrefixes = listOf(
    Routes.REPAIR_DETAIL,
    Routes.ENGINEER_DIRECTORY,
    Routes.ENGINEER_PUBLIC_PROFILE,
    Routes.ENGINEER_JOBS_HUB,
    Routes.CONVERSATIONS,
    Routes.CHAT_DETAIL,
    Routes.KYC,
    Routes.ABOUT,
    Routes.ADD_PHONE,
    Routes.MY_BIDS,
    Routes.REQUEST_SERVICE,
    Routes.ENGINEER_PROFILE,
    Routes.HOSPITAL_ACTIVE_JOBS,
    Routes.NOTIFICATIONS,
    Routes.NOTIFICATION_SETTINGS,
    Routes.TOUR,
    Routes.CHANGE_PASSWORD,
    Routes.CHANGE_EMAIL,
    Routes.FOUNDER_DASHBOARD,
    Routes.FOUNDER_KYC_QUEUE,
    Routes.FOUNDER_REPORTS_QUEUE,
    Routes.FOUNDER_USERS,
    Routes.FOUNDER_PAYMENTS,
    Routes.FOUNDER_INTEGRITY,
    Routes.FOUNDER_CATEGORIES,
    Routes.FOUNDER_BUYER_KYC,
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
            // v1: cold-start lands on the Home tab — the 3-card Hub
            // (Book Repair / Engineer Jobs + optional Founder).
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
                // v1: Home tab — Book Repair / Engineer Jobs (+ Founder Admin
                // tile when signed in as the pinned founder).
                com.equipseva.app.features.home.HomeHubScreen(
                    onOpenBookRepair = { navController.navigate(Routes.ENGINEER_DIRECTORY) },
                    onOpenEngineerJobs = { navController.navigate(Routes.ENGINEER_JOBS_HUB) },
                    onOpenFounder = { navController.navigate(Routes.FOUNDER_DASHBOARD) },
                    onOpenNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                    onOpenKyc = { navController.navigate(Routes.KYC) },
                )
            }
            composable(Routes.REPAIR) {
                // Role-dispatched Repair tab. Engineers see the available-jobs
                // feed; hospital users land on the active-requests list with a
                // CTA to raise a new request; everyone else gets the engineer
                // feed by default (signed-out users land here too).
                val activeRoleKey by deepLinkHost.activeRole.collectAsStateWithLifecycle(initialValue = null)
                val role = activeRoleKey?.let { com.equipseva.app.features.auth.UserRole.fromKey(it) }
                when (role) {
                    com.equipseva.app.features.auth.UserRole.HOSPITAL ->
                        HospitalActiveJobsScreen(
                            onBack = {},
                            onJobClick = { jobId ->
                                navController.navigate(Routes.repairJobDetailRoute(jobId))
                            },
                            onRequestRepair = { navController.navigate(Routes.REQUEST_SERVICE) },
                            onBrowseEngineers = { navController.navigate(Routes.ENGINEER_DIRECTORY) },
                        )
                    else ->
                        RepairJobsScreen(
                            onJobClick = { jobId ->
                                navController.navigate(Routes.repairJobDetailRoute(jobId))
                            },
                            onTuneProfile = { navController.navigate(Routes.ENGINEER_PROFILE) },
                            onViewEarnings = { navController.navigate(Routes.EARNINGS) },
                        )
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
                    onOpenNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                    onOpenFounderDashboard = { navController.navigate(Routes.FOUNDER_DASHBOARD) },
                    onOpenBankDetails = { navController.navigate(Routes.PROFILE_BANK_DETAILS) },
                    onOpenAddresses = { navController.navigate(Routes.PROFILE_ADDRESSES) },
                    onOpenHospitalSettings = { navController.navigate(Routes.PROFILE_HOSPITAL_SETTINGS) },
                    onOpenAddPhone = { navController.navigate(Routes.ADD_PHONE) },
                    onOpenChangePassword = { navController.navigate(Routes.CHANGE_PASSWORD) },
                    onOpenChangeEmail = { navController.navigate(Routes.CHANGE_EMAIL) },
                    onOpenEarnings = { navController.navigate(Routes.EARNINGS) },
                    onOpenMyRepairJobs = { navController.navigate(Routes.HOSPITAL_ACTIVE_JOBS) },
                    onOpenPublicPreview = { engineerId ->
                        navController.navigate(Routes.engineerPublicProfileRoute(engineerId))
                    },
                    onOpenHelp = {
                        // Open a mailto: intent so the user lands in their
                        // email composer pre-addressed to support — no in-app
                        // ticketing system yet.
                        val ctx = navController.context
                        val intent = android.content.Intent(android.content.Intent.ACTION_SENDTO).apply {
                            data = android.net.Uri.parse("mailto:support@equipseva.com")
                            putExtra(android.content.Intent.EXTRA_SUBJECT, "EquipSeva support request")
                        }
                        try {
                            ctx.startActivity(intent)
                        } catch (_: android.content.ActivityNotFoundException) {
                            showSnackbar("No email app installed")
                        }
                    },
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
                    onAddPhone = { navController.navigate(Routes.ADD_PHONE) },
                    onSubmitted = {
                        navController.navigate(Routes.KYC_SUBMITTED) {
                            popUpTo(Routes.KYC) { inclusive = true }
                        }
                    },
                )
            }
            composable(Routes.KYC_SUBMITTED) {
                com.equipseva.app.features.kyc.KycSubmittedScreen(
                    onBackHome = { navController.popBackStack(Routes.HOME, inclusive = false) },
                )
            }
            composable(Routes.ABOUT) {
                AboutScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.ADD_PHONE) {
                com.equipseva.app.features.profile.AddPhoneScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.CHANGE_PASSWORD) {
                com.equipseva.app.features.security.ChangePasswordScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.CHANGE_EMAIL) {
                com.equipseva.app.features.security.ChangeEmailScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
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
                    onBankDetails = { navController.navigate(Routes.PROFILE_BANK_DETAILS) },
                )
            }
            composable(Routes.ACTIVE_WORK) {
                ActiveWorkScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                )
            }
            composable(Routes.REQUEST_SERVICE) {
                RequestServiceScreen(
                    onBack = { navController.popBackStack() },
                    onSubmitted = { jobId, jobNumber ->
                        navController.navigate(Routes.requestSentRoute(jobId, jobNumber)) {
                            popUpTo(Routes.REQUEST_SERVICE) { inclusive = true }
                        }
                    },
                    onShowMessage = showSnackbar,
                )
            }
            composable(
                route = "${Routes.REQUEST_SENT}?jobId={jobId}&jobNumber={jobNumber}",
                arguments = listOf(
                    androidx.navigation.navArgument("jobId") {
                        type = androidx.navigation.NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                    androidx.navigation.navArgument("jobNumber") {
                        type = androidx.navigation.NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
            ) { entry ->
                val jobId = entry.arguments?.getString("jobId")
                val jobNumber = entry.arguments?.getString("jobNumber")
                com.equipseva.app.features.hospital.RequestSentScreen(
                    jobNumber = jobNumber,
                    onViewJob = {
                        if (!jobId.isNullOrBlank()) {
                            navController.navigate(Routes.repairJobDetailRoute(jobId)) {
                                popUpTo(Routes.HOME)
                            }
                        } else {
                            navController.popBackStack(Routes.HOME, inclusive = false)
                        }
                    },
                    onBackHome = {
                        navController.popBackStack(Routes.HOME, inclusive = false)
                    },
                )
            }
            composable(Routes.HOSPITAL_ACTIVE_JOBS) {
                HospitalActiveJobsScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                    onRequestRepair = { navController.navigate(Routes.REQUEST_SERVICE) },
                    onBrowseEngineers = { navController.navigate(Routes.ENGINEER_DIRECTORY) },
                )
            }
            composable(Routes.ENGINEER_PROFILE) {
                EngineerProfileScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
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
                    onOpenEngineerZones = { navController.navigate(Routes.FOUNDER_ENGINEER_MAP) },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_ENGINEER_MAP) {
                com.equipseva.app.features.founder.FounderEngineerMapScreen(
                    onBack = { navController.popBackStack() },
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
 *  - `app://repair/<jobId>`        → repair job detail
 *  - `app://chat/<conversationId>` → chat thread
 *  - `equipseva://...`             → same suffixes (alternative scheme)
 *  - `<top-level route>`           → already a known route string (e.g. "repair")
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
                parts.size >= 2 && parts[0] == "repair" && uuidRegex.matches(parts[1]) ->
                    Routes.repairJobDetailRoute(parts[1])
                parts.size >= 2 && parts[0] == "chat" && uuidRegex.matches(parts[1]) ->
                    Routes.chatRoute(parts[1])
                parts.size == 1 -> when (parts[0]) {
                    "repair", "home", "profile" -> parts[0]
                    "chat" -> Routes.CONVERSATIONS
                    else -> null
                }
                else -> null
            }
        }
        trimmed in setOf(
            Routes.HOME, Routes.REPAIR,
            Routes.PROFILE, Routes.CONVERSATIONS,
        ) -> trimmed
        else -> null
    }

    if (target == null) {
        showSnackbar("Couldn't open that link")
        return
    }
    navController.navigate(target)
}
