package com.equipseva.app.features.onboarding

import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.location.HomeRegionSaved
import com.equipseva.app.core.data.location.IndiaLocations
import com.equipseva.app.core.data.location.MyRegionProfile
import com.equipseva.app.core.data.location.RegionAssetReader
import com.equipseva.app.core.data.location.RegionCatalogPolicy
import com.equipseva.app.core.data.location.RegionCatalogSource
import com.equipseva.app.core.data.location.RegionCatalogStatus
import com.equipseva.app.core.data.location.RegionRepository
import com.equipseva.app.core.data.location.RegionWriteError
import com.equipseva.app.core.data.location.ServiceDistrictsSaved
import com.equipseva.app.core.data.location.SyntheticRegions
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.FakeProfileRepository
import com.equipseva.app.testing.FakeRest
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Records home-region RPC calls; [homeResult] decides the answer. */
internal class FakeRegionRepository : RegionRepository {
    data class HomeCall(val stateCode: String, val districtCode: String, val version: String)

    val homeCalls = mutableListOf<HomeCall>()

    /** Defaults to the server mirroring the synthetic catalogue's current names. */
    var homeResult: (HomeCall) -> Result<HomeRegionSaved> = { c ->
        val catalog = SyntheticRegions.catalog
        Result.success(
            HomeRegionSaved(
                c.stateCode, catalog.state(c.stateCode)!!.name,
                c.districtCode, catalog.district(c.districtCode)!!.name, c.version, "resolved",
            ),
        )
    }
    var status: Result<RegionCatalogStatus> =
        Result.success(RegionCatalogStatus(currentVersion = "synthetic-v2", supportedVersions = listOf("synthetic-v2")))
    var statusCalls = 0

    override suspend fun catalogStatus(): Result<RegionCatalogStatus> { statusCalls++; return status }
    override suspend fun setMyHomeRegion(stateCode: String, districtCode: String, catalogVersion: String): Result<HomeRegionSaved> {
        val call = HomeCall(stateCode, districtCode, catalogVersion)
        homeCalls += call
        return homeResult(call)
    }
    override suspend fun setMyServiceDistricts(districtCodes: List<String>, catalogVersion: String): Result<ServiceDistrictsSaved> =
        error("not used by onboarding")
    override suspend fun myRegionProfile(): Result<MyRegionProfile> = Result.success(MyRegionProfile())
}

internal fun catalogSource(text: String?): RegionCatalogSource =
    RegionCatalogSource(RegionAssetReader { text }, RegionCatalogPolicy(allowSynthetic = true)) { throw AssertionError(it) }
        .apply { ioDispatcher = Dispatchers.Unconfined }

private fun refusal(code: String) = FakeRest.rest(400, """{"code":"22023","message":"$code"}""")

class OnboardingHomeRegionTest {
    @Test
    fun `without a bundled catalogue it is inert and keeps today's lists`() = runTest {
        val repo = FakeRegionRepository()
        val region = OnboardingHomeRegion(catalogSource(null), repo)
        assertNull(region.load())
        assertEquals(IndiaLocations.STATES, region.stateOptions())
        assertEquals(IndiaLocations.districtsFor("Telangana"), region.districtOptions("Telangana"))
        region.selectState("Telangana")
        assertEquals(OnboardingHomeRegion.Outcome.LegacyOnly, region.save())
        assertTrue(repo.homeCalls.isEmpty())
    }

    @Test
    fun `with a catalogue the names map to codes and the version is sent`() = runTest {
        val repo = FakeRegionRepository()
        val region = OnboardingHomeRegion(catalogSource(SyntheticRegions.json), repo)
        region.load()
        assertEquals(listOf("Alpha State", "Beta Territory"), region.stateOptions())
        assertEquals(listOf("Lakeside East", "Lakeside West", "Northfield", "Riverton"), region.districtOptions("Alpha State"))
        region.selectState("Beta Territory")
        region.selectDistrict("Northfield")
        assertEquals(OnboardingHomeRegion.Outcome.Saved("Beta Territory", "Northfield"), region.save())
        assertEquals(listOf(FakeRegionRepository.HomeCall("902", "90201", "synthetic-v2")), repo.homeCalls)
    }

    @Test
    fun `the server's current names come back with the save`() = runTest {
        val repo = FakeRegionRepository().apply {
            homeResult = { c -> Result.success(HomeRegionSaved(c.stateCode, "Alpha State", c.districtCode, "Riverton Nagar", c.version, "resolved")) }
        }
        val region = OnboardingHomeRegion(catalogSource(SyntheticRegions.json), repo)
        region.load()
        region.selectState("Alpha State")
        region.selectDistrict("Riverton")
        assertEquals(OnboardingHomeRegion.Outcome.Saved("Alpha State", "Riverton Nagar"), region.save())
    }

    @Test
    fun `a refusal falls back to labels only when the bundled catalogue is behind the server's`() = runTest {
        suspend fun outcome(serverCurrent: String?): OnboardingHomeRegion.Outcome {
            val repo = FakeRegionRepository().apply {
                homeResult = { Result.failure(refusal("region_district_retired")) }
                status = Result.success(RegionCatalogStatus(currentVersion = serverCurrent))
            }
            val region = OnboardingHomeRegion(catalogSource(SyntheticRegions.json), repo)
            region.load()
            region.selectState("Alpha State")
            region.selectDistrict("Riverton")
            return region.save()
        }
        assertEquals(OnboardingHomeRegion.Outcome.LegacyOnly, outcome("synthetic-v3"))
        assertEquals(OnboardingHomeRegion.Outcome.Refused(RegionWriteError.DistrictRetired), outcome("synthetic-v2"))
        assertEquals(OnboardingHomeRegion.Outcome.Refused(RegionWriteError.DistrictRetired), outcome(null))
    }

    @Test
    fun `changing the State or UT clears the district, so an incomplete pick is refused without a call`() = runTest {
        val repo = FakeRegionRepository()
        val region = OnboardingHomeRegion(catalogSource(SyntheticRegions.json), repo)
        region.load()
        region.selectState("Alpha State")
        region.selectDistrict("Northfield")
        region.selectState("Beta Territory")
        assertEquals(OnboardingHomeRegion.Outcome.Refused(RegionWriteError.PairInvalid), region.save())
        assertTrue(repo.homeCalls.isEmpty())
    }

    @Test
    fun `server answers map to refused, legacy-only or failed`() = runTest {
        suspend fun outcomeFor(error: Throwable): OnboardingHomeRegion.Outcome {
            val repo = FakeRegionRepository().apply { homeResult = { Result.failure(error) } }
            val region = OnboardingHomeRegion(catalogSource(SyntheticRegions.json), repo)
            region.load()
            region.selectState("Alpha State")
            region.selectDistrict("Riverton")
            return region.save()
        }
        assertEquals(OnboardingHomeRegion.Outcome.Refused(RegionWriteError.PairInvalid), outcomeFor(refusal("region_pair_invalid")))
        assertEquals(OnboardingHomeRegion.Outcome.Refused(RegionWriteError.CodeUnknown), outcomeFor(refusal("region_code_unknown")))
        assertEquals(OnboardingHomeRegion.Outcome.Refused(RegionWriteError.DistrictRetired), outcomeFor(refusal("region_district_retired")))
        assertEquals(OnboardingHomeRegion.Outcome.LegacyOnly, outcomeFor(refusal("region_catalog_version_unsupported")))
        assertEquals(
            OnboardingHomeRegion.Outcome.LegacyOnly,
            outcomeFor(FakeRest.rest(404, """{"code":"PGRST202","message":"Could not find the function public.set_my_home_region"}""")),
        )
        val network = IOException("timeout")
        assertEquals(OnboardingHomeRegion.Outcome.Failed(network), outcomeFor(network))
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class OnboardingRegionSaveTest {
    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun teardown() { Dispatchers.resetMain() }

    private val auth = FakeAuthRepository(AuthSession.SignedIn(userId = "u1", email = null))
    private val profiles = FakeProfileRepository()
    private val regions = FakeRegionRepository()

    private fun hospital(catalog: String?) =
        HospitalOnboardingViewModel(auth, profiles, OnboardingHomeRegion(catalogSource(catalog), regions))

    private fun TestScope.effectsOf(vm: HospitalOnboardingViewModel): MutableList<HospitalOnboardingViewModel.Effect> {
        val seen = mutableListOf<HospitalOnboardingViewModel.Effect>()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { vm.effects.collect { seen += it } }
        return seen
    }

    private fun HospitalOnboardingViewModel.fill(state: String, district: String) {
        onPhoneChange("+919876543210")
        onStateChange(state)
        onDistrictChange(district)
    }

    @Test
    fun `without a catalogue the screen saves labels exactly as before`() = runTest {
        val vm = hospital(null)
        val effects = effectsOf(vm)
        assertEquals(IndiaLocations.STATES, vm.state.value.stateOptions)
        vm.fill("Telangana", IndiaLocations.districtsFor("Telangana").first())
        vm.onSubmit()
        assertTrue(regions.homeCalls.isEmpty())
        assertEquals("Telangana", profiles.updateBasicInfoCalls.single().state)
        assertTrue(HospitalOnboardingViewModel.Effect.Done in effects)
    }

    @Test
    fun `with a catalogue the codes are saved first, then the phone and labels`() = runTest {
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions == listOf("Alpha State", "Beta Territory") }
        val effects = effectsOf(vm)
        vm.fill("Alpha State", "Riverton")
        assertEquals(listOf("Lakeside East", "Lakeside West", "Northfield", "Riverton"), vm.state.value.districtOptions)
        vm.onSubmit()
        assertEquals(listOf(FakeRegionRepository.HomeCall("901", "90102", "synthetic-v2")), regions.homeCalls)
        val saved = profiles.updateBasicInfoCalls.single()
        assertEquals(listOf("+919876543210", "Alpha State", "Riverton"), listOf(saved.phone, saved.state, saved.district))
        assertTrue(HospitalOnboardingViewModel.Effect.Done in effects)
    }

    @Test
    fun `a refused pair shows the message, saves nothing and does not advance`() = runTest {
        regions.homeResult = { Result.failure(refusal("region_pair_invalid")) }
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions.size == 2 }
        val effects = effectsOf(vm)
        vm.fill("Beta Territory", "Hillcrest")
        vm.onSubmit()
        assertEquals(OnboardingHomeRegion.REFUSED_MESSAGE, vm.state.value.error)
        assertFalse(vm.state.value.saving)
        assertTrue(profiles.updateBasicInfoCalls.isEmpty())
        assertFalse(HospitalOnboardingViewModel.Effect.Done in effects)
        // The picks stay on screen to correct.
        assertEquals("Hillcrest", vm.state.value.district)
    }

    @Test
    fun `a server without the RPC or the version still completes onboarding with labels`() = runTest {
        regions.homeResult = { Result.failure(refusal("region_catalog_version_unsupported")) }
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions.size == 2 }
        val effects = effectsOf(vm)
        vm.fill("Alpha State", "Northfield")
        vm.onSubmit()
        assertEquals(1, regions.homeCalls.size)
        assertEquals("Northfield", profiles.updateBasicInfoCalls.single().district)
        assertTrue(HospitalOnboardingViewModel.Effect.Done in effects)
    }

    @Test
    fun `the label save reuses the names the server mirrored, not the bundled ones`() = runTest {
        regions.homeResult = { c -> Result.success(HomeRegionSaved(c.stateCode, "Alpha State", c.districtCode, "Riverton Nagar", c.version, "resolved")) }
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions.size == 2 }
        vm.fill("Alpha State", "Riverton")
        vm.onSubmit()
        val saved = profiles.updateBasicInfoCalls.single()
        assertEquals(listOf("Alpha State", "Riverton Nagar"), listOf(saved.state, saved.district))
    }

    @Test
    fun `a server without the RPC completes onboarding with the picked labels`() = runTest {
        regions.homeResult = { Result.failure(FakeRest.rest(404, """{"code":"PGRST202","message":"Could not find the function public.set_my_home_region"}""")) }
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions.size == 2 }
        val effects = effectsOf(vm)
        vm.fill("Beta Territory", "Hillcrest")
        vm.onSubmit()
        assertEquals("Hillcrest", profiles.updateBasicInfoCalls.single().district)
        assertTrue(HospitalOnboardingViewModel.Effect.Done in effects)
    }

    @Test
    fun `a pick made before the catalogue loaded is kept only if the catalogue has the same names`() = runTest {
        fun delayedSource() = RegionCatalogSource(RegionAssetReader { SyntheticRegions.json }, RegionCatalogPolicy(allowSynthetic = true)) { throw AssertionError(it) }
            .apply { ioDispatcher = StandardTestDispatcher(testScheduler) }

        val kept = HospitalOnboardingViewModel(auth, profiles, OnboardingHomeRegion(delayedSource(), regions))
        assertEquals(IndiaLocations.STATES, kept.state.value.stateOptions)
        kept.onStateChange("Alpha State")
        kept.onDistrictChange("Riverton")
        advanceUntilIdle()
        assertEquals(listOf("Alpha State", "Beta Territory"), kept.state.value.stateOptions)
        assertEquals(listOf("Alpha State", "Riverton"), listOf(kept.state.value.state, kept.state.value.district))
        kept.onPhoneChange("+919876543210")
        kept.onSubmit()
        assertEquals(FakeRegionRepository.HomeCall("901", "90102", "synthetic-v2"), regions.homeCalls.last())

        val cleared = HospitalOnboardingViewModel(auth, profiles, OnboardingHomeRegion(delayedSource(), regions))
        cleared.onStateChange("Telangana")
        cleared.onDistrictChange(IndiaLocations.districtsFor("Telangana").first())
        advanceUntilIdle()
        assertEquals(listOf("", ""), listOf(cleared.state.value.state, cleared.state.value.district))
        assertFalse(cleared.state.value.canSubmit)
    }

    @Test
    fun `a network failure keeps the user on the screen with nothing saved`() = runTest {
        regions.homeResult = { Result.failure(IOException("Unable to resolve host")) }
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions.size == 2 }
        val effects = effectsOf(vm)
        vm.fill("Alpha State", "Northfield")
        vm.onSubmit()
        assertTrue(vm.state.value.error != null)
        assertTrue(profiles.updateBasicInfoCalls.isEmpty())
        assertFalse(HospitalOnboardingViewModel.Effect.Done in effects)
    }

    @Test
    fun `changing the State or UT clears the district`() = runTest {
        val vm = hospital(SyntheticRegions.json)
        vm.state.first { it.stateOptions.size == 2 }
        vm.fill("Alpha State", "Northfield")
        vm.onStateChange("Beta Territory")
        assertEquals("", vm.state.value.district)
        assertEquals(listOf("Hillcrest", "Northfield"), vm.state.value.districtOptions)
        assertFalse(vm.state.value.canSubmit)
    }

    @Test
    fun `the engineer screen saves codes the same way`() = runTest {
        val vm = EngineerOnboardingViewModel(auth, profiles, OnboardingHomeRegion(catalogSource(SyntheticRegions.json), regions))
        vm.state.first { it.stateOptions.size == 2 }
        vm.onPhoneChange("+919876543210")
        vm.onStateChange("Beta Territory")
        vm.onDistrictChange("Hillcrest")
        vm.onSubmit()
        assertEquals(listOf(FakeRegionRepository.HomeCall("902", "90202", "synthetic-v2")), regions.homeCalls)
        assertEquals("Hillcrest", profiles.updateBasicInfoCalls.single().district)
    }
}
