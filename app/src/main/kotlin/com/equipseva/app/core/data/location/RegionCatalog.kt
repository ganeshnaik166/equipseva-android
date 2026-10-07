package com.equipseva.app.core.data.location

import java.util.Locale

/**
 * Code-based India region catalogue (PRODUCT_PLAN §6, ledger P2.2): State/UT and district
 * records keyed by stable codes, plus the catalogue version they come from. Names are display
 * labels only; anything persisted is a code plus [version].
 *
 * Built and validated by [RegionCatalogParser]; immutable. Resolution of free text is
 * exact-only (case and whitespace are normalised exactly as the server's
 * `region_normalize_label` does) and never looks outside the given State/UT. [search] is a
 * picker filter for a user to choose from, never a resolution.
 */
class RegionCatalog internal constructor(
    val version: String,
    val isSynthetic: Boolean,
    states: List<RegionState>,
    districts: List<RegionDistrict>,
    retiredDistricts: List<RetiredDistrict>,
    aliases: List<RegionAlias>,
) {
    /** Active States/UTs, sorted by name. */
    val states: List<RegionState> = states.sortedBy { it.name.lowercase(Locale.ROOT) }

    private val stateByCode = states.associateBy { it.code }
    private val districtByCode = districts.associateBy { it.code }
    private val retiredByCode = retiredDistricts.associateBy { it.code }
    private val districtsByState: Map<String, List<RegionDistrict>> = districts
        .groupBy { it.stateCode }
        .mapValues { (_, list) -> list.sortedBy { it.name.lowercase(Locale.ROOT) } }
    private val stateByName: Map<String, RegionState> = states.associateBy { normalizeLabel(it.name)!! }
    private val districtCodesByStateAndLabel: Map<Pair<String, String>, Set<String>> = buildMap<Pair<String, String>, MutableSet<String>> {
        districts.forEach { d -> getOrPut(d.stateCode to normalizeLabel(d.name)!!) { mutableSetOf() } += d.code }
        aliases.forEach { a -> getOrPut(a.stateCode to a.alias) { mutableSetOf() } += a.districtCode }
    }

    val districtCount: Int get() = districtByCode.size

    /** Active State/UT with [code], or null. */
    fun state(code: String?): RegionState? = code?.let(stateByCode::get)

    /** Active district with [code], or null (retired and unknown codes return null). */
    fun district(code: String?): RegionDistrict? = code?.let(districtByCode::get)

    /** A district code that this catalogue knows was retired, with its replacements. */
    fun retiredDistrict(code: String?): RetiredDistrict? = code?.let(retiredByCode::get)

    /** Active districts of one State/UT, sorted by name; empty for an unknown code. */
    fun districtsOf(stateCode: String?): List<RegionDistrict> =
        stateCode?.let(districtsByState::get).orEmpty()

    /** The active State/UT whose name matches [label] exactly after normalisation. */
    fun resolveState(label: String?): RegionState? = normalizeLabel(label)?.let(stateByName::get)

    /**
     * Exact resolution of a district label inside one State/UT, by current name or alias.
     * A label that matches several districts is [RegionMatch.Ambiguous]; nothing is guessed.
     */
    fun resolveDistrict(stateCode: String?, label: String?): RegionMatch {
        val state = state(stateCode) ?: return RegionMatch.UnknownState
        val key = normalizeLabel(label) ?: return RegionMatch.NoMatch
        val codes = districtCodesByStateAndLabel[state.code to key].orEmpty()
        val candidates = codes.mapNotNull(districtByCode::get).filter { it.stateCode == state.code }
            .sortedBy { it.code }
        return when (candidates.size) {
            0 -> RegionMatch.NoMatch
            1 -> RegionMatch.Resolved(candidates.single())
            else -> RegionMatch.Ambiguous(candidates)
        }
    }

    /**
     * Picker filter: active districts of [stateCode] whose name starts with, or contains a word
     * starting with, [query]. A blank query returns every district of the State/UT.
     */
    fun search(stateCode: String?, query: String?): List<RegionDistrict> {
        val all = districtsOf(stateCode)
        val q = normalizeLabel(query) ?: return all
        return all.filter { d ->
            val name = normalizeLabel(d.name)!!
            name.startsWith(q) || name.split(' ').any { it.startsWith(q) }
        }
    }

    companion object {
        /** ASCII whitespace only, as on the server; Unicode spaces such as NBSP are kept. */
        private val WHITESPACE = Regex("[ \\t\\n\\r\\f\\x0B]+")

        /**
         * Mirrors the server's `region_normalize_label` exactly: lower case, runs of ASCII
         * whitespace (space, tab, newline, carriage return, form feed, vertical tab) collapsed to
         * one space and trimmed; null when nothing is left. Non-breaking and other Unicode spaces,
         * punctuation and abbreviations are kept, so "Hyderabad Dist." never equals "Hyderabad".
         * The explicit class also keeps Android's ICU regex (whose \s includes Unicode spaces)
         * from diverging.
         */
        fun normalizeLabel(raw: String?): String? =
            raw?.replace(WHITESPACE, " ")?.trim(' ')?.lowercase(Locale.ROOT)?.takeIf { it.isNotEmpty() }
    }
}

data class RegionState(val code: String, val name: String, val isUnionTerritory: Boolean)

data class RegionDistrict(val code: String, val stateCode: String, val name: String)

data class RetiredDistrict(
    val code: String,
    val stateCode: String,
    val name: String,
    val replacedBy: List<String>,
)

/** [alias] is stored normalised (see [RegionCatalog.normalizeLabel]). */
data class RegionAlias(val stateCode: String, val alias: String, val districtCode: String, val kind: String)

sealed interface RegionMatch {
    data class Resolved(val district: RegionDistrict) : RegionMatch
    data class Ambiguous(val candidates: List<RegionDistrict>) : RegionMatch
    data object NoMatch : RegionMatch
    data object UnknownState : RegionMatch
}
