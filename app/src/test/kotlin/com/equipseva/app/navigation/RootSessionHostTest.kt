package com.equipseva.app.navigation

import android.app.Application
import android.content.pm.PackageManager
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navigation
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.features.auth.SessionOwner
import com.equipseva.app.features.auth.SessionPresentation
import com.equipseva.app.features.auth.SessionState
import com.equipseva.app.features.auth.SessionViewModel
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.SignOutCleanup
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.testing.AuthAuditFixtures
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.RecordingUserPrefs
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config

/**
 * Actual production root NavHost with inert screens. The isolated test host
 * avoids Hilt, production providers and real repositories. These are simulator
 * routing/lifetime assertions, not a device, TalkBack or full-workflow score.
 */
@RunWith(IsolatedUiTestRunner::class)
@OptIn(androidx.compose.ui.test.ExperimentalTestApi::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w360dp-h800dp-mdpi")
class RootSessionHostTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var controller: ActivityController<ComponentActivity>
    private val presentation = mutableStateOf(SessionPresentation())
    private var currentPresentation: () -> SessionPresentation = { presentation.value }
    private val ownedViewModels = mutableListOf<SessionViewModel>()
    private val trace = Trace()
    private var refreshCalls = 0
    private var signOutCalls = 0

    @Before fun startEmptyHost() {
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        controller = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }

    @After fun closeEmptyHost() {
        ownedViewModels.forEach { it.viewModelScope.cancel() }
        if (::controller.isInitialized) controller.pause().stop().destroy()
    }

    private data class Render(val slot: String, val entryOwner: String?, val expectedOwner: SessionOwner?, val gateState: SessionState)
    private class Trace {
        val mounts = mutableListOf<Pair<String, String>>()
        val disposals = mutableListOf<Pair<String, String>>()
        val frames = mutableListOf<Render>()
        val callbacks = mutableMapOf<String, MutableList<() -> Unit>>()
        val created = mutableListOf<Int>()
        val cleared = mutableListOf<Int>()
        var draftFocused = false
        var draftChanges = 0
        fun record(name: String, callback: () -> Unit) {
            callbacks.getOrPut(name) { mutableListOf() } += callback
        }
        fun last(name: String): () -> Unit = callbacks.getValue(name).last()
    }

    class SentinelViewModel(val number: Int, private val onClear: (Int) -> Unit) : ViewModel() {
        override fun onCleared() { onClear(number) }
    }

    class SignupEntryViewModel(private val onClear: () -> Unit) : ViewModel() {
        override fun onCleared() { onClear() }
    }

    @Composable private fun Slot(name: String, content: @Composable () -> Unit) {
        val entry = checkNotNull(LocalViewModelStoreOwner.current) as NavBackStackEntry
        val current = currentPresentation()
        DisposableEffect(entry.id, name) {
            trace.mounts += name to entry.id
            onDispose { trace.disposals += name to entry.id }
        }
        SideEffect {
            trace.frames += Render(name, entry.arguments?.getString("owner"), current.owner, current.state)
        }
        Column(Modifier.fillMaxSize().testTag("slot-$name")) { content() }
    }

    @Composable private fun Action(name: String, action: () -> Unit) {
        SideEffect { trace.record(name, action) }
        Button(onClick = action, modifier = Modifier.testTag(name)) { Text(name) }
    }

    private fun slots() = RootSessionSlots(
        auth = { saved -> Slot("auth") { Action("auth-saved", saved) } },
        role = { saved, signOut -> Slot("role") {
            Action("role-saved", saved); Action("role-sign-out", signOut)
        } },
        onboarding = { role, baseDone, saved -> Slot("onboarding") {
            Text("${role.storageKey}:$baseDone", Modifier.testTag("onboarding-kind"))
            Action("onboarding-saved", saved)
        } },
        main = { role, saved -> Slot("main") {
            val sentinel = viewModel<SentinelViewModel>(factory = object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    val number = trace.created.size + 1
                    trace.created += number
                    return SentinelViewModel(number) { trace.cleared += it } as T
                }
            })
            Text("${role.storageKey}:${sentinel.number}", Modifier.testTag("main-kind"))
            Action("main-saved", saved)
            val nested = rememberNavController()
            NavHost(nested, "fixture-home", modifier = Modifier.fillMaxSize()) {
                composable("fixture-home") {
                    Button(onClick = { nested.navigate("fixture-detail") }, modifier = Modifier.testTag("open-detail")) {
                        Text("Open inert detail")
                    }
                }
                composable("fixture-detail") {
                    var draft by rememberSaveable { mutableStateOf("") }
                    Column {
                        Text("Inert detail", Modifier.testTag("detail"))
                        BasicTextField(draft, onValueChange = {
                            trace.draftChanges++
                            draft = it
                        }, modifier = Modifier.testTag("draft").onFocusChanged { trace.draftFocused = it.isFocused })
                    }
                }
            }
        } },
        pending = { retry, signOut -> Slot("pending") {
            Action("pending-retry", retry); Action("pending-sign-out", signOut)
        } },
        resolving = { Text("Resolving auth", Modifier.testTag("resolving")) },
    )

    private fun render(initial: SessionPresentation) {
        presentation.value = initial
        controller.get().setContent {
            MaterialTheme {
                RootSessionHost(presentation.value, { refreshCalls++ }, { signOutCalls++ }, slots())
            }
        }
        compose.waitForIdle()
    }

    private fun update(value: SessionPresentation) {
        compose.runOnIdle { presentation.value = value }
        compose.waitForIdle()
    }

    private fun back() {
        compose.runOnIdle { controller.get().onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
    }

    private fun assertOnly(slot: String) {
        compose.onNodeWithTag("slot-$slot").assertIsDisplayed()
        listOf("auth", "role", "onboarding", "main", "pending").filter { it != slot }.forEach {
            compose.onNodeWithTag("slot-$it").assertDoesNotExist()
        }
    }

    private fun assertNoWrongOwnerFrame() {
        trace.frames.filter { it.slot != "auth" && it.slot != "pending" }.forEach {
            val expected = checkNotNull(it.expectedOwner)
            assertEquals("wrong-owner composition: $it", "${expected.userId}:${expected.generation}", it.entryOwner)
            if (it.gateState is SessionState.NeedsRole) assertEquals("role", it.slot)
        }
    }

    private fun openDraft(value: String) {
        compose.onNodeWithTag("open-detail").performClick()
        compose.onNodeWithTag("detail").assertIsDisplayed()
        compose.onNodeWithTag("draft").performClick()
        if (value.isNotEmpty()) compose.onNodeWithTag("draft").performTextInput(value)
    }

    @Test fun `isolated harness has plain application and no declared providers`() {
        val context = ApplicationProvider.getApplicationContext<Application>()
        assertEquals(Application::class.java, context.javaClass)
        @Suppress("DEPRECATION")
        val providers = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PROVIDERS).providers
        assertTrue(providers.isNullOrEmpty())
        render(SessionPresentation(SessionState.SignedOut))
        assertOnly("auth")
    }

    @Test fun `cold needs role never composes main or onboarding`() {
        render(needsRole())
        assertOnly("role")
        assertEquals(listOf("role"), trace.mounts.map { it.first })
        assertTrue(trace.created.isEmpty())
    }

    @Test fun `pending then role has no intermediate main admission`() {
        render(SessionPresentation(owner = owner()))
        assertOnly("pending")
        update(needsRole())
        assertOnly("role")
        assertTrue(trace.mounts.none { it.first == "main" || it.first == "onboarding" })
    }

    @Test fun `live role gate removes main and callback cannot bypass authoritative state`() {
        render(ready())
        update(needsRole())
        assertOnly("role")
        compose.onNodeWithTag("role-saved").performClick()
        assertEquals(1, refreshCalls)
        assertOnly("role")
        back()
        assertOnly("role")
        update(ready())
        assertOnly("main")
        assertNoWrongOwnerFrame()
    }

    @Test fun `supported onboarding stages require authoritative ready before main`() {
        render(onboarding("hospital_admin", false))
        compose.onNodeWithTag("onboarding-kind").assertTextEquals("hospital_admin:false")
        update(onboarding("engineer", false))
        compose.onNodeWithTag("onboarding-kind").assertTextEquals("engineer:false")
        update(onboarding("engineer", true))
        compose.onNodeWithTag("onboarding-kind").assertTextEquals("engineer:true")
        compose.onNodeWithTag("onboarding-saved").performClick()
        assertEquals(1, refreshCalls)
        assertOnly("onboarding")
        update(ready(role = "engineer"))
        assertOnly("main")
        back()
        assertOnly("main")
    }

    @Test fun `unknown admin and deferred roles always render role choice`() {
        render(ready(role = "admin"))
        listOf("", " ", "unknown", "admin", "supplier", "manufacturer", "logistics").forEach { role ->
            update(ready(role = role)); assertOnly("role")
            update(onboarding(role, false)); assertOnly("role")
        }
        assertTrue(trace.mounts.all { it.first == "role" })
        assertTrue(trace.created.isEmpty())
    }

    @Test fun `direct account replacement clears entry VM and nested draft`() {
        render(ready())
        openDraft("A private draft")
        val first = trace.created.single()
        update(ready(userId = "B", generation = 2))
        assertOnly("main")
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
        compose.onNodeWithTag("detail").assertDoesNotExist()
        assertEquals(listOf(first), trace.cleared)
        assertEquals(2, trace.created.size)
        openDraft("")
        compose.onNodeWithTag("draft").assertTextEquals("")
        assertNoWrongOwnerFrame()
    }

    @Test fun `replacement through pending disposes old main before new profile resolves`() {
        render(ready())
        openDraft("A draft")
        update(SessionPresentation(owner = owner("B", 2), profileLoading = true))
        assertOnly("pending")
        assertEquals(listOf(1), trace.cleared)
        back()
        assertOnly("pending")
        assertEquals("Back cannot remount A while B's profile is pending", listOf(1), trace.created)
        assertEquals(listOf(1), trace.cleared)
        update(SessionPresentation(owner = owner("B", 2), profileFailed = true))
        assertOnly("pending")
        assertEquals(listOf(1), trace.created)
        update(ready("B", 2))
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
        assertEquals(listOf(1, 2), trace.created)
        assertNoWrongOwnerFrame()
    }

    @Test fun `same id new generation resets even when Compose never renders signed out`() {
        render(ready())
        openDraft("first login")
        update(ready(generation = 3))
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
        assertEquals(listOf(1), trace.cleared)
        assertEquals(listOf(1, 2), trace.created)
        assertNoWrongOwnerFrame()
    }

    @Test fun `sign out and same id relogin cannot recover retired back stack`() {
        render(ready())
        openDraft("old account")
        update(SessionPresentation(SessionState.SignedOut))
        assertOnly("auth")
        assertEquals(listOf(1), trace.cleared)
        update(ready(generation = 2))
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
        back()
        assertOnly("main")
        compose.onNodeWithTag("detail").assertDoesNotExist()
        assertEquals(listOf(1, 2), trace.created)
    }

    @Test fun `direct A B A creates three independent entry stores`() {
        render(ready())
        openDraft("first A")
        update(ready("B", 2))
        openDraft("B")
        update(ready("A", 3))
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
        assertEquals(listOf(1, 2), trace.cleared)
        assertEquals(listOf(1, 2, 3), trace.created)
        assertNoWrongOwnerFrame()
    }

    @Test fun `transient unknown hides actions clears focus and preserves nav and draft through Back`() {
        val validated = ready()
        render(validated)
        openDraft("retained draft")
        assertTrue(trace.draftFocused)
        val oldCallback = trace.last("main-saved")
        val changes = trace.draftChanges
        update(validated.copy(state = SessionState.Loading, retainedState = validated.state, resolvingAuth = true))
        compose.onNodeWithTag("resolving").assertIsDisplayed()
        compose.onNodeWithTag("draft").assertDoesNotExist()
        compose.onAllNodes(hasClickAction()).assertCountEquals(0)
        assertFalse("hidden field must release keyboard focus", trace.draftFocused)
        compose.runOnIdle {
            oldCallback()
            controller.get().dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
            controller.get().dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
        }
        back()
        assertFalse(controller.get().isFinishing)
        assertEquals(0, refreshCalls)
        assertEquals(changes, trace.draftChanges)
        assertTrue(trace.cleared.isEmpty())
        update(validated)
        compose.onNodeWithTag("detail").assertIsDisplayed()
        compose.onNodeWithTag("draft").assertTextEquals("retained draft")
        assertEquals(listOf(1), trace.created)
        assertTrue(trace.cleared.isEmpty())
        back()
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
    }

    @Test fun `email updates and current profile refresh keep navigation intact`() {
        render(ready())
        openDraft("stable draft")
        update(ready().copy(state = SessionState.Ready("A", "changed@test.invalid", "hospital_admin"), profileLoading = true))
        compose.onNodeWithTag("detail").assertIsDisplayed()
        compose.onNodeWithTag("draft").assertTextEquals("stable draft")
        assertEquals(listOf(1), trace.created)
        assertTrue(trace.cleared.isEmpty())
    }

    @Test fun `onboarding stays mounted during unknown and old completion cannot bypass or affect B`() {
        val validated = onboarding("engineer", true)
        render(validated)
        val saved = trace.last("onboarding-saved")
        val mounts = trace.mounts.toList()
        update(validated.copy(state = SessionState.Loading, retainedState = validated.state, resolvingAuth = true))
        compose.runOnIdle { saved() }
        assertEquals(0, refreshCalls)
        assertEquals(mounts, trace.mounts)
        assertTrue(trace.disposals.isEmpty())
        update(validated)
        compose.onNodeWithTag("onboarding-kind").assertTextEquals("engineer:true")
        assertEquals(mounts, trace.mounts)
        update(needsRole("B", 2))
        compose.runOnIdle { saved() }
        assertEquals(0, refreshCalls)
        assertOnly("role")
    }

    @Test fun `captured callbacks cannot refresh or sign out a replacement or changed gate`() {
        render(needsRole())
        val oldSave = trace.last("role-saved")
        val oldSignOut = trace.last("role-sign-out")
        update(needsRole("B", 2))
        compose.runOnIdle { oldSave(); oldSignOut() }
        assertEquals(0, refreshCalls)
        assertEquals(0, signOutCalls)
        compose.onNodeWithTag("role-saved").performClick()
        compose.onNodeWithTag("role-sign-out").performClick()
        assertEquals(1, refreshCalls)
        assertEquals(1, signOutCalls)
        update(ready("B", 2))
        val mainSaved = trace.last("main-saved")
        update(onboarding("hospital_admin", false, "B", 2))
        compose.runOnIdle { mainSaved() }
        assertEquals(1, refreshCalls)
        assertOnly("onboarding")
    }

    @Test fun `auth and pending callbacks request refresh without direct main navigation`() {
        render(SessionPresentation(SessionState.SignedOut))
        val oldAuthSaved = trace.last("auth-saved")
        compose.onNodeWithTag("auth-saved").performClick()
        assertOnly("auth")
        assertEquals(1, refreshCalls)
        update(SessionPresentation(owner = owner()))
        compose.runOnIdle { oldAuthSaved() }
        assertEquals(1, refreshCalls)
        compose.onNodeWithTag("pending-retry").performClick()
        assertEquals(2, refreshCalls)
        assertOnly("pending")
        val retry = trace.last("pending-retry")
        val signOut = trace.last("pending-sign-out")
        update(needsRole("B", 2))
        compose.runOnIdle { retry(); signOut() }
        assertEquals(2, refreshCalls)
        assertEquals(0, signOutCalls)
    }

    @Test fun `encoded owner identifier cannot change the root route structure`() {
        render(ready(userId = "owner/with:delimiters?and#fragments"))
        assertOnly("main")
        assertNoWrongOwnerFrame()
    }

    @Test fun `cold legacy phone auth entry redirects to sign in without recoverable setup`() {
        assertLegacyPhoneRedirect(startAtLegacy = true)
    }

    @Test fun `entered legacy phone auth entry clears previous auth children before sign in`() {
        assertLegacyPhoneRedirect(startAtLegacy = false)
    }

    private fun assertLegacyPhoneRedirect(startAtLegacy: Boolean) {
        lateinit var nav: NavHostController
        controller.get().setContent {
            MaterialTheme {
                nav = rememberNavController()
                NavHost(nav, startDestination = Routes.AUTH_GRAPH) {
                    navigation(
                        route = Routes.AUTH_GRAPH,
                        startDestination = if (startAtLegacy) Routes.HOSPITAL_PHONE_ONBOARDING else Routes.AUTH_WELCOME,
                    ) {
                        composable(Routes.AUTH_WELCOME) {
                            Button(onClick = { nav.navigate(Routes.HOSPITAL_PHONE_ONBOARDING) },
                                modifier = Modifier.testTag("legacy-entry")) { Text("Restore legacy route") }
                        }
                        composable(Routes.AUTH_SIGN_IN) { Text("Inert sign in", Modifier.testTag("legacy-sign-in")) }
                        legacyPhoneAuthRedirect(nav)
                    }
                }
            }
        }
        compose.waitForIdle()
        if (!startAtLegacy) compose.onNodeWithTag("legacy-entry").performClick()
        compose.onNodeWithTag("legacy-sign-in").assertIsDisplayed()
        compose.runOnIdle {
            assertEquals(Routes.AUTH_SIGN_IN, nav.currentDestination?.route)
            assertEquals("all old auth children must be removed", null, nav.previousBackStackEntry)
        }
        back()
        compose.runOnIdle { assertFalse(nav.currentDestination?.route == Routes.HOSPITAL_PHONE_ONBOARDING) }
        compose.onNodeWithTag("legacy-entry").assertDoesNotExist()
    }

    @Test fun `AppNavGraph uses the explicit real root VM and profile callbacks stay pending until validated`() {
        val uid = AuthAuditFixtures.UID_A
        val auth = FakeAuthRepository(AuthSession.SignedIn(uid, AuthAuditFixtures.EMAIL_A))
        val prefs = RecordingUserPrefs.create()
        val requests = mutableListOf<CompletableDeferred<Result<Profile?>>>()
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(uid) } coAnswers {
                CompletableDeferred<Result<Profile?>>().also { requests += it }.await()
            }
        }
        val registrar = mockk<DeviceTokenRegistrar> { coEvery { refresh() } returns Unit }
        val cleanup = mockk<SignOutCleanup> { coEvery { wipeLocalUserState() } returns Unit }
        lateinit var vm: SessionViewModel
        compose.runOnUiThread {
            vm = SessionViewModel(auth, profiles, prefs.mock, registrar, cleanup)
            ownedViewModels += vm
            currentPresentation = { vm.presentation.value }
            controller.get().setContent { MaterialTheme { AppNavGraph(vm, slots()) } }
        }
        compose.waitForIdle()
        assertOnly("pending")
        assertEquals(1, requests.size)
        compose.runOnIdle { requests[0].complete(Result.success(AuthAuditFixtures.triggerDefaultProfile())) }
        compose.waitForIdle()
        assertOnly("role")
        compose.onNodeWithTag("role-saved").performClick()
        assertOnly("pending")
        assertEquals(2, requests.size)
        compose.runOnIdle { requests[1].complete(Result.success(AuthAuditFixtures.confirmedProfile(onboarded = false))) }
        compose.waitForIdle()
        assertOnly("onboarding")
        compose.onNodeWithTag("onboarding-saved").performClick()
        assertOnly("pending")
        assertEquals(3, requests.size)
        compose.runOnIdle { requests[2].complete(Result.success(AuthAuditFixtures.confirmedProfile())) }
        compose.waitForIdle()
        assertOnly("main")
        openDraft("owned draft")
        val oldMainSaved = trace.last("main-saved")
        compose.onNodeWithTag("main-saved").performClick()
        assertOnly("pending")
        assertEquals(listOf(1), trace.cleared)
        assertEquals(4, requests.size)
        compose.runOnIdle {
            oldMainSaved()
            requests[3].complete(Result.failure(IOException("offline fixture")))
        }
        compose.waitForIdle()
        assertOnly("pending")
        assertEquals(4, requests.size)
        assertTrue(vm.presentation.value.profileFailed)
        compose.onNodeWithTag("pending-retry").performClick()
        assertEquals(5, requests.size)
        compose.runOnIdle { requests[4].complete(Result.success(AuthAuditFixtures.confirmedProfile())) }
        compose.waitForIdle()
        assertOnly("main")
        compose.onNodeWithTag("open-detail").assertIsDisplayed()
        assertEquals(listOf(1, 2), trace.created)
        assertNoWrongOwnerFrame()
    }

    @Test fun `old composed callbacks cannot act on B before the next Compose frame`() {
        val a = AuthAuditFixtures.UID_A
        val b = AuthAuditFixtures.UID_B
        val auth = FakeAuthRepository(AuthSession.SignedIn(a, AuthAuditFixtures.EMAIL_A))
        val prefs = RecordingUserPrefs.create()
        val fetches = mutableListOf<String>()
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(any()) } coAnswers {
                val uid = firstArg<String>()
                fetches += uid
                Result.success(AuthAuditFixtures.triggerDefaultProfile(id = uid))
            }
        }
        val registrar = mockk<DeviceTokenRegistrar> { coEvery { refresh() } returns Unit }
        val cleanup = mockk<SignOutCleanup> { coEvery { wipeLocalUserState() } returns Unit }
        lateinit var vm: SessionViewModel
        compose.runOnUiThread {
            vm = SessionViewModel(auth, profiles, prefs.mock, registrar, cleanup)
            ownedViewModels += vm
            currentPresentation = { vm.presentation.value }
            controller.get().setContent { MaterialTheme { AppNavGraph(vm, slots()) } }
        }
        compose.waitForIdle()
        assertOnly("role")
        val savedByA = trace.last("role-saved")
        val signOutByA = trace.last("role-sign-out")
        compose.mainClock.autoAdvance = false
        try {
            compose.runOnIdle { auth.setSession(AuthSession.SignedIn(b, AuthAuditFixtures.EMAIL_B)) }
            compose.runOnIdle {
                assertEquals("fixture must advance the real VM to B", b, vm.presentation.value.owner?.userId)
                assertEquals("fixture must keep A's old composition until the next frame", a,
                    trace.frames.last().expectedOwner?.userId)
                savedByA()
                signOutByA()
            }
            assertEquals(listOf(a, b), fetches)
            assertEquals(0, auth.signOutCount)
            coVerify(exactly = 0) { cleanup.wipeLocalUserState() }
            assertEquals(SessionState.NeedsRole(b, AuthAuditFixtures.EMAIL_B), vm.presentation.value.state)
        } finally {
            compose.mainClock.autoAdvance = true
        }
        compose.waitForIdle()
        assertOnly("role")
        assertNoWrongOwnerFrame()
    }

    @Test fun `old composed callbacks cannot revoke or invalidate retained A during unknown`() {
        val uid = AuthAuditFixtures.UID_A
        val auth = FakeAuthRepository(AuthSession.SignedIn(uid, AuthAuditFixtures.EMAIL_A))
        val prefs = RecordingUserPrefs.create()
        var fetches = 0
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(uid) } coAnswers {
                fetches++
                Result.success(AuthAuditFixtures.triggerDefaultProfile())
            }
        }
        val registrar = mockk<DeviceTokenRegistrar> { coEvery { refresh() } returns Unit }
        val cleanup = mockk<SignOutCleanup> { coEvery { wipeLocalUserState() } returns Unit }
        lateinit var vm: SessionViewModel
        compose.runOnUiThread {
            vm = SessionViewModel(auth, profiles, prefs.mock, registrar, cleanup)
            ownedViewModels += vm
            currentPresentation = { vm.presentation.value }
            controller.get().setContent { MaterialTheme { AppNavGraph(vm, slots()) } }
        }
        compose.waitForIdle()
        assertOnly("role")
        val saved = trace.last("role-saved")
        val signOut = trace.last("role-sign-out")
        val validated = vm.presentation.value.state
        compose.mainClock.autoAdvance = false
        try {
            compose.runOnIdle { auth.setSession(AuthSession.Unknown) }
            compose.runOnIdle {
                assertTrue("fixture must resolve Unknown in the VM first", vm.presentation.value.resolvingAuth)
                assertEquals("fixture must retain the old composed gate", validated, trace.frames.last().gateState)
                saved()
                signOut()
            }
            assertEquals(validated, vm.presentation.value.retainedState)
            assertEquals(1, fetches)
            coVerify(exactly = 0) { cleanup.wipeLocalUserState() }
            assertEquals(0, auth.signOutCount)
        } finally { compose.mainClock.autoAdvance = true }
        compose.waitForIdle()
        compose.onNodeWithTag("resolving").assertIsDisplayed()
        compose.runOnIdle { auth.setSession(AuthSession.SignedIn(uid, AuthAuditFixtures.EMAIL_A)) }
        compose.waitForIdle()
        assertOnly("role")
        assertEquals(validated, vm.presentation.value.state)
        assertEquals(1, fetches)
        assertEquals(0, auth.signOutCount)
        coVerify(exactly = 0) { cleanup.wipeLocalUserState() }
    }

    @Test fun `auth entry cancellation after auto login leaves recoverable role gate`() {
        val auth = FakeAuthRepository(AuthSession.SignedOut)
        val prefs = RecordingUserPrefs.create()
        val continuationEntered = CompletableDeferred<Unit>()
        val continuationRelease = CompletableDeferred<Unit>()
        val roleResponse = CompletableDeferred<Result<Profile?>>()
        var fetches = 0
        var authEntryClears = 0
        var continuationFinished = 0
        var continuationCompleted = 0
        val profiles = mockk<ProfileRepository> {
            coEvery { fetchById(AuthAuditFixtures.UID_A) } coAnswers {
                fetches++
                if (fetches == 1) Result.success(AuthAuditFixtures.triggerDefaultProfile()) else roleResponse.await()
            }
        }
        val registrar = mockk<DeviceTokenRegistrar> { coEvery { refresh() } returns Unit }
        val cleanup = mockk<SignOutCleanup> { coEvery { wipeLocalUserState() } returns Unit }
        lateinit var vm: SessionViewModel
        val fixtureSlots = slots().copy(auth = { saved -> Slot("auth") {
            val signup = viewModel<SignupEntryViewModel>(factory = object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    SignupEntryViewModel { authEntryClears++ } as T
            })
            Action("auth-auto-login") {
                signup.viewModelScope.launch {
                    try {
                        auth.setSession(AuthSession.SignedIn(AuthAuditFixtures.UID_A, AuthAuditFixtures.EMAIL_A))
                        continuationEntered.complete(Unit)
                        continuationRelease.await()
                        continuationCompleted++
                        saved()
                    } finally { continuationFinished++ }
                }
            }
        } })
        compose.runOnUiThread {
            vm = SessionViewModel(auth, profiles, prefs.mock, registrar, cleanup)
            ownedViewModels += vm
            currentPresentation = { vm.presentation.value }
            controller.get().setContent { MaterialTheme { AppNavGraph(vm, fixtureSlots) } }
        }
        compose.waitForIdle()
        assertOnly("auth")
        try {
            compose.onNodeWithTag("auth-auto-login").performClick()
            compose.waitForIdle()
            assertTrue(continuationEntered.isCompleted)
            assertFalse(continuationRelease.isCompleted)
            assertOnly("role")
            assertEquals(1, authEntryClears)
            assertEquals(1, continuationFinished)
            assertEquals(0, continuationCompleted)
            compose.runOnIdle { continuationRelease.complete(Unit) }
            compose.waitForIdle()
            assertEquals(0, continuationCompleted)
            assertEquals(1, fetches)
            compose.onNodeWithTag("role-saved").performClick()
            assertOnly("pending")
            assertEquals(2, fetches)
            compose.runOnIdle { roleResponse.complete(Result.success(AuthAuditFixtures.confirmedProfile())) }
            compose.waitForIdle()
            assertOnly("main")
            assertEquals(2, fetches)
            assertEquals(0, auth.signOutCount)
            coVerify(exactly = 0) { cleanup.wipeLocalUserState() }
        } finally {
            continuationRelease.complete(Unit)
            roleResponse.complete(Result.success(AuthAuditFixtures.confirmedProfile()))
        }
    }

    companion object {
        private fun owner(userId: String = "A", generation: Long = 1) = SessionOwner(userId, generation)
        private fun ready(userId: String = "A", generation: Long = 1, role: String = "hospital_admin") =
            SessionPresentation(SessionState.Ready(userId, "$userId@test.invalid", role), owner(userId, generation), true)
        private fun needsRole(userId: String = "A", generation: Long = 1) =
            SessionPresentation(SessionState.NeedsRole(userId, "$userId@test.invalid"), owner(userId, generation))
        private fun onboarding(role: String, baseDone: Boolean, userId: String = "A", generation: Long = 1) =
            SessionPresentation(SessionState.NeedsOnboarding(userId, "$userId@test.invalid", role), owner(userId, generation), baseDone)
    }
}
