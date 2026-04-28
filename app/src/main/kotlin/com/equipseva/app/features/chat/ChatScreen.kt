package com.equipseva.app.features.chat

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.chat.ChatMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.ReportContentSheet
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.CloudSync
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun ChatScreen(
    onBack: () -> Unit,
    viewModel: ChatViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val listState = rememberLazyListState()

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is ChatViewModel.Effect.ShowMessage -> snackbarHostState.showSnackbar(effect.text)
            }
        }
    }

    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.lastIndex)
        }
    }

    Scaffold(
        containerColor = com.equipseva.app.designsystem.theme.PaperDefault,
        topBar = {
            ChatTopBar(
                title = state.title,
                counterpartBlocked = state.counterpartBlocked,
                canBlock = state.counterpart != null && !state.togglingBlock,
                onBack = onBack,
                onToggleBlock = viewModel::onToggleBlock,
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            Column {
                if (state.editingMessageId != null) {
                    EditMessageBar(
                        draft = state.editDraft,
                        canSubmit = state.canSubmitEdit,
                        submitting = state.editing,
                        onDraftChange = viewModel::onEditDraftChange,
                        onSubmit = viewModel::onSubmitEdit,
                        onCancel = viewModel::onCancelEdit,
                    )
                }
                TypingIndicatorRow(visible = state.typingUserIds.isNotEmpty())
                ChatInputBar(
                    draft = state.draft,
                    canSend = state.canSend,
                    onDraftChange = viewModel::onDraftChange,
                    onSend = viewModel::onSend,
                )
            }
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
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.messages.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.ChatBubbleOutline,
                    title = "Say hello",
                    subtitle = "This is the start of your conversation.",
                )
                else -> LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        horizontal = 14.dp,
                        vertical = Spacing.md,
                    ),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(items = state.messages, key = { it.id }) { msg ->
                        MessageRow(
                            message = msg,
                            isSelf = msg.senderUserId == state.selfUserId,
                            onReport = viewModel::onOpenReport,
                            onDelete = viewModel::onDeleteMessage,
                            onEdit = viewModel::onOpenEdit,
                        )
                    }
                }
            }
        }
    }

    if (state.reportingMessageId != null) {
        ReportContentSheet(
            titleLabel = "Report this message",
            submitting = state.submittingReport,
            onDismiss = viewModel::onDismissReport,
            onSubmit = viewModel::onSubmitReport,
        )
    }
}

@Composable
private fun TypingIndicatorRow(visible: Boolean) {
    if (!visible) return
    // Low-res tick (~450ms) drives a three-dot phase; good enough to read as "alive"
    // without burning a recomposition per frame. Re-emits while the indicator is shown.
    val phase = remember { androidx.compose.runtime.mutableIntStateOf(0) }
    androidx.compose.runtime.LaunchedEffect(visible) {
        while (true) {
            kotlinx.coroutines.delay(450)
            phase.intValue = (phase.intValue + 1) % 3
        }
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        repeat(3) { i ->
            Box(
                modifier = Modifier
                    .size(5.dp)
                    .clip(CircleShape)
                    .background(if (i == phase.intValue) BrandGreen else Surface200),
            )
        }
        Text(
            text = "typing…",
            style = MaterialTheme.typography.bodySmall,
            color = Ink500,
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
            style = MaterialTheme.typography.bodySmall,
            color = Ink900,
        )
    }
}

@Composable
private fun ChatTopBar(
    title: String,
    counterpartBlocked: Boolean,
    canBlock: Boolean,
    onBack: () -> Unit,
    onToggleBlock: () -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp,
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = Ink900,
                    )
                }
                InitialsAvatar(name = title, size = 38.dp)
                Text(
                    text = title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
                if (canBlock) {
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = "More", tint = Ink900)
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = {
                                    Text(if (counterpartBlocked) "Unblock user" else "Block user")
                                },
                                onClick = {
                                    menuOpen = false
                                    onToggleBlock()
                                },
                            )
                        }
                    }
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Surface200),
            )
        }
    }
}

@Composable
private fun InitialsAvatar(name: String, size: androidx.compose.ui.unit.Dp) {
    val initials = name
        .split(" ", limit = 2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }
        .joinToString("")
        .take(2)
        .ifBlank { "?" }
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(BrandGreen50),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = initials,
            fontSize = (size.value * 0.32f).sp,
            fontWeight = FontWeight.Bold,
            color = BrandGreen,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageRow(
    message: ChatMessage,
    isSelf: Boolean,
    onReport: (String) -> Unit = {},
    onDelete: (String) -> Unit = {},
    onEdit: (String) -> Unit = {},
) {
    val isDeleted = message.isDeleted
    // Deleted bubbles fall back to a muted surface so the tombstone reads as disabled,
    // regardless of sender.
    val bubbleColor = when {
        isDeleted -> Surface100
        isSelf -> BrandGreen
        else -> MaterialTheme.colorScheme.surface
    }
    val textColor = when {
        isDeleted -> Ink500
        isSelf -> Color.White
        else -> Ink900
    }
    val shape = if (isSelf) {
        RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 16.dp, bottomEnd = 4.dp)
    } else {
        RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 4.dp, bottomEnd = 16.dp)
    }

    var menuOpen by remember { mutableStateOf(false) }

    // Long-press is used for per-message actions. Counterpart messages can be reported;
    // own messages can be deleted (soft). Deleted messages cannot be acted on further.
    val onLongClick: (() -> Unit)? = when {
        isDeleted -> null
        !isSelf -> { { onReport(message.id) } }
        else -> { { menuOpen = true } }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isSelf) Arrangement.End else Arrangement.Start,
    ) {
        Box {
            Box(
                modifier = Modifier
                    .widthIn(max = 280.dp)
                    .clip(shape)
                    .background(bubbleColor)
                    .then(
                        if (!isSelf || isDeleted) Modifier.border(1.dp, Surface200, shape) else Modifier,
                    )
                    .combinedClickable(
                        onClick = {},
                        onLongClick = onLongClick,
                    )
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Column {
                    if (isDeleted) {
                        Text(
                            text = "Message deleted",
                            fontSize = 14.sp,
                            lineHeight = 20.sp,
                            color = textColor,
                            fontStyle = FontStyle.Italic,
                        )
                    } else {
                        val images = message.attachments.filter { it.isImageUrl() }
                        if (images.isNotEmpty()) {
                            Column(
                                verticalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(bottom = if (message.message.isNotBlank()) 6.dp else 0.dp),
                            ) {
                                images.forEach { url ->
                                    AsyncImage(
                                        model = url,
                                        contentDescription = null,
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier
                                            .widthIn(max = 220.dp)
                                            .height(160.dp)
                                            .clip(RoundedCornerShape(12.dp)),
                                    )
                                }
                            }
                        }
                        if (message.message.isNotBlank()) {
                            Text(
                                text = message.message,
                                fontSize = 14.sp,
                                lineHeight = 20.sp,
                                color = textColor,
                            )
                        }
                    }
                    val timeLabel = formatTime(message.createdAtIso)
                    if (!timeLabel.isNullOrBlank()) {
                        val metaColor = when {
                            isDeleted -> Ink500
                            isSelf -> Color.White.copy(alpha = 0.8f)
                            else -> Ink500
                        }
                        Row(
                            modifier = Modifier
                                .align(Alignment.End)
                                .padding(top = 2.dp),
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            if (message.isEdited && !isDeleted) {
                                Text(
                                    text = "(edited)",
                                    fontSize = 10.sp,
                                    fontStyle = FontStyle.Italic,
                                    color = metaColor,
                                )
                            }
                            Text(
                                text = timeLabel,
                                fontSize = 10.sp,
                                color = metaColor,
                            )
                        }
                    }
                }
            }
            if (isSelf && !isDeleted) {
                DropdownMenu(
                    expanded = menuOpen,
                    onDismissRequest = { menuOpen = false },
                ) {
                    DropdownMenuItem(
                        text = { Text("Edit") },
                        onClick = {
                            menuOpen = false
                            onEdit(message.id)
                        },
                    )
                    DropdownMenuItem(
                        text = { Text("Delete") },
                        onClick = {
                            menuOpen = false
                            onDelete(message.id)
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatInputBar(
    draft: String,
    canSend: Boolean,
    onDraftChange: (String) -> Unit,
    onSend: () -> Unit,
) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp,
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Surface200),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(42.dp)
                        .clip(CircleShape)
                        .border(1.dp, Surface200, CircleShape)
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 14.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (draft.isEmpty()) {
                        Text(
                            text = "Message…",
                            fontSize = 14.sp,
                            color = Ink500,
                        )
                    }
                    BasicTextField(
                        value = draft,
                        onValueChange = onDraftChange,
                        textStyle = TextStyle(
                            fontSize = 14.sp,
                            color = Ink900,
                        ),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(BrandGreen),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(if (canSend) BrandGreen else Surface100)
                        .padding(10.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    IconButton(
                        onClick = onSend,
                        enabled = canSend,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.Send,
                            contentDescription = "Send",
                            tint = if (canSend) Color.White else Ink500,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EditMessageBar(
    draft: String,
    canSubmit: Boolean,
    submitting: Boolean,
    onDraftChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCancel: () -> Unit,
) {
    Surface(
        color = BrandGreen50,
        tonalElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Edit message",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = BrandGreen,
            )
            OutlinedTextField(
                value = draft,
                onValueChange = onDraftChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = false,
                maxLines = 4,
                enabled = !submitting,
                textStyle = TextStyle(fontSize = 14.sp, color = Ink900),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = onCancel, enabled = !submitting) {
                    Text("Cancel")
                }
                TextButton(onClick = onSubmit, enabled = canSubmit) {
                    Text(if (submitting) "Saving…" else "Save")
                }
            }
        }
    }
}

private val timeFormatter = DateTimeFormatter.ofPattern("h:mm a").withZone(ZoneId.systemDefault())

private fun formatTime(iso: String?): String? =
    iso?.let { runCatching { timeFormatter.format(java.time.Instant.parse(it)) }.getOrNull() }

private fun String.isImageUrl(): Boolean {
    val lower = substringBefore('?').lowercase()
    return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") ||
        lower.endsWith(".webp") || lower.endsWith(".gif") || lower.endsWith(".heic")
}
