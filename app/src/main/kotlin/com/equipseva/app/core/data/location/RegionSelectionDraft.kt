package com.equipseva.app.core.data.location

/** Local draft of legacy bundled names, not verified location or official geographic authority. */
internal class RegionSelectionDraft private constructor(
    val state: String?,
    val district: String?,
) {
    /** A selected pair from the legacy bundled catalog only; not a verified address or location. */
    val isComplete: Boolean get() = state != null && district != null

    fun selectState(state: String?): RegionSelectionDraft {
        val selected = state?.takeIf { it in IndiaLocations.STATES }
        if (selected != null && selected == this.state) return this
        // A same-named district under another state still needs a fresh explicit selection.
        return RegionSelectionDraft(selected, null)
    }

    fun selectDistrict(district: String?): RegionSelectionDraft {
        val selectedState = state ?: return empty()
        val selectedDistrict = district?.takeIf { it in IndiaLocations.districtsFor(selectedState) }
        return RegionSelectionDraft(selectedState, selectedDistrict)
    }

    companion object {
        fun empty(): RegionSelectionDraft = RegionSelectionDraft(null, null)

        /** Restored drafts pass through the same exact parent/child validation as new selections. */
        fun restore(state: String?, district: String?): RegionSelectionDraft =
            empty().selectState(state).selectDistrict(district)
    }
}
