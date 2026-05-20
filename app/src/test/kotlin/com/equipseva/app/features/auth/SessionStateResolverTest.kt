package com.equipseva.app.features.auth

import com.equipseva.app.core.auth.AuthSession
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The root nav graph branches on SessionState — a misresolve here
 * either bounces a signed-in user back to Welcome (lost session feel)
 * or lands them on a Hub before their role is known (wrong dashboard).
 * Pin the full 3-axis matrix (session × role × syncing).
 */
class SessionStateResolverTest {

    @Test fun `unknown session maps to Loading regardless of role or sync`() {
        assertEquals(
            SessionState.Loading,
            resolveSessionState(AuthSession.Unknown, role = null, syncing = false),
        )
        assertEquals(
            SessionState.Loading,
            resolveSessionState(AuthSession.Unknown, role = "engineer", syncing = true),
        )
    }

    @Test fun `SignedOut is terminal regardless of role or sync`() {
        assertEquals(
            SessionState.SignedOut,
            resolveSessionState(AuthSession.SignedOut, role = null, syncing = false),
        )
        // Stale local-pref role doesn't bring a signed-out user back to Ready.
        assertEquals(
            SessionState.SignedOut,
            resolveSessionState(AuthSession.SignedOut, role = "engineer", syncing = false),
        )
    }

    @Test fun `SignedIn with non-blank role maps to Ready`() {
        val out = resolveSessionState(
            AuthSession.SignedIn(userId = "u1", email = "x@y.com"),
            role = "hospital_admin",
            syncing = false,
        )
        assertEquals(
            SessionState.Ready("u1", "x@y.com", "hospital_admin"),
            out,
        )
    }

    @Test fun `SignedIn with role wins over syncing flag`() {
        // If we already have a role, the in-flight profile fetch is
        // belt-and-braces — render Ready instead of bouncing through Loading.
        val out = resolveSessionState(
            AuthSession.SignedIn("u1", "x@y.com"),
            role = "engineer",
            syncing = true,
        )
        assertEquals(SessionState.Ready("u1", "x@y.com", "engineer"), out)
    }

    @Test fun `SignedIn with blank role and syncing maps to Loading`() {
        // Brief window between Supabase session restore + profile fetch.
        // Bouncing to RoleSelect here would flicker the wrong screen on
        // every cold start.
        val out = resolveSessionState(
            AuthSession.SignedIn("u1", "x@y.com"),
            role = null,
            syncing = true,
        )
        assertEquals(SessionState.Loading, out)
    }

    @Test fun `SignedIn with blank role and settled bootstrap maps to NeedsRole`() {
        val out = resolveSessionState(
            AuthSession.SignedIn("u1", "x@y.com"),
            role = null,
            syncing = false,
        )
        assertEquals(SessionState.NeedsRole("u1", "x@y.com"), out)
    }

    @Test fun `SignedIn with whitespace-only role is treated as blank`() {
        // Defensive: a stale " " in prefs shouldn't land the user in a
        // Ready state with an unrenderable role.
        val out = resolveSessionState(
            AuthSession.SignedIn("u1", null),
            role = "   ",
            syncing = false,
        )
        assertEquals(SessionState.NeedsRole("u1", null), out)
    }
}
