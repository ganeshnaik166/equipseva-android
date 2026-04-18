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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.equipseva.app.features.cart.CartScreen
import com.equipseva.app.features.home.HomeScreen
import com.equipseva.app.features.marketplace.MarketplaceScreen
import com.equipseva.app.features.marketplace.PartDetailScreen
import com.equipseva.app.features.orders.OrdersScreen
import com.equipseva.app.features.profile.ProfileScreen
import com.equipseva.app.features.repair.RepairJobsScreen
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
private val fullScreenRoutePrefixes = listOf(Routes.MARKETPLACE_DETAIL, Routes.CART)

@Composable
fun MainNavGraph() {
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val snackbarHost = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    val showSnackbar: (String) -> Unit = { msg ->
        scope.launch { snackbarHost.showSnackbar(msg) }
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
            composable(Routes.HOME) { HomeScreen(onShowMessage = showSnackbar) }
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
            composable(Routes.ORDERS) { OrdersScreen() }
            composable(Routes.REPAIR) { RepairJobsScreen() }
            composable(Routes.PROFILE) {
                ProfileScreen(onShowMessage = showSnackbar)
            }
            composable(Routes.CART) {
                CartScreen(
                    onBack = { navController.popBackStack() },
                    onBrowseParts = {
                        navController.navigate(Routes.MARKETPLACE) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
        }
    }
}
