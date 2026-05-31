package com.equipseva.app.navigation

import androidx.core.net.toUri
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.firstOrNull
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.WorkOutline
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
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

// Round-3 nav restructure — bottom nav is now per-role, matching
// `shared.jsx:BottomNav`:
//   • Hospital → 3 tabs (Home / Bookings / Profile) with Bookings
//     pointing straight at the active-jobs list (was a buried sub-screen).
//   • Engineer → 4 tabs (Home / Jobs / Earnings / Profile) — Earnings
//     graduates from a Profile row to a top-level destination.
//   • Anonymous / unknown role → engineer 4-tab default.
private fun tabsForRole(
    role: com.equipseva.app.features.auth.UserRole?,
): List<com.equipseva.app.designsystem.components.EsBottomNavItem> {
    val routes = tabRoutesForRole(role)
    return routes.map { route ->
        when (route) {
            Routes.HOME -> com.equipseva.app.designsystem.components.EsBottomNavItem(
                Routes.HOME, "Home", Icons.Outlined.Home,
            )
            Routes.HOSPITAL_ACTIVE_JOBS -> com.equipseva.app.designsystem.components.EsBottomNavItem(
                Routes.HOSPITAL_ACTIVE_JOBS, "Bookings", Icons.Outlined.WorkOutline,
            )
            Routes.ENGINEER_JOBS_HUB -> com.equipseva.app.designsystem.components.EsBottomNavItem(
                Routes.ENGINEER_JOBS_HUB, "Jobs", Icons.Outlined.Build,
            )
            Routes.EARNINGS -> com.equipseva.app.designsystem.components.EsBottomNavItem(
                Routes.EARNINGS, "Earnings", Icons.Outlined.CurrencyRupee,
            )
            Routes.PROFILE -> com.equipseva.app.designsystem.components.EsBottomNavItem(
                Routes.PROFILE, "Profile", Icons.Outlined.Person,
            )
            else -> error("tabRoutesForRole returned unknown route: $route")
        }
    }
}

/**
 * Pure form of [tabsForRole]: returns the ordered list of route
 * strings the bottom-nav exposes for each role. Extracted so the
 * per-role tab arrangement can be tested without the Compose
 * ImageVector dependencies on the full EsBottomNavItem.
 *
 *   * Hospital → Home / Bookings / Profile (3 tabs)
 *   * Engineer (and other / null roles) → Home / Jobs / Earnings /
 *     Profile (4 tabs)
 *
 * The Jobs tab routes to ENGINEER_JOBS_HUB (the chooser landing), not
 * the raw REPAIR feed — pinned because the hub itself routes into the
 * feed via the "Available jobs" tile.
 */
internal fun tabRoutesForRole(
    role: com.equipseva.app.features.auth.UserRole?,
): List<String> = when (role) {
    com.equipseva.app.features.auth.UserRole.HOSPITAL ->
        listOf(Routes.HOME, Routes.HOSPITAL_ACTIVE_JOBS, Routes.PROFILE)
    else ->
        listOf(Routes.HOME, Routes.ENGINEER_JOBS_HUB, Routes.EARNINGS, Routes.PROFILE)
}

/** Routes that take over the screen and should hide the bottom navigation bar. */
internal val fullScreenRoutePrefixes = listOf(
    Routes.REPAIR_DETAIL,
    Routes.ENGINEER_DIRECTORY,
    Routes.ENGINEER_PUBLIC_PROFILE,
    Routes.AMC_CONTRACTS_LIST,
    Routes.AMC_CONTRACT_DETAIL,
    Routes.CREATE_AMC,
    // ENGINEER_JOBS_HUB intentionally excluded — it's a bottom-nav tab, not a full-screen destination.
    Routes.CONVERSATIONS,
    Routes.CHAT_DETAIL,
    Routes.KYC,
    Routes.ABOUT,
    Routes.ADD_PHONE,
    Routes.MY_BIDS,
    Routes.REQUEST_SERVICE,
    Routes.ENGINEER_PROFILE,
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
    Routes.FOUNDER_AMC_EXPIRING,
    Routes.FOUNDER_INACTIVE_ENGINEERS,
    Routes.FOUNDER_AMC_PAUSED,
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

    // Process-death recovery: if the user was on a restorable screen (e.g.
    // KYC) when Android reclaimed our process during the SAF picker,
    // navigate them back instead of leaving them stranded at Home. One-shot
    // — `consumeLastScreen` clears the pin after restore so the next Back
    // → Home doesn't bounce right back here.
    LaunchedEffect(navController) {
        val pinned = deepLinkHost.lastScreen.firstOrNull()
        if (!pinned.isNullOrBlank()) {
            // Wait for the engineer-status read to settle so the KYC restore
            // guard below has accurate data. firstOrNull() resolves once the
            // DeepLinkHost session-collector pushes the verified status.
            val resolvedStatus = deepLinkHost.engineerStatus
                .filterNotNull()
                .firstOrNull()
            // Don't bounce a verified engineer back into KYC. The pin is
            // meant for "user was mid-KYC when the SAF picker triggered
            // process death", not for "user popped a verification screen".
            val skip = pinned == Routes.KYC &&
                resolvedStatus ==
                    com.equipseva.app.core.data.engineers.VerificationStatus.Verified
            if (!skip) {
                navController.navigate(pinned) { launchSingleTop = true }
            }
            deepLinkHost.consumeLastScreen()
        }
    }

    LaunchedEffect(Unit) {
        deepLinkHost.events.collect { event ->
            when (event) {
                is DeepLinkHost.VerifiedEvent.OpenRoute -> {
                    // Route comes pre-resolved from NotificationDeepLink; the
                    // server-emitted (kind, data) was mapped to a known
                    // Routes helper before the PendingIntent fired. We still
                    // guard against malformed adb-injected routes and stale
                    // pre-server-PR-#192 deep_link strings so a bad payload
                    // can't crash MainActivity with IllegalArgumentException.
                    runCatching { navController.navigate(event.route) }
                }
            }
        }
    }

    val isFullScreenRoute = isFullScreenRoute(currentRoute)

    val activeRoleKey by deepLinkHost.activeRole.collectAsStateWithLifecycle(initialValue = null)
    val activeRole = activeRoleKey?.let { com.equipseva.app.features.auth.UserRole.fromKey(it) }
    val visibleTabs = tabsForRole(activeRole)
    val engineerStatus by deepLinkHost.engineerStatus.collectAsStateWithLifecycle()

    Scaffold(
        bottomBar = {
            if (!isFullScreenRoute) {
                com.equipseva.app.designsystem.components.EsBottomNav(
                    tabs = visibleTabs,
                    currentRoute = backStack?.destination?.hierarchy
                        ?.firstOrNull { dest -> visibleTabs.any { it.route == dest.route } }
                        ?.route,
                    onSelect = { route ->
                        // Jobs tab on the engineer-side bottom nav is gated
                        // by KYC. activeRole may not be set on signup yet,
                        // so we trigger off the route + engineerStatus alone.
                        val isEngineerJobsTab = route == Routes.ENGINEER_JOBS_HUB
                        val gateMsg: String? = if (isEngineerJobsTab) {
                            when (engineerStatus) {
                                com.equipseva.app.core.data.engineers.VerificationStatus.Pending ->
                                    "KYC under review — you'll be able to bid once verified (usually within 24h)."
                                com.equipseva.app.core.data.engineers.VerificationStatus.Rejected ->
                                    "KYC was rejected. Open Profile → Verification to fix and re-submit."
                                null ->
                                    "Submit your KYC first — open Profile → Verification."
                                com.equipseva.app.core.data.engineers.VerificationStatus.Verified -> null
                            }
                        } else null

                        if (gateMsg != null) {
                            showSnackbar(gateMsg)
                        } else {
                            navController.navigate(route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                    inclusive = false
                                }
                                launchSingleTop = true
                                restoreState = (route != Routes.PROFILE)
                            }
                        }
                    },
                )
            }
        },
        snackbarHost = {
            SnackbarHost(snackbarHost) { data ->
                // Match `shared.jsx` toast aesthetic — dark green-900 surface,
                // white text, 12dp radius, no Material accent line.
                Snackbar(
                    snackbarData = data,
                    containerColor = com.equipseva.app.designsystem.theme.SevaGreen900,
                    contentColor = androidx.compose.ui.graphics.Color.White,
                    actionColor = com.equipseva.app.designsystem.theme.SevaGlowRaw,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        },
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
                // v1: Home tab — role-aware tiles per design.
                //   Hospital: Book engineer / My bookings / Messages
                //   Engineer: Today's jobs / Active work / Earnings
                //   Founder gets the admin tile in addition.
                com.equipseva.app.features.home.HomeHubScreen(
                    onOpenBookRepair = { navController.navigate(Routes.ENGINEER_DIRECTORY) },
                    onOpenEngineerJobs = { navController.navigate(Routes.ENGINEER_JOBS_HUB) },
                    onOpenFounder = { navController.navigate(Routes.FOUNDER_DASHBOARD) },
                    onOpenNotifications = { navController.navigate(Routes.NOTIFICATIONS) },
                    onOpenKyc = { navController.navigate(Routes.KYC) },
                    onOpenAddPhone = { navController.navigate(Routes.ADD_PHONE) },
                    onOpenMyBookings = { navController.navigate(Routes.HOSPITAL_ACTIVE_JOBS) },
                    onOpenMessages = { navController.navigate(Routes.CONVERSATIONS) },
                    onOpenActiveWork = { navController.navigate(Routes.ACTIVE_WORK) },
                    onOpenEarnings = { navController.navigate(Routes.EARNINGS) },
                    onOpenEngineerProfile = { id ->
                        navController.navigate(Routes.engineerPublicProfileRoute(id))
                    },
                    onOpenAmcContracts = { navController.navigate(Routes.AMC_CONTRACTS_LIST) },
                    onShowMessage = showSnackbar,
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
                    onBack = null,
                    onAvailableJobs = { navController.navigate(Routes.REPAIR) },
                    onMyBids = { navController.navigate(Routes.MY_BIDS) },
                    onActiveWork = { navController.navigate(Routes.ACTIVE_WORK) },
                    onEarnings = { navController.navigate(Routes.EARNINGS) },
                    onEditProfile = { navController.navigate(Routes.ENGINEER_PROFILE) },
                    onServiceLocation = { navController.navigate(Routes.ENGINEER_LOCATION) },
                    onSubmitKyc = { navController.navigate(Routes.KYC) },
                    onSignIn = { onSignIn() },
                    onAmcVisits = { navController.navigate(Routes.ENGINEER_AMC_VISITS) },
                    onMyDisputes = { navController.navigate(Routes.ENGINEER_MY_DISPUTES) },
                )
            }
            composable(Routes.ENGINEER_AMC_VISITS) {
                com.equipseva.app.features.engineer.EngineerAmcVisitsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenVisit = { visitId ->
                        navController.navigate(Routes.repairJobDetailRoute(visitId))
                    },
                )
            }
            composable(Routes.HOSPITAL_MY_DISPUTES) {
                com.equipseva.app.features.hospital.HospitalMyDisputesScreen(
                    onBack = { navController.popBackStack() },
                    onOpenJob = { jobId ->
                        navController.navigate(Routes.repairJobDetailRoute(jobId))
                    },
                )
            }
            composable(Routes.ENGINEER_MY_DISPUTES) {
                com.equipseva.app.features.engineer.EngineerMyDisputesScreen(
                    onBack = { navController.popBackStack() },
                    onOpenJob = { jobId ->
                        navController.navigate(Routes.repairJobDetailRoute(jobId))
                    },
                )
            }
            composable(Routes.ENGINEER_LOCATION) {
                com.equipseva.app.features.engineer.EngineerLocationScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.ENGINEER_DIRECTORY) {
                com.equipseva.app.features.repair.directory.EngineerDirectoryScreen(
                    onBack = { navController.popBackStack() },
                    onOpenProfile = { id ->
                        navController.navigate(Routes.engineerPublicProfileRoute(id))
                    },
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
                    onOpenConversation = { conversationId ->
                        navController.navigate(Routes.chatRoute(conversationId))
                    },
                    onShowMessage = showSnackbar,
                    onSetupMaintenance = { engineerId ->
                        navController.navigate(Routes.createAmcRoute(engineerId))
                    },
                )
            }
            // v2.1 PR-C6 — AMC (Annual Maintenance Contract) surfaces.
            composable(Routes.AMC_CONTRACTS_LIST) {
                com.equipseva.app.features.amc.MaintenanceContractsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenContract = { contractId ->
                        navController.navigate(Routes.amcContractDetailRoute(contractId))
                    },
                    onBrowseEngineers = {
                        navController.navigate(Routes.ENGINEER_DIRECTORY)
                    },
                )
            }
            composable(
                route = "${Routes.AMC_CONTRACT_DETAIL}/{${Routes.AMC_CONTRACT_DETAIL_ARG_ID}}",
                arguments = listOf(
                    navArgument(Routes.AMC_CONTRACT_DETAIL_ARG_ID) { type = NavType.StringType },
                ),
            ) {
                com.equipseva.app.features.amc.AmcDetailScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                    onRenew = { engineerId, sourceContractId ->
                        navController.navigate(
                            Routes.createAmcRouteWithSource(engineerId, sourceContractId),
                        )
                    },
                    onOpenConversation = { conversationId ->
                        navController.navigate(Routes.chatRoute(conversationId))
                    },
                )
            }
            composable(
                route = "${Routes.CREATE_AMC}/{${Routes.CREATE_AMC_ARG_ENGINEER_ID}}"
                    + "?${Routes.CREATE_AMC_ARG_SOURCE_ID}={${Routes.CREATE_AMC_ARG_SOURCE_ID}}",
                arguments = listOf(
                    navArgument(Routes.CREATE_AMC_ARG_ENGINEER_ID) { type = NavType.StringType },
                    navArgument(Routes.CREATE_AMC_ARG_SOURCE_ID) {
                        type = NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
            ) {
                com.equipseva.app.features.amc.CreateAmcWizardScreen(
                    onBack = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                    onCreated = { contractId ->
                        navController.navigate(Routes.amcContractDetailRoute(contractId)) {
                            // Pop the wizard so Back from detail goes
                            // back to the engineer profile, not the
                            // wizard.
                            popUpTo(Routes.CREATE_AMC) { inclusive = true }
                        }
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
                    onOpenMaintenanceContracts = { navController.navigate(Routes.AMC_CONTRACTS_LIST) },
                    onOpenMyDisputes = { navController.navigate(Routes.HOSPITAL_MY_DISPUTES) },
                    onOpenPublicPreview = { engineerId ->
                        navController.navigate(Routes.engineerPublicProfileRoute(engineerId))
                    },
                    onOpenHelp = {
                        // Open a mailto: intent so the user lands in their
                        // email composer pre-addressed to support — no in-app
                        // ticketing system yet.
                        val ctx = navController.context
                        val intent = android.content.Intent(android.content.Intent.ACTION_SENDTO).apply {
                            data = "mailto:support@equipseva.com".toUri()
                            putExtra(android.content.Intent.EXTRA_SUBJECT, "EquipSeva support request")
                        }
                        try {
                            ctx.startActivity(intent)
                        } catch (_: android.content.ActivityNotFoundException) {
                            showSnackbar("No email app installed")
                        }
                    },
                    onSignIn = onSignIn,
                    onSwitchService = {
                        navController.navigate(Routes.HOME) {
                            popUpTo(Routes.HOME) { inclusive = true }
                            launchSingleTop = true
                        }
                    },
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
                    onOpenJob = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                )
            }
            composable(Routes.MY_BIDS) {
                MyBidsScreen(
                    onBack = { navController.popBackStack() },
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                    onBrowseJobs = { navController.navigate(Routes.REPAIR) },
                )
            }
            composable(Routes.EARNINGS) {
                // Earnings is reachable both as the engineer bottom-nav tab
                // root AND from the Jobs hub tile. We drop the in-screen
                // back arrow because at the tab root it would be redundant
                // with the bottom nav, and from the hub the system back
                // gesture pops cleanly back to the hub.
                EarningsScreen(
                    onBack = null,
                    onJobClick = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
                    onBankDetails = { navController.navigate(Routes.PROFILE_BANK_DETAILS) },
                    onBrowseJobs = { navController.navigate(Routes.REPAIR) },
                    onOpenActiveEscrows = { navController.navigate(Routes.ENGINEER_ACTIVE_ESCROWS) },
                )
            }
            composable(Routes.ENGINEER_ACTIVE_ESCROWS) {
                com.equipseva.app.features.earnings.EngineerActiveEscrowsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenJob = { jobId -> navController.navigate(Routes.repairJobDetailRoute(jobId)) },
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
            composable(Routes.HOSPITAL_ONBOARDING) {
                // v0.2.0 mandatory onboarding for hospital admins (phone +
                // state + district). On Done we pop the back stack so the
                // user lands on whatever was below (Home, typically). The
                // PR #1017 AppNavGraph auto-gate also mounts this screen
                // outside the main graph for cold-start; both entries
                // share the same pop semantics.
                com.equipseva.app.features.onboarding.HospitalOnboardingScreen(
                    onDone = { navController.popBackStack() },
                    onShowMessage = showSnackbar,
                )
            }
            composable(Routes.ENGINEER_ONBOARDING) {
                // Engineer counterpart — same shape, same nav semantics.
                // After save, AppNavGraph's session-state gate hands the
                // engineer back to Home where the existing KYC banner
                // pushes them onward to verification.
                com.equipseva.app.features.onboarding.EngineerOnboardingScreen(
                    onDone = { navController.popBackStack() },
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
                    onOpenEscrowDisputes = { navController.navigate(Routes.FOUNDER_ESCROW_DISPUTES) },
                    onOpenAmcEscalations = { navController.navigate(Routes.FOUNDER_AMC_ESCALATIONS) },
                    onOpenCashSuspended = { navController.navigate(Routes.FOUNDER_CASH_SUSPENDED) },
                    onOpenPartsOutliers = { navController.navigate(Routes.FOUNDER_PARTS_OUTLIERS) },
                    onOpenResolvedDisputes = { navController.navigate(Routes.FOUNDER_RESOLVED_DISPUTES) },
                    onOpenSpotAudits = { navController.navigate(Routes.FOUNDER_SPOT_AUDITS) },
                    onOpenAmcExpiring = { navController.navigate(Routes.FOUNDER_AMC_EXPIRING) },
                    onOpenInactiveEngineers = { navController.navigate(Routes.FOUNDER_INACTIVE_ENGINEERS) },
                    onOpenAmcPaused = { navController.navigate(Routes.FOUNDER_AMC_PAUSED) },
                    onOpenEngineerProfile = { engineerId ->
                        navController.navigate(Routes.engineerPublicProfileRoute(engineerId))
                    },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_ESCROW_DISPUTES) {
                com.equipseva.app.features.founder.FounderEscrowDisputesScreen(
                    onBack = { navController.popBackStack() },
                    onOpenTimeline = { escrowId ->
                        navController.navigate(Routes.founderEscrowDisputeDetailRoute(escrowId))
                    },
                )
            }
            composable(Routes.FOUNDER_RESOLVED_DISPUTES) {
                com.equipseva.app.features.founder.FounderResolvedDisputesScreen(
                    onBack = { navController.popBackStack() },
                    onOpenTimeline = { escrowId ->
                        navController.navigate(Routes.founderEscrowDisputeDetailRoute(escrowId))
                    },
                )
            }
            composable(Routes.FOUNDER_SPOT_AUDITS) {
                com.equipseva.app.features.founder.FounderSpotAuditsScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(
                route = "${Routes.FOUNDER_ESCROW_DISPUTE_DETAIL}/{${Routes.FOUNDER_ESCROW_DISPUTE_DETAIL_ARG_ESCROW_ID}}",
                arguments = listOf(
                    androidx.navigation.navArgument(Routes.FOUNDER_ESCROW_DISPUTE_DETAIL_ARG_ESCROW_ID) {
                        type = androidx.navigation.NavType.StringType
                    },
                ),
            ) {
                com.equipseva.app.features.founder.FounderEscrowDisputeDetailScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_AMC_ESCALATIONS) {
                com.equipseva.app.features.founder.FounderAmcEscalationsScreen(
                    onBack = { navController.popBackStack() },
                    onOpenDetail = { escalationId ->
                        navController.navigate(Routes.founderAmcEscalationDetailRoute(escalationId))
                    },
                )
            }
            composable(
                route = "${Routes.FOUNDER_AMC_ESCALATION_DETAIL}/{${Routes.FOUNDER_AMC_ESCALATION_DETAIL_ARG_ESCALATION_ID}}",
                arguments = listOf(
                    androidx.navigation.navArgument(Routes.FOUNDER_AMC_ESCALATION_DETAIL_ARG_ESCALATION_ID) {
                        type = androidx.navigation.NavType.StringType
                    },
                ),
            ) {
                com.equipseva.app.features.founder.FounderAmcEscalationDetailScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_CASH_SUSPENDED) {
                com.equipseva.app.features.founder.FounderCashSuspendedScreen(
                    onBack = { navController.popBackStack() },
                    onOpenHistory = { engineerId ->
                        navController.navigate(Routes.founderCashFlagHistoryRoute(engineerId))
                    },
                )
            }
            composable(
                route = "${Routes.FOUNDER_CASH_FLAG_HISTORY}/{${Routes.FOUNDER_CASH_FLAG_HISTORY_ARG_ENGINEER_ID}}",
                arguments = listOf(
                    androidx.navigation.navArgument(Routes.FOUNDER_CASH_FLAG_HISTORY_ARG_ENGINEER_ID) {
                        type = androidx.navigation.NavType.StringType
                    },
                ),
            ) {
                com.equipseva.app.features.founder.FounderCashFlagHistoryScreen(
                    onBack = { navController.popBackStack() },
                )
            }
            composable(Routes.FOUNDER_PARTS_OUTLIERS) {
                com.equipseva.app.features.founder.FounderPartsOutliersScreen(
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
                    onOpenReview = { userId ->
                        navController.navigate(Routes.founderKycReviewRoute(userId))
                    },
                )
            }
            composable(
                route = "${Routes.FOUNDER_KYC_REVIEW}/{${Routes.FOUNDER_KYC_REVIEW_ARG_USER_ID}}",
                arguments = listOf(
                    androidx.navigation.navArgument(Routes.FOUNDER_KYC_REVIEW_ARG_USER_ID) {
                        type = androidx.navigation.NavType.StringType
                    },
                ),
            ) {
                com.equipseva.app.features.founder.FounderKycReviewScreen(
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
                    onOpenBuyerIntegrity = { userId, name ->
                        navController.navigate(Routes.founderIntegrityRoute(userId, name))
                    },
                )
            }
            composable(
                route = "${Routes.FOUNDER_INTEGRITY}?${Routes.FOUNDER_INTEGRITY_ARG_USER}={${Routes.FOUNDER_INTEGRITY_ARG_USER}}&${Routes.FOUNDER_INTEGRITY_ARG_NAME}={${Routes.FOUNDER_INTEGRITY_ARG_NAME}}",
                arguments = listOf(
                    androidx.navigation.navArgument(Routes.FOUNDER_INTEGRITY_ARG_USER) {
                        type = androidx.navigation.NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                    androidx.navigation.navArgument(Routes.FOUNDER_INTEGRITY_ARG_NAME) {
                        type = androidx.navigation.NavType.StringType
                        nullable = true
                        defaultValue = null
                    },
                ),
            ) {
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

            composable(Routes.FOUNDER_AMC_EXPIRING) {
                com.equipseva.app.features.founder.FounderAmcExpiringScreen(
                    onBack = { navController.popBackStack() },
                    onOpenContract = { contractId ->
                        navController.navigate(Routes.amcContractDetailRoute(contractId))
                    },
                )
            }

            composable(Routes.FOUNDER_INACTIVE_ENGINEERS) {
                com.equipseva.app.features.founder.FounderInactiveEngineersScreen(
                    onBack = { navController.popBackStack() },
                    onOpenEngineer = { engineerId ->
                        navController.navigate(Routes.engineerPublicProfileRoute(engineerId))
                    },
                )
            }

            composable(Routes.FOUNDER_AMC_PAUSED) {
                com.equipseva.app.features.founder.FounderPausedAmcScreen(
                    onBack = { navController.popBackStack() },
                    onOpenContract = { contractId ->
                        navController.navigate(Routes.amcContractDetailRoute(contractId))
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
    val target = resolveNotificationDeepLink(link)
    if (target == null) {
        if (link.isNotBlank()) showSnackbar("Couldn't open that link")
        return
    }
    navController.navigate(target)
}

/**
 * Pure resolver: maps a deep-link string (app://, equipseva://, or a
 * bare top-level route) to a NavGraph route, or null if the link is
 * blank/unparseable. Extracted to keep the side-effecting NavController
 * wrapper thin and the link parsing testable.
 */
/**
 * True when [route] is a destination that should take over the
 * screen and hide the bottom navigation bar. Pure helper extracted so
 * the route → bottom-bar visibility decision can be unit-tested
 * without standing up a NavController. Match semantics are prefix —
 * sub-routes (e.g. `repair/detail/<id>`) inherit the parent's
 * full-screen flag.
 */
internal fun isFullScreenRoute(route: String?): Boolean {
    if (route == null) return false
    return fullScreenRoutePrefixes.any { route.startsWith(it) }
}

internal fun resolveNotificationDeepLink(link: String): String? {
    val trimmed = link.trim().ifBlank { return null }

    val uuidRegex =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

    return when {
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
}
