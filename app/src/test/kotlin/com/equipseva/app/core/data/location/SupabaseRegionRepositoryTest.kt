package com.equipseva.app.core.data.location

import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * SupabaseRegionRepository against a ktor MockEngine: the RPC names and parameter names the
 * round3830 SQL defines, decoding with the app's serializer settings, refusal mapping, and a
 * cancelled caller staying cancelled.
 */
class SupabaseRegionRepositoryTest {
    private data class Seen(val path: String, val body: JsonObject?)

    private val seen = mutableListOf<Seen>()

    private fun repo(status: HttpStatusCode = HttpStatusCode.OK, body: String = "{}", hang: CompletableDeferred<Unit>? = null) =
        SupabaseRegionRepository(
            createSupabaseClient(supabaseUrl = "https://fake.supabase.co", supabaseKey = "anon-key") {
                // Same settings as SupabaseModule.
                defaultSerializer = KotlinXSerializer(Json { coerceInputValues = true; ignoreUnknownKeys = true; isLenient = true })
                httpEngine = MockEngine { request ->
                    val text = request.body.toByteArray().decodeToString()
                    seen += Seen(request.url.encodedPath, text.takeIf { it.isNotBlank() }?.let { Json.parseToJsonElement(it).jsonObject })
                    if (hang != null) {
                        hang.complete(Unit)
                        awaitCancellation()
                    }
                    respond(content = body, status = status, headers = headersOf(HttpHeaders.ContentType, "application/json"))
                }
                install(Postgrest)
            },
        )

    @Test
    fun `set_my_home_region sends the three named parameters and decodes the result`() = runTest {
        val saved = repo(body = """{"state_code":"901","state_name":"Alpha State","district_code":"90102","district_name":"Riverton","catalog_version":"synthetic-v2","status":"resolved"}""")
            .setMyHomeRegion("901", "90102", "synthetic-v2").getOrThrow()
        assertEquals("Riverton", saved.districtName)
        val call = seen.single()
        assertEquals("/rest/v1/rpc/set_my_home_region", call.path)
        assertEquals(setOf("p_state_code", "p_district_code", "p_catalog_version"), call.body!!.keys)
        assertEquals("\"901\"", call.body["p_state_code"].toString())
    }

    @Test
    fun `set_my_service_districts sends the codes as a JSON array`() = runTest {
        repo(body = """{"catalog_version":"synthetic-v2","district_codes":["90102","90202"],"count":2}""")
            .setMyServiceDistricts(listOf("90102", "90202"), "synthetic-v2").getOrThrow()
        val call = seen.single()
        assertEquals("/rest/v1/rpc/set_my_service_districts", call.path)
        assertEquals("[\"90102\",\"90202\"]", call.body!!["p_district_codes"].toString())
        assertEquals("\"synthetic-v2\"", call.body["p_catalog_version"].toString())
    }

    @Test
    fun `region_catalog_current and my_region_profile decode their real shapes`() = runTest {
        val status = repo(body = """[{"current_version":null,"supported_versions":[],"is_synthetic":false,"state_count":0,"district_count":0}]""")
            .catalogStatus().getOrThrow()
        assertNull(status.currentVersion)
        assertEquals("/rest/v1/rpc/region_catalog_current", seen.single().path)

        val profile = repo(body = """{"home":null,"home_stale":false,"legacy_state_label":"Alpha State","legacy_district_label":null,"legacy_preview":null,"is_engineer":false,"service_districts":[],"service_source":"none","service_stale":false,"current_catalog_version":null}""")
            .myRegionProfile().getOrThrow()
        assertEquals("Alpha State", profile.legacyStateLabel)
        assertEquals("/rest/v1/rpc/my_region_profile", seen.last().path)
    }

    @Test
    fun `a server refusal is a failure carrying its code`() = runTest {
        val result = repo(status = HttpStatusCode.BadRequest, body = """{"code":"22023","details":null,"hint":null,"message":"region_pair_invalid"}""")
            .setMyHomeRegion("901", "90201", "synthetic-v2")
        assertTrue(result.isFailure)
        assertEquals(RegionWriteError.PairInvalid, RegionWriteError.from(result.exceptionOrNull()))
    }

    @Test
    fun `a cancelled caller stays cancelled instead of receiving a failure`() = runTest {
        val started = CompletableDeferred<Unit>()
        val repository = repo(hang = started)
        var delivered: Result<HomeRegionSaved>? = null
        val job = launch { delivered = repository.setMyHomeRegion("901", "90102", "synthetic-v2") }
        started.await()
        job.cancel()
        job.join()
        assertTrue(job.isCancelled)
        assertNull("a cancellation must not be turned into a Result", delivered)
    }
}
