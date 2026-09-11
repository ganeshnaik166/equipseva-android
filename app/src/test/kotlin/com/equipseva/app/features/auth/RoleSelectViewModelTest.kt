package com.equipseva.app.features.auth

import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectEffect
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectError
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.IOException

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RoleSelectViewModelTest {
    private val fixtures = mutableListOf<Fixture>()

    @Before fun setUp() { Dispatchers.setMain(StandardTestDispatcher()) }
    @After fun tearDown() {
        fixtures.forEach { it.close() }
        Dispatchers.resetMain()
    }

    private class AddRole(val key: String) {
        val result = CompletableDeferred<Result<Unit>>()
    }

    private class Fixture(initial: AuthSession) {
        val sessions = MutableSharedFlow<AuthSession>(replay = 1, extraBufferCapacity = 16)
            .also { it.tryEmit(initial) }
        val auth = mockk<AuthRepository> { every { sessionState } returns sessions }
        val calls = mutableListOf<AddRole>()
        val profiles = mockk<ProfileRepository> {
            coEvery { addRole(any()) } coAnswers {
                val call = AddRole(firstArg())
                calls += call
                // The production repository wraps RPCs in runCatching. A late
                // result must be fenced even if cancellation is swallowed.
                withContext(NonCancellable) { call.result.await() }
            }
        }
        val vm = RoleSelectViewModel(auth, profiles)
        fun session(session: AuthSession) { check(sessions.tryEmit(session)) }
        fun close() {
            vm.viewModelScope.cancel()
            calls.forEach { it.result.complete(Result.failure(CancellationException("Test finished"))) }
        }
    }

    private fun fixture(initial: AuthSession = signedIn("A")) = Fixture(initial).also { fixtures += it }

    private fun TestScope.effects(f: Fixture): MutableList<RoleSelectEffect> =
        mutableListOf<RoleSelectEffect>().also { events ->
            backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
                f.vm.effects.collect { events += it }
            }
        }

    @Test fun `only active roles can be selected or confirmed`() = runTest {
        val f = fixture()
        runCurrent()
        assertEquals(listOf(UserRole.HOSPITAL, UserRole.ENGINEER), f.vm.state.value.roles)
        for (unsupported in listOf(UserRole.SUPPLIER, UserRole.MANUFACTURER, UserRole.LOGISTICS)) {
            f.vm.onRoleSelected(unsupported)
            f.vm.onConfirm()
            runCurrent()
            assertNull(f.vm.state.value.selected)
            assertFalse(f.vm.state.value.canConfirm)
            assertTrue(f.calls.isEmpty())
            assertFalse(RoleSelectViewModel.RoleSelectState(selected = unsupported).canConfirm)
        }
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onRoleSelected(UserRole.SUPPLIER)
        assertEquals(UserRole.HOSPITAL, f.vm.state.value.selected)
    }

    @Test fun `hospital confirmation calls add role and requests authoritative refresh once`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        assertEquals(listOf("hospital_admin"), f.calls.map { it.key })
        assertTrue(f.vm.state.value.form.submitting)
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertEquals(listOf(RoleSelectEffect.RoleSaved), events)
        assertTrue(f.vm.state.value.saved)
        assertFalse(f.vm.state.value.form.submitting)
        assertFalse(f.vm.state.value.canConfirm)
        coVerify(exactly = 0) { f.profiles.updateRole(any(), any()) }
        coVerify(exactly = 0) { f.auth.signOut() }
    }

    @Test fun `engineer confirmation uses engineer RPC key`() = runTest {
        val f = fixture()
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        assertEquals(listOf("engineer"), f.calls.map { it.key })
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertTrue(f.vm.state.value.saved)
    }

    @Test fun `double confirm and role changes while saving cannot start a second RPC`() = runTest {
        val f = fixture()
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        f.vm.onConfirm()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        runCurrent()
        assertEquals(listOf("hospital_admin"), f.calls.map { it.key })
        assertEquals(UserRole.HOSPITAL, f.vm.state.value.selected)
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        f.vm.onConfirm()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        runCurrent()
        assertEquals(1, f.calls.size)
        assertEquals(UserRole.HOSPITAL, f.vm.state.value.selected)
    }

    @Test fun `checking saved setup again requests refresh without repeating add role`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onCheckSavedRole()
        runCurrent()
        assertTrue(events.isEmpty())
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        f.vm.onCheckSavedRole()
        runCurrent()
        assertEquals(listOf(RoleSelectEffect.RoleSaved, RoleSelectEffect.RoleSaved), events)
        assertEquals(1, f.calls.size)
    }

    @Test fun `network failure releases submitting and retry can succeed`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        f.calls.single().result.complete(Result.failure(IOException("offline")))
        runCurrent()
        assertEquals(RoleSelectError.Network, f.vm.state.value.error)
        assertFalse(f.vm.state.value.form.submitting)
        assertTrue(f.vm.state.value.canConfirm)
        assertTrue(events.isEmpty())
        f.vm.onConfirm()
        runCurrent()
        f.calls.last().result.complete(Result.success(Unit))
        runCurrent()
        assertEquals(2, f.calls.size)
        assertNull(f.vm.state.value.error)
        assertTrue(f.vm.state.value.saved)
        assertEquals(listOf(RoleSelectEffect.RoleSaved), events)
    }

    @Test fun `thrown failure recovers and changing selection clears localized error`() = runTest {
        val f = fixture()
        coEvery { f.profiles.addRole(any()) } throws IllegalStateException("RPC rejected")
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        assertEquals(RoleSelectError.SaveFailed, f.vm.state.value.error)
        assertFalse(f.vm.state.value.form.submitting)
        f.vm.onRoleSelected(UserRole.ENGINEER)
        assertNull(f.vm.state.value.error)
        assertTrue(f.vm.state.value.canConfirm)
    }

    @Test fun `wrapped cancellation is not a user error or a successful save`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        f.calls.single().result.complete(Result.failure(CancellationException("Cancelled RPC")))
        runCurrent()
        assertNull(f.vm.state.value.error)
        assertFalse(f.vm.state.value.form.submitting)
        assertFalse(f.vm.state.value.saved)
        assertTrue(f.vm.state.value.canConfirm)
        assertTrue(events.isEmpty())
    }

    @Test fun `thrown cancellation propagates while the form remains retryable`() = runTest {
        val f = fixture()
        val events = effects(f)
        coEvery { f.profiles.addRole(any()) } throws CancellationException("Cancelled RPC")
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        assertNull(f.vm.state.value.error)
        assertFalse(f.vm.state.value.form.submitting)
        assertFalse(f.vm.state.value.saved)
        assertTrue(events.isEmpty())
    }

    private fun missingSessionDoesNotWait(initial: AuthSession) = runTest {
        val f = fixture(initial)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        assertEquals(RoleSelectError.SessionUnavailable, f.vm.state.value.error)
        assertFalse(f.vm.state.value.form.submitting)
        assertTrue(f.calls.isEmpty())
        f.session(signedIn("B"))
        runCurrent()
        assertTrue(f.calls.isEmpty())
        assertNull(f.vm.state.value.selected)
        assertNull(f.vm.state.value.error)
    }

    @Test fun `signed out confirmation does not wait for the next login`() =
        missingSessionDoesNotWait(AuthSession.SignedOut)

    @Test fun `unknown confirmation does not wait for the next login`() =
        missingSessionDoesNotWait(AuthSession.Unknown)

    @Test fun `blank identity cannot confirm a role`() =
        missingSessionDoesNotWait(AuthSession.SignedIn(" ", null))

    private fun staleSave(sameAccount: Boolean, oldResult: Result<Unit>) = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        val old = f.calls.single()
        if (sameAccount) {
            f.session(AuthSession.SignedOut)
            runCurrent()
        }
        f.session(signedIn(if (sameAccount) "A" else "B"))
        runCurrent()
        assertNull(f.vm.state.value.selected)
        assertFalse(f.vm.state.value.saved)
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        assertEquals(2, f.calls.size)
        old.result.complete(oldResult)
        runCurrent()
        assertTrue(f.vm.state.value.form.submitting)
        assertNull(f.vm.state.value.error)
        assertFalse(f.vm.state.value.saved)
        assertTrue(events.isEmpty())
        f.calls.last().result.complete(Result.success(Unit))
        runCurrent()
        assertTrue(f.vm.state.value.saved)
        assertEquals(listOf(RoleSelectEffect.RoleSaved), events)
    }

    @Test fun `late A save success cannot affect B`() = staleSave(false, Result.success(Unit))
    @Test fun `late A save error cannot affect B`() = staleSave(false, Result.failure(IOException("old offline")))
    @Test fun `late first A success cannot affect second A login`() = staleSave(true, Result.success(Unit))
    @Test fun `late first A error cannot affect second A login`() = staleSave(true, Result.failure(IOException("old offline")))

    @Test fun `direct A B A changes generation without requiring sign out`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        f.session(signedIn("B"))
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertNull(f.vm.state.value.selected)
        assertFalse(f.vm.state.value.saved)
        assertFalse(f.vm.state.value.form.submitting)
        assertTrue(events.isEmpty())
    }

    @Test fun `queued response checks live auth before observer handles B`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        f.calls.single().result.complete(Result.success(Unit))
        f.session(signedIn("B"))
        runCurrent()
        assertTrue(events.isEmpty())
        assertNull(f.vm.state.value.selected)
        assertFalse(f.vm.state.value.saved)
    }

    @Test fun `queued saved effect cannot be delivered after upstream switches to B`() = runTest {
        val f = fixture()
        val events = mutableListOf<RoleSelectEffect>()
        backgroundScope.launch { f.vm.effects.collect { events += it } }
        var replaceOnce = true
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            f.vm.state.collect { state ->
                if (state.saved && replaceOnce) {
                    replaceOnce = false
                    // This publisher is queued before the normal effect
                    // collector; B's auth observer can still be queued behind it.
                    backgroundScope.launch { f.session(signedIn("B")) }
                }
            }
        }
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertTrue(events.isEmpty())
        assertFalse(f.vm.state.value.saved)
        f.vm.onCheckSavedRole()
        runCurrent()
        assertTrue(events.isEmpty())
    }

    @Test fun `same login duplicate and email update preserve the current save`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        f.session(signedIn("A"))
        runCurrent()
        f.session(AuthSession.SignedIn("A", "new@test.invalid"))
        runCurrent()
        assertTrue(f.vm.state.value.form.submitting)
        assertEquals(UserRole.ENGINEER, f.vm.state.value.selected)
        assertEquals(1, f.calls.size)
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertEquals(listOf(RoleSelectEffect.RoleSaved), events)
    }

    @Test fun `unknown cancels save but same login can retry the retained selection`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        f.session(AuthSession.Unknown)
        runCurrent()
        assertFalse(f.vm.state.value.form.submitting)
        assertEquals(UserRole.HOSPITAL, f.vm.state.value.selected)
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertTrue(events.isEmpty())
        f.session(signedIn("A"))
        runCurrent()
        assertNull(f.vm.state.value.error)
        f.vm.onConfirm()
        runCurrent()
        assertEquals(2, f.calls.size)
        f.calls.last().result.complete(Result.success(Unit))
        runCurrent()
        assertEquals(listOf(RoleSelectEffect.RoleSaved), events)
    }

    @Test fun `sign out callback preparation cancels save without signing out in the VM`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.ENGINEER)
        f.vm.onConfirm()
        runCurrent()
        f.vm.cancelPendingSave()
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertFalse(f.vm.state.value.form.submitting)
        assertFalse(f.vm.state.value.saved)
        assertTrue(events.isEmpty())
        coVerify(exactly = 0) { f.auth.signOut() }
    }

    @Test fun `cleared VM cannot publish late non cooperative save result`() = runTest {
        val f = fixture()
        val events = effects(f)
        runCurrent()
        f.vm.onRoleSelected(UserRole.HOSPITAL)
        f.vm.onConfirm()
        runCurrent()
        f.vm.viewModelScope.cancel()
        f.calls.single().result.complete(Result.success(Unit))
        runCurrent()
        assertFalse(f.vm.state.value.saved)
        assertTrue(events.isEmpty())
    }

    companion object {
        private fun signedIn(id: String) = AuthSession.SignedIn(id, "$id@test.invalid")
    }
}
