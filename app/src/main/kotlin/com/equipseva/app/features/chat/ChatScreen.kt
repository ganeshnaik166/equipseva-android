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
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.Phone
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.SolidColor
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
import com.equipseva.app.designsystem.components.Avatar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.OnlineStatus
import com.equipseva.app.designsystem.components.ReportContentSheet
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen100
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// ChatScreen — re-skinned to match newdesign/screens-comm.jsx:ChatThread
// (lines 40-119). Custom 52dp top bar with avatar+name+online+phone CTA,
// green-50 job-context strip, green-700 / white message bubbles with
// asymmetric corners, and a paper-2 pill input + 40dp circle send button.
// All ChatViewModel hooks (send / edit / report / delete / typing / queued /
// real-time subscriptions) are preserved unchanged.
@Composable
fun ChatScreen(
    onBack: () -> Unit,
    onOpenJob: (jobId: String) -> Unit = {},
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
        containerColor = PaperDefault,
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
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            state.relatedJobId?.let { jobId ->
                JobContextStrip(jobId = jobId, onClick = { onOpenJob(jobId) })
            }
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
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    // Day-separator + messages, grouped by local-date so each day
                    // boundary gets its own "Today / Yesterday / dd MMM" header.
                    val grouped = state.messages.groupBy { dayKey(it.createdAtIso) }
                    grouped.forEach { (key, msgs) ->
                        item(key = "sep-$key") {
                            DaySeparator(label = dayLabel(key))
                        }
                        items(items = msgs, key = { it.id }) { msg ->
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
private fun DaySeparator(label: String) {
    if (label.isBlank()) return
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 11.sp,
            color = SevaInk400,
        )
    }
}

@Composable
private fun TypingIndicatorRow(visible: Boolean) {
    if (!visible) return
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
            .padding(horizontal = 16.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        repeat(3) { i ->
            Box(
                modifier = Modifier
                    .size(5.dp)
                    .clip(CircleShape)
                    .background(if (i == phase.intValue) SevaGreen700 else BorderDefault),
            )
        }
        Text(
            text = "typing…",
            fontSize = 12.sp,
            color = SevaInk500,
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
            fontSize = 12.sp,
            color = SevaInk900,
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
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .background(PaperDefault)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Left slot: back arrow + avatar + name+online — single tappable group,
            // matches the JSX `<button>` wrapper that triggers go(-1).
            Row(
                modifier = Modifier
                    .weight(1f)
                    .clickable(onClick = onBack)
                    .padding(horizontal = 6.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Outlined.ArrowBack,
                    contentDescription = "Back",
                    tint = SevaInk900,
                    modifier = Modifier.size(20.dp),
                )
                Avatar(
                    initials = initialsOf(title),
                    size = 32.dp,
                    online = OnlineStatus.Available,
                )
                Column {
                    Text(
                        text = title,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaInk900,
                        maxLines = 1,
                    )
                    Text(
                        text = "● Online",
                        fontSize = 10.sp,
                        color = SevaGreen700,
                        maxLines = 1,
                    )
                }
            }
            // Phone CTA — wired when telephony lands.
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .clickable { /* call CTA — placeholder */ },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Phone,
                    contentDescription = "Call",
                    tint = SevaGreen700,
                    modifier = Modifier.size(18.dp),
                )
            }
            if (canBlock) {
                Box {
                    IconButton(onClick = { menuOpen = true }) {
                        Icon(Icons.Filled.MoreVert, contentDescription = "More", tint = SevaInk900)
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
                .background(BorderDefault),
        )
    }
}

private fun initialsOf(name: String): String =
    name.split(" ", limit = 2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }
        .joinToString("")
        .take(2)
        .ifBlank { "?" }

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
    // Deleted bubbles fall back to a muted surface so the tombstone reads as
    // disabled, regardless of sender.
    val bubbleColor = when {
        isDeleted -> Paper2
        isSelf -> SevaGreen700
        else -> Color.White
    }
    val textColor = when {
        isDeleted -> SevaInk500
        isSelf -> Color.White
        else -> SevaInk900
    }
    // 14dp / 4dp asymmetric corners — bottom-end on me-bubble, bottom-start on them-bubble.
    val shape = if (isSelf) {
        RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp, bottomStart = 14.dp, bottomEnd = 4.dp)
    } else {
        RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp, bottomStart = 4.dp, bottomEnd = 14.dp)
    }

    var menuOpen by remember { mutableStateOf(false) }

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
                        if (!isSelf || isDeleted) Modifier.border(1.dp, BorderDefault, shape) else Modifier,
                    )
                    .combinedClickable(
                        onClick = {},
                        onLongClick = onLongClick,
                    )
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                Column {
                    if (isDeleted) {
                        Text(
                            text = "Message deleted",
                            fontSize = 13.sp,
                            lineHeight = (13 * 1.4f).sp,
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
                                fontSize = 13.sp,
                                lineHeight = (13 * 1.4f).sp,
                                color = textColor,
                            )
                        }
                    }
                    val timeLabel = formatTime(message.createdAtIso)
                    if (!timeLabel.isNullOrBlank()) {
                        // 0.7 alpha on me-bubble per JSX; muted ink on them-bubble.
                        val metaColor = when {
                            isDeleted -> SevaInk500
                            isSelf -> Color.White.copy(alpha = 0.7f)
                            else -> SevaInk500.copy(alpha = 0.7f)
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
                                    text = "edited",
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
                            if (isSelf && !isDeleted) {
                                // JSX shows a lime check when m.read, currentColor otherwise.
                                // ChatMessage has no per-message read flag yet, so we always
                                // render the muted "sent" tint; flip to SevaGlowRaw once a
                                // read flag lands on ChatMessage.
                                Icon(
                                    imageVector = Icons.Outlined.Check,
                                    contentDescription = null,
                                    tint = metaColor,
                                    modifier = Modifier.size(12.dp),
                                )
                            }
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
        color = Color.White,
        tonalElevation = 0.dp,
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(BorderDefault),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 12.dp),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(22.dp))
                        .background(Paper2)
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (draft.isEmpty()) {
                        Text(
                            text = "Message…",
                            fontSize = 14.sp,
                            color = SevaInk500,
                        )
                    }
                    BasicTextField(
                        value = draft,
                        onValueChange = onDraftChange,
                        textStyle = TextStyle(
                            fontSize = 14.sp,
                            color = SevaInk900,
                        ),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
                        cursorBrush = SolidColor(SevaGreen700),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                // 40dp circle send button — green-700 when active, paper-2 disabled.
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(if (canSend) SevaGreen700 else Paper2)
                        .clickable(enabled = canSend, onClick = onSend),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Outlined.ArrowForward,
                        contentDescription = "Send",
                        tint = if (canSend) Color.White else SevaInk400,
                        modifier = Modifier.size(18.dp),
                    )
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
        color = SevaGreen50,
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
                color = SevaGreen700,
            )
            OutlinedTextField(
                value = draft,
                onValueChange = onDraftChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = false,
                maxLines = 4,
                enabled = !submitting,
                textStyle = TextStyle(fontSize = 14.sp, color = SevaInk900),
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
private val dayHeaderFormatter = DateTimeFormatter.ofPattern("dd MMM").withZone(ZoneId.systemDefault())

private fun formatTime(iso: String?): String? =
    iso?.let { runCatching { timeFormatter.format(Instant.parse(it)) }.getOrNull() }

// Group key by local date so the day-separator only appears at boundaries.
// Falls back to "unknown" when a timestamp is unparseable; DaySeparator
// short-circuits on a blank label so unparseable buckets render no header.
private fun dayKey(iso: String?): String =
    iso?.let {
        runCatching { Instant.parse(it).atZone(ZoneId.systemDefault()).toLocalDate().toString() }
            .getOrNull()
    } ?: "unknown"

private fun dayLabel(key: String): String {
    if (key == "unknown") return ""
    val date = runCatching { LocalDate.parse(key) }.getOrNull() ?: return ""
    val today = LocalDate.now()
    return when (date) {
        today -> "Today"
        today.minusDays(1) -> "Yesterday"
        else -> dayHeaderFormatter.format(date.atStartOfDay(ZoneId.systemDefault()).toInstant())
    }
}

private fun String.isImageUrl(): Boolean {
    val lower = substringBefore('?').lowercase()
    return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") ||
        lower.endsWith(".webp") || lower.endsWith(".gif") || lower.endsWith(".heic")
}

@Composable
private fun JobContextStrip(jobId: String, onClick: () -> Unit) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(SevaGreen50)
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = Icons.Outlined.Build,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(14.dp),
            )
            // Job code rendered bold + " · " separator + equipment / fallback.
            // When ChatViewModel.UiState exposes related equipment flip the
            // suffix to that label.
            val short = jobId.take(8)
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "RJ-$short",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaGreen900,
                )
                Text(
                    text = " · Repair job",
                    fontSize = 12.sp,
                    color = SevaGreen900,
                )
            }
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(14.dp),
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(SevaGreen100),
        )
    }
}
