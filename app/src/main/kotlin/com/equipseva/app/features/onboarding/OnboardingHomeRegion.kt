package com.equipseva.app.features.onboarding

import com.equipseva.app.core.data.location.IndiaLocations
import com.equipseva.app.core.data.location.RegionCatalog
import com.equipseva.app.core.data.location.RegionCatalogSource
import com.equipseva.app.core.data.location.RegionRepository
import com.equipseva.app.core.data.location.RegionSelectionDraft
import com.equipseva.app.core.data.location.RegionWriteError
import javax.inject.Inject

/**
 * Region side of the onboarding screens (PRODUCT_PLAN §6, WP25.T01 sub-slice D1). One instance
 * per ViewModel.
 *
 * Without a bundled region catalogue (the state until an owner-approved LGD snapshot ships)
 * it is inert: the options are the existing [IndiaLocations] lists and [save] reports
 * [Outcome.LegacyOnly], so the screen keeps its label-only save exactly as before.
 *
 * With a catalogue, the options are its State/UT and district names, the choice is kept as
 * codes in a [RegionSelectionDraft], and [save] sends the codes (`set_my_home_region`, which
 * also writes the name labels) before the screen's existing phone/label save:
 *  - accepted → [Outcome.Saved] with the server's current names, which the screen then saves as
 *    its labels (an older bundled catalogue may still use a district's previous name);
 *  - a wrong pair, unknown or retired code → [Outcome.Refused] (nothing is saved; choose again),
 *    unless the bundled catalogue is older than the server's current one: then the device list
 *    itself is out of date, so the screen falls back to [Outcome.LegacyOnly] instead of trapping
 *    the user;
 *  - a server that does not accept this catalogue version yet, or does not have the RPC yet →
 *    [Outcome.LegacyOnly], so nobody is blocked by a release-order gap;
 *  - anything else (network, server) → [Outcome.Failed].
 */
class OnboardingHomeRegion @Inject constructor(
    private val catalogSource: RegionCatalogSource,
    private val regionRepository: RegionRepository,
) {
    sealed interface Outcome {
        data class Saved(val stateName: String, val districtName: String) : Outcome
        data object LegacyOnly : Outcome
        data class Refused(val error: RegionWriteError) : Outcome
        data class Failed(val error: Throwable) : Outcome
    }

    var catalog: RegionCatalog? = null
        private set
    private var draft: RegionSelectionDraft? = null

    /** Loads the bundled catalogue once; null means the label-only flow stays in use. */
    suspend fun load(): RegionCatalog? {
        val c = catalogSource.catalog()
        catalog = c
        draft = c?.let(RegionSelectionDraft::empty)
        return c
    }

    fun stateOptions(): List<String> = catalog?.states?.map { it.name } ?: IndiaLocations.STATES

    fun districtOptions(stateName: String): List<String> {
        val c = catalog ?: return IndiaLocations.districtsFor(stateName)
        return c.districtsOf(stateCode(c, stateName)).map { it.name }
    }

    /** Records the picked State/UT name; a different State/UT clears the district. */
    fun selectState(stateName: String) {
        val c = catalog ?: return
        draft = draft?.selectState(stateCode(c, stateName))
    }

    /** Records the picked district name inside the already-picked State/UT. */
    fun selectDistrict(districtName: String) {
        val c = catalog ?: return
        val d = draft ?: return
        val code = c.districtsOf(d.stateCode).firstOrNull { it.name == districtName }?.code
        draft = d.selectDistrict(code)
    }

    suspend fun save(): Outcome {
        val c = catalog ?: return Outcome.LegacyOnly
        val d = draft?.takeIf { it.isComplete } ?: return Outcome.Refused(RegionWriteError.PairInvalid)
        return regionRepository.setMyHomeRegion(d.stateCode!!, d.districtCode!!, c.version).fold(
            onSuccess = { Outcome.Saved(it.stateName, it.districtName) },
            onFailure = { e ->
                when (val refusal = RegionWriteError.from(e)) {
                    RegionWriteError.CatalogVersionUnsupported -> Outcome.LegacyOnly
                    RegionWriteError.PairInvalid,
                    RegionWriteError.CodeUnknown,
                    RegionWriteError.DistrictRetired ->
                        if (bundledCatalogIsBehind(c)) Outcome.LegacyOnly else Outcome.Refused(refusal)
                    else -> if (isMissingRpc(e)) Outcome.LegacyOnly else Outcome.Failed(e)
                }
            },
        )
    }

    /** True only when the server reports a different current catalogue than the bundled one. */
    private suspend fun bundledCatalogIsBehind(c: RegionCatalog): Boolean =
        regionRepository.catalogStatus().getOrNull()?.currentVersion?.let { it != c.version } ?: false

    private fun stateCode(c: RegionCatalog, stateName: String): String? =
        c.states.firstOrNull { it.name == stateName }?.code

    companion object {
        /** Shown when the server refuses the chosen codes; nothing was saved. */
        const val REFUSED_MESSAGE = "That State/UT and district could not be saved. Please choose them again."

        /** PostgREST reports a function it does not know (migration not applied yet) as PGRST202. */
        internal fun isMissingRpc(error: Throwable): Boolean =
            generateSequence(error) { it.cause }.take(8).any { it.message.orEmpty().contains("PGRST202") }
    }
}
