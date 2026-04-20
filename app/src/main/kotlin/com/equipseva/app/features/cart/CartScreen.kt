package com.equipseva.app.features.cart

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.outlined.ShoppingCartCheckout
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.cart.CartItem
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.QuantityStepper
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import androidx.compose.material.icons.filled.MedicalServices
import kotlinx.coroutines.launch

@Composable
fun CartScreen(
    onBack: () -> Unit,
    onCheckout: () -> Unit = {},
    onBrowseParts: () -> Unit = {},
    viewModel: CartViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is CartViewModel.Effect.ShowMessage -> snackbarHostState.showSnackbar(effect.text)
                CartViewModel.Effect.OpenCheckout -> onCheckout()
            }
        }
    }

    // Cart only shows the item subtotal. Per-line GST depends on each part's
    // gstRatePercent and is computed in CheckoutViewModel; delivery is chosen
    // there too. Showing a fabricated flat 12% here drifted from the real total.
    val subtotalRupees = state.totalInPaise / 100.0

    val title = if (state.items.isNotEmpty()) "Cart · ${state.items.size}" else "Cart"
    Scaffold(
        topBar = { ESBackTopBar(title = title, onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        containerColor = Surface50,
        bottomBar = {
            if (state.items.isNotEmpty()) {
                CheckoutBottomBar(
                    subtotalRupees = subtotalRupees,
                    onCheckout = viewModel::onCheckout,
                )
            }
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .background(Surface50),
        ) {
            when {
                state.loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

                state.items.isEmpty() -> EmptyCart(onBrowseParts = onBrowseParts)

                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        horizontal = Spacing.lg,
                        vertical = Spacing.sm,
                    ),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(items = state.items, key = { it.partId }) { line ->
                        CartLineRow(
                            item = line,
                            onIncrement = { viewModel.onIncrement(line.partId) },
                            onDecrement = { viewModel.onDecrement(line.partId) },
                            onRemove = { viewModel.onRemove(line.partId) },
                        )
                    }
                    item("coupon") {
                        CouponRow(
                            onClick = {
                                scope.launch {
                                    snackbarHostState.showSnackbar("Promo codes coming soon")
                                }
                            },
                        )
                    }
                    item("summary") {
                        SummaryCard(subtotal = subtotalRupees)
                    }
                    item("trailing_spacer") {
                        Spacer(Modifier.height(Spacing.md))
                    }
                }
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Cart line                                                          */
/* ------------------------------------------------------------------ */

@Composable
private fun CartLineRow(
    item: CartItem,
    onIncrement: () -> Unit,
    onDecrement: () -> Unit,
    onRemove: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(5.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            GradientTile(
                icon = Icons.Filled.MedicalServices,
                hue = 40,
                size = 72.dp,
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = item.name,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                    maxLines = 2,
                )
                Spacer(Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    QuantityStepper(
                        value = item.quantity,
                        onDecrement = onDecrement,
                        onIncrement = onIncrement,
                    )
                    Text(
                        text = formatRupees((item.unitPriceInPaise * item.quantity) / 100.0),
                        fontSize = 15.sp,
                        lineHeight = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Ink900,
                    )
                }
            }

            IconButton(onClick = onRemove, modifier = Modifier.size(32.dp)) {
                Icon(
                    imageVector = Icons.Filled.Delete,
                    contentDescription = "Remove ${item.name} from cart",
                    tint = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Coupon pill                                                        */
/* ------------------------------------------------------------------ */

@Composable
private fun CouponRow(onClick: () -> Unit) {
    // Dashed border is non-trivial without a custom drawBehind; use a dotted-style
    // 1.5dp solid border to stay close to the spec.
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(50))
            .background(Surface0)
            .border(1.5.dp, Surface200, RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.LocalOffer,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = "Have a coupon?",
            fontSize = 14.sp,
            color = Ink500,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = "Apply",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = BrandGreen,
        )
    }
}

/* ------------------------------------------------------------------ */
/* Summary card                                                       */
/* ------------------------------------------------------------------ */

@Composable
private fun SummaryCard(subtotal: Double) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(5.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.5.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Subtotal",
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                Text(
                    text = formatRupees(subtotal),
                    fontSize = 18.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = BrandGreenDark,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = "GST and delivery are calculated at checkout.",
                fontSize = 12.sp,
                lineHeight = 16.sp,
                color = Ink500,
            )
        }
    }
}

/* ------------------------------------------------------------------ */
/* Bottom bar                                                         */
/* ------------------------------------------------------------------ */

@Composable
private fun CheckoutBottomBar(subtotalRupees: Double, onCheckout: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(0.dp))
            .padding(16.dp),
    ) {
        Button(
            onClick = onCheckout,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = BrandGreen),
        ) {
            Text(
                text = "Checkout \u00b7 ${formatRupees(subtotalRupees)}",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.width(8.dp))
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/* ------------------------------------------------------------------ */
/* Empty                                                              */
/* ------------------------------------------------------------------ */

@Composable
private fun EmptyCart(onBrowseParts: () -> Unit) {
    EmptyStateView(
        icon = Icons.Outlined.ShoppingCartCheckout,
        title = "Your cart is empty",
        subtitle = "Browse parts to add them here.",
        ctaLabel = "Browse marketplace",
        onCta = onBrowseParts,
    )
}

