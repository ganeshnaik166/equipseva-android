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
import androidx.compose.foundation.layout.imePadding
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
import com.equipseva.app.core.util.initialsOf
import com.equipseva.app.designsystem.components.Avatar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
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
    // rememberSaveable so the scroll position survives the keyboard
    // popping up / config changes — plain rememberLazyListState reset
    // to index 0 on every IME open, scrolling the user back to the top
    // of the conversation every time they typed.
    val listState = androidx.compose.runtime.saveable.rememberSaveable(
        saver = androidx.compose.foundation.lazy.LazyListState.Saver,
    ) { androidx.compose.foundation.lazy.LazyListState() }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is ChatViewModel.Effect.ShowMessage -> snackbarHostState.showSnackbar(effect.text)
            }
        }
    }

    LaunchedEffect(state.messages.size) {
        if (state.messages.isEmpty()) return@LaunchedEffect
        // Only auto-scroll to the newest message when the user is already
        // parked near the bottom — otherwise a new inbound message would
        // yank them away from the history they're reading. The threshold
        // is generous enough to cover small layout shifts during typing.
        val info = listState.layoutInfo
        val lastVisible = info.visibleItemsInfo.lastOrNull()?.index ?: -1
        val total = info.totalItemsCount
        val nearBottom = total == 0 || lastVisible >= total - 3
        if (nearBottom) {
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
            // Round 454 — imePadding lifts the input bar above the
            // software keyboard. Without it, edge-to-edge windows let
            // the IME overlap the BasicTextField; the user types blind
            // until they manually dismiss the keyboard.
            Column(modifier = Modifier.imePadding()) {
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
                JobContextStrip(
                    jobId = jobId,
                    jobNumber = state.relatedJobNumber,
                    onClick = { onOpenJob(jobId) },
                )
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
                else -> {
                    // Day-separator grouping is O(messages) — without remember
                    // it would re-run every parent recomposition (typing,
                    // realtime tick, scroll). Keyed on the message list ref
                    // so groupBy only re-fires when messages actually change.
                    val grouped = remember(state.messages) {
                        state.messages.groupBy { dayKey(it.createdAtIso) }
                    }
                    // Cache the human-readable label per day-key too —
                    // dayLabel() parses an ISO date each call, and the
                    // forEach below otherwise re-runs the parse on
                    // every parent recomposition (typing, scroll).
                    val dayLabels = remember(grouped) {
                        grouped.keys.associateWith { dayLabel(it) }
                    }
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 14.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        grouped.forEach { (key, msgs) ->
                            item(key = "sep-$key") {
                                DaySeparator(label = dayLabels[key] ?: key)
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
            text = queuedChatMessagePillText(count),
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
                )
                Text(
                    text = title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                    maxLines = 1,
                )
            }
            // Phone CTA removed for v2.1 — the previous green icon
            // looked tappable but was wired to a `/* placeholder */`
            // no-op. The masked-call surface lives on the engineer
            // profile + repair-job sheet (MaskedContactPanel), gated
            // on an active job. Re-add here only when chat-header
            // calling is actually wired.
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
                    // formatTime parses an ISO instant + applies a
                    // DateTimeFormatter; memoize on the source so a
                    // recomposition (selection toggle, blocked-flag
                    // tick, scroll measure) doesn't re-parse.
                    val timeLabel = remember(message.createdAtIso) { formatTime(message.createdAtIso) }
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
                // 40dp circle send button — green-700 when active, paper-2
                // disabled. Round 458: wrapped in a 48 dp click target so
                // the a11y hit area meets Material spec; the visible 40 dp
                // circle is preserved.
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clickable(enabled = canSend, onClick = onSend),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(if (canSend) SevaGreen700 else Paper2),
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

// Pin Locale.ENGLISH so "h:mm a" stays "2:30 PM" (not Devanagari AM/PM)
// and "dd MMM" stays "11 May" regardless of the device locale.
// Pin Asia/Kolkata zone too — EquipSeva is India-only (PRD locked), and
// systemDefault() reads from the device, so an Indian user travelling
// abroad would see times in the destination timezone. Mirrors the
// NotificationsScreen IST override added in round 234.
private val IST_ZONE: ZoneId = ZoneId.of("Asia/Kolkata")
private val timeFormatter = DateTimeFormatter.ofPattern("h:mm a", java.util.Locale.ENGLISH)
    .withZone(IST_ZONE)
private val dayHeaderFormatter = DateTimeFormatter.ofPattern("dd MMM", java.util.Locale.ENGLISH)
    .withZone(IST_ZONE)

internal fun formatTime(iso: String?): String? =
    iso?.let { runCatching { timeFormatter.format(Instant.parse(it)) }.getOrNull() }

// Group key by local date so the day-separator only appears at boundaries.
// Falls back to "unknown" when a timestamp is unparseable; DaySeparator
// short-circuits on a blank label so unparseable buckets render no header.
internal fun dayKey(iso: String?): String =
    iso?.let {
        runCatching { Instant.parse(it).atZone(IST_ZONE).toLocalDate().toString() }
            .getOrNull()
    } ?: "unknown"

private fun dayLabel(key: String): String = dayLabelAt(key, LocalDate.now(IST_ZONE))

/** Pure variant of [dayLabel] used by tests. */
internal fun dayLabelAt(key: String, today: LocalDate): String {
    if (key == "unknown") return ""
    val date = runCatching { LocalDate.parse(key) }.getOrNull() ?: return ""
    return when (date) {
        today -> "Today"
        today.minusDays(1) -> "Yesterday"
        else -> dayHeaderFormatter.format(date.atStartOfDay(IST_ZONE).toInstant())
    }
}

private fun String.isImageUrl(): Boolean = isImageUrlExtension(this)

/**
 * True when [url]'s path (anything before the query string) ends in
 * one of the six image extensions the chat composer accepts. Used by
 * the attachment renderer to decide between AsyncImage vs the generic
 * file-pill. Extracted top-level so the case-folding + query-strip
 * logic can be unit-tested without the surrounding row composable.
 */
internal fun isImageUrlExtension(url: String): Boolean {
    val lower = url.substringBefore('?').lowercase()
    return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") ||
        lower.endsWith(".webp") || lower.endsWith(".gif") || lower.endsWith(".heic")
}

/**
 * Banner text on the queued-chat-message pill (offline send queue).
 *
 * Critical region: singular/plural split AND the U+2014 em-dash
 * separator. Sibling of [com.equipseva.app.features.mybids.queuedBidPillText]
 * but with chat-specific vocabulary ("message" / "send" instead of
 * "bid" / "submit"). Pin the cross-surface vocabulary asymmetry —
 * a refactor that unified them via a parametric helper would risk
 * mixing "bid send" / "message submit" prose on either surface.
 *
 *   - count == 1 → "1 message queued — will send when back online"
 *   - count != 1 → "N messages queued — will send when back online"
 */
internal fun queuedChatMessagePillText(count: Int): String =
    if (count == 1) {
        "1 message queued — will send when back online"
    } else {
        "$count messages queued — will send when back online"
    }

/**
 * Label on the job-context strip above the chat thread.
 *
 *   - jobNumber non-blank → use as-is (e.g. "RPR-2026-00041")
 *   - jobNumber null/blank → "RJ-${jobId.take(8)}" fallback
 *
 * Pin the "RJ-" prefix (NOT "RPR-") on the fallback — distinguishes
 * the chat-context-only label from the canonical jobNumber form so
 * users / founders inspecting screenshots can tell whether they're
 * looking at the real number or the in-flight chat fallback.
 *
 * Pin take(8) — the 8-char prefix matches the founder's other
 * id-prefix conventions (userDisplayName, contract slugs, etc.) so
 * cross-referencing in Supabase Studio stays consistent.
 */
internal fun jobContextStripLabel(jobNumber: String?, jobId: String): String =
    jobNumber?.takeIf { it.isNotBlank() } ?: "RJ-${jobId.take(8)}"

@Composable
private fun JobContextStrip(jobId: String, jobNumber: String?, onClick: () -> Unit) {
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
            // Real job_number when resolved; truncated UUID otherwise so the
            // strip is never blank during the fetch window.
            val label = jobContextStripLabel(jobNumber, jobId)
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = label,
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
