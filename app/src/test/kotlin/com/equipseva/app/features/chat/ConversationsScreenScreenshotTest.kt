package com.equipseva.app.features.chat

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.equipseva.app.core.data.chat.ChatConversation
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Pins the four inbox states of [ConversationsContent] as Roborazzi
 * goldens under `screens/ConversationsScreen_<state>.png`.
 *
 * Fixture rows carry no `lastMessageAtIso` on purpose: the row renders
 * that field through `relativeLabel(now)`, so any real timestamp would
 * drift the golden every time the clock moved a bucket.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class ConversationsScreenScreenshotTest {

    @get:Rule val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/ConversationsScreen_" + name + ".png")
    }

    @Composable
    private fun Content(state: ConversationsViewModel.UiState) {
        ConversationsContent(
            state = state,
            onQueryChange = {},
            onRefresh = {},
            onBack = {},
            onConversationClick = {},
            onSignIn = {},
        )
    }

    @Test fun loading() = capture("loading") {
        Content(state = ConversationsViewModel.UiState(loading = true, rows = emptyList()))
    }

    @Test fun empty() = capture("empty") {
        Content(state = ConversationsViewModel.UiState(loading = false, rows = emptyList()))
    }

    @Test fun error() = capture("error") {
        Content(
            state = ConversationsViewModel.UiState(
                loading = false,
                rows = emptyList(),
                errorMessage = "Couldn't load conversations. Check your connection and try again.",
            ),
        )
    }

    @Test fun populated() = capture("populated") {
        Content(
            state = ConversationsViewModel.UiState(
                loading = false,
                queuedCount = 2,
                rows = listOf(
                    row(
                        id = "CONV-00041",
                        counterpart = profile(id = "USR-1001", fullName = "Satish Naidu"),
                        lastMessage = "Reached the hospital, heading to the ICU now.",
                        unreadCount = 3,
                    ),
                    row(
                        id = "CONV-00042",
                        counterpart = profile(id = "USR-1002", fullName = "Priyanka Reddy"),
                        lastMessage = "Invoice for RPR-00041 is attached. Thanks!",
                        unreadCount = 0,
                    ),
                    row(
                        id = "CONV-00043",
                        counterpart = profile(id = "USR-1003", fullName = "Apollo Biomedical Services"),
                        lastMessage = "Can you share the ventilator serial number before we quote?",
                        unreadCount = 120,
                    ),
                    row(
                        id = "CONV-00044",
                        counterpart = null,
                        lastMessage = null,
                        unreadCount = 0,
                    ),
                ),
            ),
        )
    }

    private fun row(
        id: String,
        counterpart: Profile?,
        lastMessage: String?,
        unreadCount: Int,
    ): ConversationsViewModel.Row = ConversationsViewModel.Row(
        conversation = ChatConversation(
            id = id,
            participantUserIds = listOf("USR-SELF", counterpart?.id ?: "USR-GONE"),
            relatedEntityType = "repair_job",
            relatedEntityId = "RPR-00041",
            lastMessage = lastMessage,
            lastMessageAtIso = null,
            createdAtIso = "2026-01-05T09:00:00Z",
            unreadCount = unreadCount,
        ),
        counterpart = counterpart,
    )

    private fun profile(id: String, fullName: String): Profile = Profile(
        id = id,
        email = null,
        phone = null,
        fullName = fullName,
        avatarUrl = null,
        role = null,
        rawRoleKey = null,
        roleConfirmed = true,
        onboardingCompleted = true,
        isActive = true,
        organizationId = null,
        organizationName = null,
        organizationCity = null,
        organizationState = null,
    )
}
