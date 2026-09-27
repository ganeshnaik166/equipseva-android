package com.equipseva.app.navigation

import android.app.Application
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.equipseva.app.features.auth.SessionOwner
import com.equipseva.app.features.auth.SessionPresentation
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Composed production boundary with inert content; no account or network is used. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [34])
class RootSessionBoundaryTest {
    @get:Rule val compose = createComposeRule()
    private var presentation by mutableStateOf(ready("A", 1))
    private var mounts = 0
    private var disposals = 0

    private fun render() {
        compose.setContent {
            MaterialTheme {
                RootSessionBoundary(presentation, mountedOnce = true) {
                    DisposableEffect(Unit) {
                        mounts++
                        onDispose { disposals++ }
                    }
                    Text("Private ${presentation.owner?.userId ?: "auth"}")
                }
            }
        }
        compose.waitForIdle()
    }

    private fun update(next: SessionPresentation) {
        compose.runOnIdle { presentation = next }
        compose.waitForIdle()
    }

    @Test fun `A to B obscures and disposes old host before B validates`() {
        render()
        compose.onNodeWithText("Private A").assertIsDisplayed()
        assertEquals(1, mounts)

        update(pending("B", 2))
        compose.onNodeWithText("Private A").assertDoesNotExist()
        assertEquals(1, disposals)
        assertEquals(1, mounts)

        update(ready("B", 2))
        compose.onNodeWithText("Private B").assertIsDisplayed()
        assertEquals(2, mounts)
    }

    @Test fun `A out A resets prior host even when the user ID is the same`() {
        render()
        update(SessionPresentation(SessionState.SignedOut, resolvingAuth = false))
        compose.onNodeWithText("Private auth").assertIsDisplayed()
        assertEquals(1, disposals)

        update(pending("A", 2))
        compose.onNodeWithText("Private auth").assertDoesNotExist()
        assertEquals(1, disposals) // Fresh auth host is retained under the cover.
        update(ready("A", 2))
        compose.onNodeWithText("Private A").assertIsDisplayed()
        assertEquals(2, mounts)
    }

    @Test fun `same login Unknown hides semantics without destroying form host`() {
        render()
        update(SessionPresentation(
            state = SessionState.Loading,
            owner = SessionOwner("A", 1),
            validatedRole = UserRole.HOSPITAL,
            profileValidated = true,
            resolvingAuth = true,
        ))
        compose.onNodeWithText("Private A").assertDoesNotExist()
        assertEquals(0, disposals)

        update(ready("A", 1))
        compose.onNodeWithText("Private A").assertIsDisplayed()
        assertEquals(1, mounts)
    }

    @Test fun `Unknown cover blocks touches on the retained private host`() {
        var taps = 0
        compose.setContent {
            MaterialTheme {
                RootSessionBoundary(presentation, mountedOnce = true) {
                    Box(Modifier.fillMaxSize().clickable { taps++ }) { Text("Private action") }
                }
            }
        }
        compose.waitForIdle()
        update(SessionPresentation(
            state = SessionState.Loading,
            owner = SessionOwner("A", 1),
            validatedRole = UserRole.HOSPITAL,
            profileValidated = true,
            resolvingAuth = true,
        ))
        compose.onRoot().performTouchInput { click(center) }
        assertEquals(0, taps)
        update(ready("A", 1))
        compose.onRoot().performTouchInput { click(center) }
        assertEquals(1, taps)
    }

    @Test fun `failed verification offers retry without revealing private content`() {
        var retries = 0
        compose.setContent {
            MaterialTheme {
                RootSessionBoundary(
                    presentation = presentation,
                    mountedOnce = true,
                    onRetry = { retries++ },
                ) { Text("Private account") }
            }
        }
        update(ready("A", 1).copy(resolvingAuth = true, verificationFailed = true))
        compose.onNodeWithText("Private account").assertDoesNotExist()
        compose.onNodeWithText("Retry").performClick()
        assertEquals(1, retries)
    }

    @Test fun `A B A gives the last A a new host`() {
        render()
        update(pending("B", 2))
        update(pending("A", 3))
        compose.onNodeWithText("Private A").assertDoesNotExist()
        update(ready("A", 3))
        compose.onNodeWithText("Private A").assertIsDisplayed()
        assertEquals(2, mounts)
        assertEquals(1, disposals)
    }

    @Test fun `same login server role change resets saved hospital or engineer host`() {
        render()
        update(ready("A", 1, UserRole.ENGINEER))
        compose.onNodeWithText("Private A").assertIsDisplayed()
        assertEquals(2, mounts)
        assertEquals(1, disposals)
    }

    @Test fun `role removal destroys hospital host before engineer role returns`() {
        render()
        update(SessionPresentation(
            state = SessionState.NeedsRole("A", "a@test.invalid"),
            owner = SessionOwner("A", 1),
            profileValidated = true,
            resolvingAuth = false,
        ))
        assertEquals(1, disposals)
        update(ready("A", 1, UserRole.ENGINEER))
        compose.onNodeWithText("Private A").assertIsDisplayed()
        assertEquals(2, mounts)
        assertEquals(1, disposals)
    }

    @Test fun `main admission requires same validated ready owner and role`() {
        val hospital = ready("A", 1)
        assertEquals(true, mayComposeMain(hospital, hospital))
        assertEquals(false, mayComposeMain(hospital, pending("B", 2)))
        assertEquals(false, mayComposeMain(hospital, SessionPresentation(
            state = SessionState.NeedsRole("A", "a@test.invalid"),
            owner = SessionOwner("A", 1),
            profileValidated = true,
            resolvingAuth = false,
        )))
        assertEquals(false, mayComposeMain(hospital, ready("A", 1, UserRole.ENGINEER)))
        val unknown = SessionPresentation(
            state = SessionState.Loading,
            owner = SessionOwner("A", 1),
            validatedRole = UserRole.HOSPITAL,
            profileValidated = true,
            resolvingAuth = true,
        )
        assertEquals(true, mayComposeMain(unknown, unknown)) // retained only under opaque cover
    }

    @Test fun `stale auth callback cannot navigate after owner switch or pending refresh`() {
        val a = ready("A", 1)
        assertEquals(true, mayNavigateToMain(a, a))
        assertEquals(false, mayNavigateToMain(a, pending("B", 2)))
        assertEquals(false, mayNavigateToMain(a, ready("B", 2)))
        assertEquals(false, mayNavigateToMain(a, a.copy(resolvingAuth = true)))
        assertEquals(false, mayNavigateToMain(a, ready("A", 1, UserRole.ENGINEER)))
    }

    private class AccountViewModel(private val onClear: () -> Unit) : ViewModel() {
        override fun onCleared() = onClear()
    }

    @Test fun `replacement account clears nested navigation ViewModel store`() {
        var cleared = 0
        compose.setContent {
            MaterialTheme {
                RootSessionBoundary(presentation, mountedOnce = true) {
                    val nav = rememberNavController()
                    NavHost(navController = nav, startDestination = "private") {
                        composable("private") {
                            viewModel<AccountViewModel>(factory = object : ViewModelProvider.Factory {
                                @Suppress("UNCHECKED_CAST")
                                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                                    AccountViewModel { cleared++ } as T
                            })
                            Text("Private data")
                        }
                    }
                }
            }
        }
        compose.onNodeWithText("Private data").assertIsDisplayed()

        update(pending("B", 2))
        compose.onNodeWithText("Private data").assertDoesNotExist()
        assertEquals(1, cleared)
    }

    @Test fun `replacement account cannot restore the old nested detail back stack`() {
        compose.setContent {
            MaterialTheme {
                RootSessionBoundary(presentation, mountedOnce = true) {
                    val nav = rememberNavController()
                    val owner = presentation.owner?.userId ?: "none"
                    NavHost(navController = nav, startDestination = "home") {
                        composable("home") {
                            Text("Open $owner", Modifier.clickable { nav.navigate("detail") })
                        }
                        composable("detail") { Text("Detail $owner") }
                    }
                }
            }
        }
        compose.onNodeWithText("Open A").performClick()
        compose.onNodeWithText("Detail A").assertIsDisplayed()

        update(pending("B", 2))
        compose.onNodeWithText("Detail A").assertDoesNotExist()
        update(ready("B", 2))
        compose.onNodeWithText("Open B").assertIsDisplayed()
        compose.onNodeWithText("Detail A").assertDoesNotExist()
    }

    private companion object {
        fun ready(id: String, generation: Long, role: UserRole = UserRole.HOSPITAL) = SessionPresentation(
            state = SessionState.Ready(id, "$id@test.invalid", role.storageKey),
            owner = SessionOwner(id, generation),
            validatedRole = role,
            profileValidated = true,
            resolvingAuth = false,
        )
        fun pending(id: String, generation: Long) = SessionPresentation(
            state = SessionState.Loading,
            owner = SessionOwner(id, generation),
            profileValidated = false,
            resolvingAuth = false,
        )
    }
}
