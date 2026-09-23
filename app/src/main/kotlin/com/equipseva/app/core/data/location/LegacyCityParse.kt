package com.equipseva.app.core.data.location

/**
 * Result of reading a legacy free-text location string into catalog names.
 *
 * Where such strings come from (checked against the writers on 2026-09-23):
 *  - `engineers.city`, written by the KYC flow as `serviceAddress ?: serviceDistrict`.
 *    `serviceAddress` may be a "My location" composition — "line1, line2,
 *    landmark, city, district, state, pincode", any part absent — or the bare
 *    district the engineer picked; the State/UT then sits in the separate
 *    `engineers.state` column, which callers pass as `knownState`.
 *  - the one-day (2026-05-01) [IndiaLocations.compose] era, "Mandal, District,
 *    State", and hand-typed values such as "District, State" or "…, State, India".
 *
 * PRODUCT_PLAN §6: during the region migration a legacy value must remain
 * visible and "needs confirmation" rather than being silently erased or mapped
 * into an arbitrary district. So:
 *
 * - [state] / [district] / [mandal] are canonical catalog names when a token
 *   resolved through exact, normalized or explicit-alias matching; never through
 *   substring guessing. Address remnants (street, landmark, pincode, "India")
 *   stay visible in [unresolved] in their original order.
 * - [needsConfirmation] is true when the State/UT was inferred rather than
 *   stated (a lone district name that is unique nationwide), when the text and
 *   the `knownState` column disagree, when a lone district exists in several
 *   States ([stateCandidates] lists them; the parser picks none), when text was
 *   present but no district could be placed, or when the district was taken
 *   from an earlier locality token because the token in the writer's district
 *   slot could not be read ("…, Hyderabad, Unknown Label, Telangana" keeps
 *   Hyderabad only as a suggestion). Known remnants beside a resolved district
 *   — a six-digit pincode, "India" — do not, by themselves, set it.
 */
data class LegacyCityParse(
    val state: String?,
    val district: String?,
    val mandal: String?,
    val unresolved: List<String>,
    val stateCandidates: List<String>,
    val needsConfirmation: Boolean,
    /** True when [state] was worked out from a lone unique district rather than read from the text or the column. */
    val stateInferred: Boolean = false,
) {
    /** Nothing to read: blank input and no known State. Distinct from "read but unresolved". */
    val isEmpty: Boolean
        get() = state == null && district == null && mandal == null && unresolved.isEmpty()

    /** State/UT and district both resolved — the minimum a district-based flow needs. */
    val isComplete: Boolean
        get() = state != null && district != null

    companion object {
        val EMPTY = LegacyCityParse(
            state = null,
            district = null,
            mandal = null,
            unresolved = emptyList(),
            stateCandidates = emptyList(),
            needsConfirmation = false,
        )

        private val PINCODE = Regex("\\d{3}\\s?\\d{3}")
        private val COUNTRY = setOf("india", "bharat")

        /**
         * Tokens the writer's layout puts after the district — a six-digit
         * pincode (optionally written "500 034") or the country — carry no
         * district information, so they do not make a district reading
         * uncertain. Anything else to the right of the chosen district does.
         */
        internal fun isKnownRemnant(token: String): Boolean {
            val trimmed = token.trim()
            return PINCODE.matches(trimmed) || IndiaRegionAliases.normalize(trimmed) in COUNTRY
        }
    }
}

/**
 * Parse a legacy free-text location string back into catalog names.
 *
 * Reading order: the rightmost token that strictly resolves as a State/UT
 * (exact, normalized or aliased — the embedded-phrase Geocoder step is off) is
 * the State; anything to its right ("India", a pincode) is a remnant. Within the
 * tokens before it, the rightmost token that is a district of that State is the
 * district, and the token immediately before that may be a Telangana mandal.
 * If an unrecognised token sits between the chosen district and the State (or
 * the end of the text), the district is only a suggestion and confirmation is
 * required — the unrecognised token may be the real district under a label the
 * catalog does not know. Without any State — in the text or in [knownState] —
 * only a lone last token that is a nationally unique district may infer the
 * State, and that inference is flagged.
 *
 * @param knownState the row's separate State/UT column, if any. It scopes the
 *   district lookup when the text has no State token, and is reported as a
 *   candidate (with confirmation required) when the text names a different one.
 *   A value that does not resolve strictly is kept visible in [LegacyCityParse.unresolved].
 */
fun parseLegacyCity(raw: String?, knownState: String? = null): LegacyCityParse {
    val tokens = raw.orEmpty().split(',').map { it.trim() }.filter { it.isNotEmpty() }
    val columnRaw = knownState?.trim()?.takeIf { it.isNotEmpty() }
    val column = IndiaLocations.canonicalState(columnRaw, allowEmbedded = false)
    val columnUnresolved = columnRaw != null && column == null

    if (tokens.isEmpty()) {
        return when {
            column != null -> LegacyCityParse.EMPTY.copy(state = column)
            columnUnresolved -> LegacyCityParse.EMPTY.copy(unresolved = listOf(columnRaw!!), needsConfirmation = true)
            else -> LegacyCityParse.EMPTY
        }
    }

    val consumed = mutableSetOf<Int>()
    var stateCandidates: List<String> = emptyList()
    var inferred = false

    // 1. State/UT from the text: rightmost strictly-resolving token.
    val stateIdx = tokens.indices.lastOrNull { i ->
        IndiaLocations.canonicalState(tokens[i], allowEmbedded = false) != null
    }
    var state: String? = stateIdx?.let { IndiaLocations.canonicalState(tokens[it], allowEmbedded = false) }
    if (stateIdx != null) consumed += stateIdx
    val head = if (stateIdx != null) tokens.subList(0, stateIdx) else tokens

    // Text vs column disagreement: keep the text's reading, ask the user.
    if (state != null && column != null && state != column) {
        stateCandidates = listOf(state, column)
    }
    // A recorded column is not an inference.
    if (state == null && column != null) state = column

    // 2. District.
    var district: String? = null
    var districtIdx = -1
    if (state != null) {
        val scope = state
        districtIdx = head.indices.lastOrNull { i -> IndiaLocations.canonicalDistrict(scope, head[i]) != null } ?: -1
        if (districtIdx >= 0) district = IndiaLocations.canonicalDistrict(scope, head[districtIdx])
    } else if (head.isNotEmpty()) {
        // No State anywhere: only a lone, nationally unique district may infer one.
        val candidate = head.last()
        val homes = IndiaLocations.STATES.filter { IndiaLocations.canonicalDistrict(it, candidate) != null }
        when (homes.size) {
            1 -> {
                state = homes.single()
                district = IndiaLocations.canonicalDistrict(state, candidate)
                districtIdx = head.lastIndex
                inferred = true
            }
            0 -> Unit
            else -> stateCandidates = homes
        }
    }
    if (districtIdx >= 0) consumed += districtIdx

    // An unrecognised token between the chosen district and the State, or
    // anywhere after the State (the writers only ever put a pincode or the
    // country there), may be the real district under an unknown label; the
    // chosen district is then only a suggestion.
    val districtSlotUncertain = districtIdx >= 0 && (
        head.subList(districtIdx + 1, head.size).any { !LegacyCityParse.isKnownRemnant(it) } ||
            (stateIdx != null && tokens.subList(stateIdx + 1, tokens.size).any { !LegacyCityParse.isKnownRemnant(it) })
        )

    // 3. Mandal: only the token immediately before the district.
    var mandal: String? = null
    if (district != null && state != null && districtIdx > 0) {
        val key = IndiaRegionAliases.normalize(head[districtIdx - 1])
        mandal = IndiaLocations.mandalsFor(state, district).firstOrNull { IndiaRegionAliases.normalize(it) == key }
        if (mandal != null) consumed += districtIdx - 1
    }

    val unresolved = tokens.filterIndexed { i, _ -> i !in consumed } +
        (if (columnUnresolved) listOf(columnRaw!!) else emptyList())
    return LegacyCityParse(
        state = state,
        district = district,
        mandal = mandal,
        unresolved = unresolved,
        stateCandidates = stateCandidates,
        needsConfirmation = inferred ||
            stateCandidates.isNotEmpty() ||
            districtSlotUncertain ||
            columnUnresolved ||
            (district == null && unresolved.isNotEmpty()),
        stateInferred = inferred,
    )
}
