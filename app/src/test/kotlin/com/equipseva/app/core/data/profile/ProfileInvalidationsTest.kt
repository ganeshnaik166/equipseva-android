package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole
import com.equipseva.app.testing.TestSupabaseClient
import com.equipseva.app.testing.TestSupabaseClient.importSyntheticSession
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

/** Real repository + SDK; MockEngine is the only network boundary. */
class ProfileInvalidationsTest {
    @Test fun `successful role mutations each notify without returning navigation authority`() = runTest {
        val harness = TestSupabaseClient.build { HttpStatusCode.NoContent to "" }
        try {
            harness.client.importSyntheticSession("A")
            val changes = ProfileInvalidations()
            val repository = SupabaseProfileRepository(harness.client, changes)
            assertTrue(repository.addRole("hospital_admin").isSuccess)
            assertEquals(1L, changes.revision.value)
            assertTrue(repository.setActiveRole("engineer").isSuccess)
            assertEquals(2L, changes.revision.value)
            assertTrue(repository.updateRole("A", UserRole.HOSPITAL).isSuccess)
            assertEquals(3L, changes.revision.value)
            assertEquals(listOf("/rest/v1/rpc/add_role", "/rest/v1/rpc/set_active_role", "/rest/v1/profiles"),
                harness.recorded.map { it.request.url.encodedPath })
            assertEquals("{\"p_role\":\"hospital_admin\"}", harness.recorded[0].body)
            assertEquals("{\"p_role\":\"engineer\"}", harness.recorded[1].body)
        } finally { harness.close() }
    }

    @Test fun `rejected role mutations never notify and successful retry does`() = runTest {
        val harness = TestSupabaseClient.build {
            HttpStatusCode.Forbidden to """{"message":"denied","code":"42501"}"""
        }
        try {
            harness.client.importSyntheticSession("A")
            val changes = ProfileInvalidations()
            val repository = SupabaseProfileRepository(harness.client, changes)
            assertTrue(repository.addRole("hospital_admin").isFailure)
            assertTrue(repository.setActiveRole("engineer").isFailure)
            assertTrue(repository.updateRole("A", UserRole.HOSPITAL).isFailure)
            assertEquals(0L, changes.revision.value)
            harness.answer = { HttpStatusCode.NoContent to "" }
            assertTrue(repository.addRole("hospital_admin").isSuccess)
            assertEquals(1L, changes.revision.value)
        } finally { harness.close() }
    }

    @Test fun `foreign user update is rejected locally without invalidating the active host`() = runTest {
        val harness = TestSupabaseClient.build()
        try {
            harness.client.importSyntheticSession("B")
            val changes = ProfileInvalidations()
            val repository = SupabaseProfileRepository(harness.client, changes)
            assertTrue(repository.updateRole("A", UserRole.HOSPITAL).isFailure)
            assertEquals(0L, changes.revision.value)
            assertTrue(harness.recorded.isEmpty())
        } finally { harness.close() }
    }
}
