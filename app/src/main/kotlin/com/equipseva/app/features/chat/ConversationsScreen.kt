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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ListSkeleton
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConversationsScreen(
    onBack: () -> Unit,
    onConversationClick: (String) -> Unit,
    viewModel: ConversationsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Messages", onBack = onBack)
            ErrorBanner(message = state.errorMessage)
            QueuedPill(count = state.queuedCount)
            if (!state.loading && state.rows.isNotEmpty()) {
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                    EsField(
                        value = state.query,
                        onChange = viewModel::onQueryChange,
                        placeholder = "Search conversations",
                        leading = {
                            Icon(
                                Icons.Filled.Search,
                                contentDescription = null,
                                tint = SevaInk500,
                                modifier = Modifier.size(18.dp),
                            )
                        },
                    )
                }
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
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.White),
                        contentPadding = PaddingValues(vertical = 0.dp),
                    ) {
                        items(items = state.displayedRows, key = { it.conversation.id }) { row ->
                            ConversationRow(
                                row = row,
                                onClick = { onConversationClick(row.conversation.id) },
                            )
                            HorizontalDivider(color = BorderDefault, thickness = 1.dp)
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
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        InitialsAvatar(name = row.title)
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = row.title,
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                val ts = row.conversation.lastMessageInstant?.let { relativeLabel(it) }
                if (!ts.isNullOrBlank()) {
                    Text(
                        text = ts,
                        style = EsType.Caption,
                        color = SevaInk400,
                    )
                }
            }
            Row(
                modifier = Modifier.padding(top = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = row.preview,
                    style = if (row.conversation.unreadCount > 0)
                        EsType.BodySm.copy(fontWeight = FontWeight.SemiBold)
                    else EsType.BodySm,
                    color = if (row.conversation.unreadCount > 0) SevaInk900 else SevaInk500,
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
            .size(18.dp)
            .clip(CircleShape)
            .background(SevaGreen700),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = EsType.Caption.copy(fontWeight = FontWeight.Bold),
            color = Color.White,
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
            .size(44.dp)
            .clip(CircleShape)
            .background(SevaGreen50),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = initials,
            style = EsType.Body.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen900,
        )
    }
}

@Composable
private fun QueuedPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = if (count == 1) "1 message queued — will send when back online"
            else "$count messages queued — will send when back online",
            style = EsType.Caption,
            color = SevaInk900,
        )
    }
}
