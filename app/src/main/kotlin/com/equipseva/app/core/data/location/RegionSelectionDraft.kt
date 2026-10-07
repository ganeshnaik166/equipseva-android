package com.equipseva.app.core.data.location

/**
 * An in-progress State/UT + district choice, held as codes from one [RegionCatalog].
 *
 * Rules (PRODUCT_PLAN §6, PAGES_AND_WORKFLOWS §4):
 *  - choosing a different State/UT clears the district, even when a district with the same
 *    name exists in both;
 *  - a district is accepted only under its own, already-chosen State/UT;
 *  - [restore] validates saved codes exactly like a fresh choice, so unknown or retired codes
 *    never count as complete;
 *  - legacy free text that does not resolve exactly is kept, visible, as [needsConfirmation];
 *    it is never erased or guessed into a code.
 *
 * Immutable: every change returns a new draft.
 */
class RegionSelectionDraft private constructor(
    val catalog: RegionCatalog,
    val stateCode: String?,
    val districtCode: String?,
    /** Legacy label text kept for display until the user confirms codes. */
    val legacyStateLabel: String?,
    val legacyDistrictLabel: String?,
) {
    val state: RegionState? get() = catalog.state(stateCode)
    val district: RegionDistrict? get() = catalog.district(districtCode)?.takeIf { it.stateCode == stateCode }

    val isComplete: Boolean get() = state != null && district != null

    /** Legacy text exists that no exact code choice has replaced yet. */
    val needsConfirmation: Boolean
        get() = !isComplete &&
            (RegionCatalog.normalizeLabel(legacyStateLabel) != null || RegionCatalog.normalizeLabel(legacyDistrictLabel) != null)

    fun selectState(code: String?): RegionSelectionDraft {
        val next = catalog.state(code)?.code
        val keepDistrict = next != null && next == stateCode
        return copy(stateCode = next, districtCode = if (keepDistrict) districtCode else null)
    }

    fun selectDistrict(code: String?): RegionSelectionDraft {
        val d = catalog.district(code)
        return copy(districtCode = d?.takeIf { it.stateCode == stateCode }?.code)
    }

    private fun copy(stateCode: String? = this.stateCode, districtCode: String?) =
        RegionSelectionDraft(catalog, stateCode, districtCode, legacyStateLabel, legacyDistrictLabel)

    companion object {
        fun empty(catalog: RegionCatalog) = RegionSelectionDraft(catalog, null, null, null, null)

        /** Saved codes, validated as a fresh selection; [legacy*] labels are kept for display. */
        fun restore(
            catalog: RegionCatalog,
            stateCode: String?,
            districtCode: String?,
            legacyStateLabel: String? = null,
            legacyDistrictLabel: String? = null,
        ): RegionSelectionDraft =
            RegionSelectionDraft(catalog, null, null, legacyStateLabel, legacyDistrictLabel)
                .selectState(stateCode)
                .selectDistrict(districtCode)

        /**
         * Legacy free text (for example `profiles.state/district` written by an older app
         * version). Only an exact State/UT name, and an exact district name or alias inside
         * it, are turned into codes; anything else stays as visible text needing confirmation.
         */
        fun fromLegacy(catalog: RegionCatalog, stateLabel: String?, districtLabel: String?): RegionSelectionDraft {
            val state = catalog.resolveState(stateLabel)
            val match = state?.let { catalog.resolveDistrict(it.code, districtLabel) }
            val district = (match as? RegionMatch.Resolved)?.district
            return RegionSelectionDraft(catalog, state?.code, district?.code, stateLabel, districtLabel)
        }
    }
}
