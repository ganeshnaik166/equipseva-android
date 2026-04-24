package com.equipseva.app.features.orders

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import androidx.compose.material.icons.outlined.Inventory

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RateOrderScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit = {},
    viewModel: RateOrderViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is RateOrderViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                RateOrderViewModel.Effect.Done -> onBack()
            }
        }
    }

    val title = state.order?.orderNumber?.let { "Rate order #$it" } ?: "Rate order"

    Scaffold(
        topBar = { ESBackTopBar(title = title, onBack = onBack) },
    ) { inner ->
        Box(modifier = Modifier.padding(inner).fillMaxSize()) {
            when {
                state.loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

                state.notFound -> EmptyStateView(
                    icon = Icons.Outlined.Inventory,
                    title = "Order not found",
                    subtitle = "It may have been removed or is not visible to you.",
                )

                state.ineligibleReason != null -> EmptyStateView(
                    icon = Icons.Outlined.Inventory,
                    title = "Can't rate yet",
                    subtitle = state.ineligibleReason,
                )

                else -> RateOrderBody(
                    stars = state.stars,
                    comment = state.comment,
                    submitting = state.submitting,
                    submitted = state.submitted,
                    canSubmit = state.canSubmit,
                    errorMessage = state.errorMessage,
                    onStarsChange = viewModel::onStarsChange,
                    onCommentChange = viewModel::onCommentChange,
                    onSubmit = viewModel::submit,
                )
            }
        }
    }
}

@Composable
private fun RateOrderBody(
    stars: Int,
    comment: String,
    submitting: Boolean,
    submitted: Boolean,
    canSubmit: Boolean,
    errorMessage: String?,
    onStarsChange: (Int) -> Unit,
    onCommentChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(
            text = if (submitted) "Thanks — your rating is locked in." else "How was this supplier?",
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink900,
        )
        Text(
            text = if (submitted) {
                "We use these ratings to surface the best suppliers to other hospitals."
            } else {
                "Pick 1–5 stars. Your comment is optional and visible to other buyers."
            },
            fontSize = 13.sp,
            color = Ink500,
        )

        StarPicker(
            stars = stars,
            enabled = !submitting && !submitted,
            onStarsChange = onStarsChange,
        )

        OutlinedTextField(
            value = comment,
            onValueChange = onCommentChange,
            label = { Text("Comment (optional)") },
            supportingText = {
                Text(
                    text = "${comment.length} / ${RateOrderViewModel.MAX_COMMENT_LEN}",
                    fontSize = 11.sp,
                    color = Ink500,
                )
            },
            maxLines = 6,
            enabled = !submitting && !submitted,
            modifier = Modifier.fillMaxWidth(),
        )

        if (!errorMessage.isNullOrBlank()) {
            ErrorBanner(message = errorMessage)
        }

        Spacer(modifier = Modifier.height(Spacing.sm))

        PrimaryButton(
            label = when {
                submitted -> "Rating submitted"
                submitting -> "Submitting…"
                else -> "Submit rating"
            },
            onClick = onSubmit,
            enabled = canSubmit,
            loading = submitting,
        )

        if (submitted && !comment.isBlank()) {
            Text(
                text = "\"$comment\"",
                fontSize = 13.sp,
                color = Ink700,
            )
        }
    }
}

@Composable
private fun StarPicker(
    stars: Int,
    enabled: Boolean,
    onStarsChange: (Int) -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        (1..5).forEach { n ->
            val filled = n <= stars
            IconButton(
                onClick = { if (enabled) onStarsChange(n) },
                enabled = enabled,
                modifier = Modifier.size(44.dp),
            ) {
                Icon(
                    imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarOutline,
                    contentDescription = "$n star",
                    tint = if (filled) Color(0xFFF5A623) else Ink500,
                    modifier = Modifier.size(32.dp),
                )
            }
        }
    }
}
