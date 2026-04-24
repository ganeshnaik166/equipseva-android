package com.equipseva.app.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.chat.ChatMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EquipmentArt
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.TypingIndicator
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import java.time.Instant
import java.time.LocalDate
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

    // Visual polish: typing indicator stub. ViewModel does not currently expose typing state.
    val isTyping = false

    Scaffold(
        containerColor = Surface50,
        topBar = {
            ChatTopBar(title = state.title, onBack = onBack)
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            ChatInputBar(
                draft = state.draft,
                canSend = state.canSend,
                onDraftChange = viewModel::onDraftChange,
                onSend = viewModel::onSend,
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
                    val grouped = remember(state.messages) { groupByDay(state.messages) }
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            horizontal = 14.dp,
                            vertical = Spacing.md,
                        ),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        grouped.forEach { (label, msgs) ->
                            item(key = "header_$label") {
                                DayHeader(label = label)
                            }
                            items(items = msgs, key = { it.id }) { msg ->
                                MessageRow(
                                    message = msg,
                                    isSelf = msg.senderUserId == state.selfUserId,
                                )
                            }
                        }
                        if (isTyping) {
                            item(key = "typing") {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(top = Spacing.sm),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    TypingIndicator()
                                    Text(
                                        text = "typing…",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = Ink500,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayHeader(label: String) {
    Text(
        text = label.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = Ink500,
        fontWeight = FontWeight.SemiBold,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = Spacing.sm),
    )
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
private fun ChatTopBar(title: String, onBack: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 0.dp,
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.sm, vertical = Spacing.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = Ink900,
                    )
                }
                InitialsAvatar(name = title, size = 32.dp)
                Column(modifier = Modifier.weight(1f)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(
                            text = title,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Ink900,
                            maxLines = 1,
                        )
                        Icon(
                            imageVector = Icons.Default.Verified,
                            contentDescription = "Verified",
                            tint = BrandGreen,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                    Text(
                        text = "Online",
                        style = MaterialTheme.typography.labelSmall,
                        color = Success,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                IconButton(onClick = { /* call hook (visual polish only) */ }) {
                    Icon(
                        imageVector = Icons.Default.Call,
                        contentDescription = "Call",
                        tint = Ink700,
                    )
                }
                IconButton(onClick = { /* more hook (visual polish only) */ }) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "More",
                        tint = Ink700,
                    )
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
private fun InitialsAvatar(name: String, size: Dp) {
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
            fontSize = (size.value * 0.36f).sp,
            fontWeight = FontWeight.Bold,
            color = BrandGreen,
        )
    }
}

@Composable
private fun MessageRow(message: ChatMessage, isSelf: Boolean) {
    val bubbleColor = if (isSelf) BrandGreen else BrandGreen50
    val textColor = if (isSelf) Color.White else Ink900
    val shape = if (isSelf) {
        RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 16.dp, bottomEnd = 4.dp)
    } else {
        RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = 4.dp, bottomEnd = 16.dp)
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isSelf) Arrangement.End else Arrangement.Start,
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(shape)
                .background(bubbleColor)
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Column {
                val images = message.attachments.filter { it.isImageUrl() }
                if (images.isNotEmpty()) {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.padding(bottom = if (message.message.isNotBlank()) 6.dp else 0.dp),
                    ) {
                        images.forEach { url ->
                            Box(
                                modifier = Modifier
                                    .size(200.dp)
                                    .clip(RoundedCornerShape(12.dp)),
                                contentAlignment = Alignment.Center,
                            ) {
                                // Placeholder gradient art behind the actual image (matches design tile).
                                GradientTile(
                                    art = EquipmentArt.Image,
                                    hue = 160,
                                    size = 200.dp,
                                )
                                AsyncImage(
                                    model = url,
                                    contentDescription = null,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .size(200.dp)
                                        .clip(RoundedCornerShape(12.dp)),
                                )
                            }
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
                val timeLabel = formatTime(message.createdAtIso)
                if (!timeLabel.isNullOrBlank()) {
                    Text(
                        text = timeLabel,
                        fontSize = 10.sp,
                        color = if (isSelf) Color.White.copy(alpha = 0.8f) else Ink500,
                        modifier = Modifier
                            .align(Alignment.End)
                            .padding(top = 2.dp),
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
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                // Leading attachment / add button — circular surface.
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(Surface50),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Attach",
                        tint = Ink700,
                    )
                }
                // Rounded input pill (24dp), multi-line capable.
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(24.dp))
                        .border(1.dp, Surface200, RoundedCornerShape(24.dp))
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(horizontal = 14.dp, vertical = 10.dp),
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
                            lineHeight = 20.sp,
                        ),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                        keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
                        cursorBrush = SolidColor(BrandGreen),
                        maxLines = 5,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                // Circular send button (48dp brand-600 with white arrow).
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(if (canSend) BrandGreen else Surface100),
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

private val timeFormatter = DateTimeFormatter.ofPattern("h:mm a").withZone(ZoneId.systemDefault())

private fun formatTime(iso: String?): String? =
    iso?.let { runCatching { timeFormatter.format(Instant.parse(it)) }.getOrNull() }

private fun String.isImageUrl(): Boolean {
    val lower = substringBefore('?').lowercase()
    return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png") ||
        lower.endsWith(".webp") || lower.endsWith(".gif") || lower.endsWith(".heic")
}

// Group messages by day label ("Today", "Yesterday", or "MMM d") preserving insertion order.
private fun groupByDay(messages: List<ChatMessage>): List<Pair<String, List<ChatMessage>>> {
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val yesterday = today.minusDays(1)
    val dayFormatter = DateTimeFormatter.ofPattern("MMM d")
    val out = linkedMapOf<String, MutableList<ChatMessage>>()
    messages.forEach { msg ->
        val instant = msg.createdAtInstant
        val label = if (instant != null) {
            val d = instant.atZone(zone).toLocalDate()
            when (d) {
                today -> "Today"
                yesterday -> "Yesterday"
                else -> d.format(dayFormatter)
            }
        } else "Today"
        out.getOrPut(label) { mutableListOf() }.add(msg)
    }
    return out.map { (k, v) -> k to v.toList() }
}
