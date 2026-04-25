package com.equipseva.app.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.ListSkeleton
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface100

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConversationsScreen(
    onBack: () -> Unit,
    onConversationClick: (String) -> Unit,
    viewModel: ConversationsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        "Messages",
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = Ink900,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Ink900,
                        )
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            QueuedPill(count = state.queuedCount)
            if (!state.loading && state.rows.isNotEmpty()) {
                OutlinedTextField(
                    value = state.query,
                    onValueChange = viewModel::onQueryChange,
                    placeholder = { Text("Search conversations") },
                    leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null, tint = Ink500) },
                    trailingIcon = if (state.query.isNotEmpty()) {
                        {
                            IconButton(onClick = { viewModel.onQueryChange("") }) {
                                Icon(Icons.Filled.Clear, contentDescription = "Clear search", tint = Ink500)
                            }
                        }
                    } else null,
                    singleLine = true,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                )
            }
            when {
                state.loading && state.rows.isEmpty() -> ListSkeleton(rows = 8)
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.ChatBubbleOutline,
                    title = "No conversations yet",
                    subtitle = "Reach out from a repair job to start chatting.",
                )
                state.displayedRows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.ChatBubbleOutline,
                    title = "No matches",
                    subtitle = "Try another name or word.",
                )
                else -> PullToRefreshBox(
                    isRefreshing = state.refreshing,
                    onRefresh = viewModel::refresh,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 0.dp),
                    ) {
                        items(items = state.displayedRows, key = { it.conversation.id }) { row ->
                            ConversationRow(
                                row = row,
                                onClick = { onConversationClick(row.conversation.id) },
                            )
                            HorizontalDivider(color = Surface100, thickness = 1.dp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ConversationRow(
    row: ConversationsViewModel.Row,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm + 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm + 4.dp),
    ) {
        InitialsAvatar(name = row.title)
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = row.title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                val ts = row.conversation.lastMessageInstant?.let { relativeLabel(it) }
                if (!ts.isNullOrBlank()) {
                    Text(
                        text = ts,
                        fontSize = 11.sp,
                        fontWeight = if (row.conversation.unreadCount > 0) FontWeight.Bold else FontWeight.Medium,
                        color = if (row.conversation.unreadCount > 0) BrandGreen else Ink500,
                    )
                }
            }
            Row(
                modifier = Modifier.padding(top = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = row.preview,
                    fontSize = 13.sp,
                    fontWeight = if (row.conversation.unreadCount > 0) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (row.conversation.unreadCount > 0) Ink900 else Ink500,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                if (row.conversation.unreadCount > 0) {
                    UnreadBadge(count = row.conversation.unreadCount)
                }
            }
        }
    }
}

@Composable
private fun UnreadBadge(count: Int) {
    val label = if (count > 99) "99+" else count.toString()
    Box(
        modifier = Modifier
            .padding(start = 8.dp)
            .size(20.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primary),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onPrimary,
        )
    }
}

@Composable
private fun InitialsAvatar(name: String) {
    val initials = name
        .split(" ", limit = 2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }
        .joinToString("")
        .take(2)
        .ifBlank { "?" }
    Box(
        modifier = Modifier
            .size(48.dp)
            .clip(CircleShape)
            .background(BrandGreen50)
            .border(1.dp, Color(0x14000000), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = initials,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = BrandGreen,
        )
    }
}

@Composable
private fun QueuedPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
            .clip(RoundedCornerShape(12.dp))
            .background(BrandGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = if (count == 1) "1 message queued — will send when back online"
            else "$count messages queued — will send when back online",
            fontSize = 13.sp,
            color = Ink900,
        )
    }
}

