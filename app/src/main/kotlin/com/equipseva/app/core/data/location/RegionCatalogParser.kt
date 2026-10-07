package com.equipseva.app.core.data.location

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Parses and validates a bundled region catalogue asset (format 1). The same rules as the
 * server tables apply (round3830 `region_*` constraints), so an asset that the server would
 * reject is never used on the device:
 *  - version `^[a-z0-9][a-z0-9._-]{2,63}$`; State/UT codes 1–3 digits, district codes 1–6 digits;
 *  - names 1–64 characters; State/UT names unique; active district names unique per State/UT;
 *  - every code unique; every active district's parent is an active State/UT;
 *  - aliases are stored normalised and point at an active district of the same State/UT;
 *  - retired districts' replacements are known codes.
 * Any violation throws [RegionCatalogFormatException]; nothing is repaired or skipped.
 */
object RegionCatalogParser {
    const val FORMAT = 1

    private val json = Json { ignoreUnknownKeys = false }
    private val VERSION = Regex("^[a-z0-9][a-z0-9._-]{2,63}$")
    private val STATE_CODE = Regex("^[0-9]{1,3}$")
    private val DISTRICT_CODE = Regex("^[0-9]{1,6}$")
    private val ALIAS_KINDS = setOf("official", "legacy_bundled", "renamed", "common_spelling")

    fun parse(text: String): RegionCatalog {
        val asset = try {
            json.decodeFromString(AssetDto.serializer(), text)
        } catch (e: IllegalArgumentException) {
            throw RegionCatalogFormatException("not a region catalogue asset: ${e.message}", e)
        }
        return validate(asset)
    }

    private fun validate(a: AssetDto): RegionCatalog {
        check(a.format == FORMAT) { "unsupported format ${a.format}" }
        check(VERSION.matches(a.version)) { "invalid version" }
        check(a.states.isNotEmpty() && a.districts.isNotEmpty()) { "empty catalogue" }

        val stateCodes = HashSet<String>()
        val stateNames = HashSet<String>()
        a.states.forEach { s ->
            check(STATE_CODE.matches(s.code)) { "invalid State/UT code ${s.code}" }
            checkName(s.name, "State/UT ${s.code}")
            check(s.kind == "state" || s.kind == "union_territory") { "invalid kind for ${s.code}" }
            check(stateCodes.add(s.code)) { "duplicate State/UT code ${s.code}" }
            check(stateNames.add(RegionCatalog.normalizeLabel(s.name)!!)) { "duplicate State/UT name ${s.name}" }
        }

        val allDistrictCodes = HashSet<String>()
        val activeNames = HashSet<Pair<String, String>>()
        a.districts.forEach { d ->
            check(DISTRICT_CODE.matches(d.code)) { "invalid district code ${d.code}" }
            checkName(d.name, "district ${d.code}")
            check(d.state in stateCodes) { "district ${d.code} has unknown State/UT ${d.state}" }
            check(allDistrictCodes.add(d.code)) { "duplicate district code ${d.code}" }
            check(activeNames.add(d.state to RegionCatalog.normalizeLabel(d.name)!!)) {
                "duplicate district name ${d.name} in ${d.state}"
            }
        }
        a.retiredDistricts.forEach { r ->
            check(DISTRICT_CODE.matches(r.code)) { "invalid retired district code ${r.code}" }
            checkName(r.name, "retired district ${r.code}")
            check(STATE_CODE.matches(r.state)) { "invalid State/UT code on retired district ${r.code}" }
            check(allDistrictCodes.add(r.code)) { "duplicate district code ${r.code}" }
        }
        a.retiredDistricts.forEach { r ->
            r.replacedBy.forEach { c -> check(c in allDistrictCodes && c != r.code) { "unknown replacement $c for ${r.code}" } }
        }

        val activeByCode = a.districts.associateBy { it.code }
        val aliasKeys = HashSet<Triple<String, String, String>>()
        a.aliases.forEach { al ->
            check(al.state in stateCodes) { "alias for unknown State/UT ${al.state}" }
            check(al.alias.length in 1..64 && RegionCatalog.normalizeLabel(al.alias) == al.alias) {
                "alias '${al.alias}' is not stored normalised"
            }
            check(al.kind in ALIAS_KINDS) { "invalid alias kind ${al.kind}" }
            val target = activeByCode[al.district]
            check(target != null && target.state == al.state) { "alias '${al.alias}' does not point at an active district of ${al.state}" }
            check(aliasKeys.add(Triple(al.state, al.alias, al.district))) { "duplicate alias '${al.alias}'" }
        }

        return RegionCatalog(
            version = a.version,
            isSynthetic = a.synthetic,
            states = a.states.map { RegionState(it.code, it.name, it.kind == "union_territory") },
            districts = a.districts.map { RegionDistrict(it.code, it.state, it.name) },
            retiredDistricts = a.retiredDistricts.map { RetiredDistrict(it.code, it.state, it.name, it.replacedBy) },
            aliases = a.aliases.map { RegionAlias(it.state, it.alias, it.district, it.kind) },
        )
    }

    private fun checkName(name: String, what: String) {
        check(name.length in 1..64 && name.isNotBlank() && name == name.trim()) { "invalid name for $what" }
    }

    private inline fun check(condition: Boolean, message: () -> String) {
        if (!condition) throw RegionCatalogFormatException(message())
    }

    @Serializable
    private data class AssetDto(
        val format: Int,
        val version: String,
        val synthetic: Boolean = false,
        val source: SourceDto,
        val states: List<StateDto>,
        val districts: List<DistrictDto>,
        @SerialName("retired_districts") val retiredDistricts: List<RetiredDto> = emptyList(),
        val aliases: List<AliasDto> = emptyList(),
    )

    @Serializable
    private data class SourceDto(
        val url: String,
        @SerialName("retrieved_on") val retrievedOn: String,
        val sha256: String,
    )

    @Serializable
    private data class StateDto(val code: String, val name: String, val kind: String)

    @Serializable
    private data class DistrictDto(val code: String, val state: String, val name: String)

    @Serializable
    private data class RetiredDto(
        val code: String,
        val state: String,
        val name: String,
        @SerialName("replaced_by") val replacedBy: List<String> = emptyList(),
    )

    @Serializable
    private data class AliasDto(val state: String, val alias: String, val district: String, val kind: String)
}

class RegionCatalogFormatException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)
