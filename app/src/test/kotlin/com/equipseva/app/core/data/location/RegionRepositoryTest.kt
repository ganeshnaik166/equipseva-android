package com.equipseva.app.core.data.location

import com.equipseva.app.testing.FakeRest
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Wire contract with the round3830 RPCs: the JSON bodies below are the exact shapes the SQL
 * builds (jsonb_build_object keys and TABLE columns in
 * supabase/migrations/20263915000000_round3830_region_catalog_v1.sql).
 */
class RegionRepositoryTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `region_catalog_current rows decode, including the unseeded state`() {
        val seeded = json.decodeFromString<List<RegionCatalogStatus>>(
            """[{"current_version":"synthetic-v2","supported_versions":["synthetic-v2"],"is_synthetic":true,"state_count":2,"district_count":6}]""",
        ).single()
        assertEquals("synthetic-v2", seeded.currentVersion)
        assertTrue(seeded.acceptsWritesFrom("synthetic-v2"))
        assertFalse(seeded.acceptsWritesFrom("synthetic-v1"))

        val unseeded = json.decodeFromString<List<RegionCatalogStatus>>(
            """[{"current_version":null,"supported_versions":[],"is_synthetic":false,"state_count":0,"district_count":0}]""",
        ).single()
        assertNull(unseeded.currentVersion)
        assertFalse(unseeded.acceptsWritesFrom("synthetic-v2"))
    }

    @Test
    fun `set_my_home_region and set_my_service_districts results decode`() {
        val home = json.decodeFromString<HomeRegionSaved>(
            """{"state_code":"901","state_name":"Alpha State","district_code":"90104","district_name":"Lakeside East","catalog_version":"synthetic-v2","status":"resolved"}""",
        )
        assertEquals("90104", home.districtCode)
        assertEquals("Lakeside East", home.districtName)
        val service = json.decodeFromString<ServiceDistrictsSaved>(
            """{"catalog_version":"synthetic-v2","district_codes":["90102","90202"],"count":2}""",
        )
        assertEquals(listOf("90102", "90202"), service.districtCodes)
    }

    @Test
    fun `my_region_profile decodes a coded row, a stale preview and a legacy-only user`() {
        val coded = json.decodeFromString<MyRegionProfile>(
            """{"home":{"state_code":"901","district_code":"90102","catalog_version":"synthetic-v2","status":"resolved","source":"legacy_backfill","legacy_state_label":"Alpha State","legacy_district_label":"Old Riverton","district_active":false},
               "home_stale":true,"legacy_state_label":"Alpha State","legacy_district_label":"Riverton",
               "legacy_preview":{"status":"resolved","state_code":"901","district_code":"90102","reason":null,"candidate_codes":["90102"],"catalog_version":"synthetic-v2"},
               "is_engineer":true,"service_districts":[{"district_code":"90101","catalog_version":"synthetic-v2","source":"legacy_backfill","active":false}],
               "service_source":"legacy_backfill","service_stale":false,
               "current_catalog_version":"synthetic-v2"}""",
        )
        assertEquals("legacy_backfill", coded.serviceSource)
        assertFalse(coded.serviceStale)
        assertTrue(coded.home!!.isResolved)
        assertTrue(coded.homeStale)
        assertEquals("90102", coded.legacyPreview!!.districtCode)
        assertEquals("90101", coded.serviceDistricts.single().districtCode)
        assertEquals(false, coded.home!!.districtActive)
        assertFalse(coded.serviceDistricts.single().active)

        val legacyOnly = json.decodeFromString<MyRegionProfile>(
            """{"home":null,"home_stale":false,"legacy_state_label":"Alpha State","legacy_district_label":"Lakeside",
               "legacy_preview":{"status":"needs_confirmation","state_code":"901","district_code":null,"reason":"ambiguous","candidate_codes":["90104","90105"],"catalog_version":"synthetic-v2"},
               "is_engineer":false,"service_districts":[],"service_source":"none","service_stale":false,"current_catalog_version":"synthetic-v2"}""",
        )
        assertNull(legacyOnly.home)
        assertEquals("none", legacyOnly.serviceSource)
        assertEquals("ambiguous", legacyOnly.legacyPreview!!.reason)
        assertEquals("Lakeside", legacyOnly.legacyDistrictLabel)

        val needsConfirmation = MyRegionProfile.HomeRegion(
            stateCode = "901", districtCode = null, catalogVersion = "synthetic-v2",
            status = "needs_confirmation", source = "legacy_backfill",
        )
        assertFalse(needsConfirmation.isResolved)
    }

    @Test
    fun `every server refusal is recognised from a PostgREST error`() {
        RegionWriteError.entries.forEach { e ->
            val error = FakeRest.rest(400, """{"code":"22023","details":null,"hint":null,"message":"${e.raiseCode}"}""")
            assertEquals(e, RegionWriteError.from(error))
        }
    }

    @Test
    fun `refusals are found through causes and never by partial words`() {
        val wrapped = RuntimeException("save failed", FakeRest.rest(400, """{"message":"region_district_retired"}"""))
        assertEquals(RegionWriteError.DistrictRetired, RegionWriteError.from(wrapped))
        assertNull(RegionWriteError.from(FakeRest.rest(400, """{"message":"user_not_authenticated_yet"}""")))
        assertNull(RegionWriteError.from(FakeRest.rest(500, """{"message":"connection reset"}""")))
        assertNull(RegionWriteError.from(null))
    }
}
