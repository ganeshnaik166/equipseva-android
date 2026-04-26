package com.medeq.app.data.repository

import android.net.Uri
import com.medeq.app.data.local.AppDatabase
import com.medeq.app.data.local.EquipmentEntity
import com.medeq.app.data.remote.OpenFdaApi
import com.medeq.app.data.remote.UdiResult
import com.medeq.app.domain.Equipment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext

/**
 * Local-first repository:
 *   1. Query Room (FTS5 over the bundled GUDID + curated DB).
 *   2. Emit those results immediately.
 *   3. If fewer than [LOCAL_FALLBACK_THRESHOLD] hits, hit OpenFDA in the background,
 *      cache rows we got back into Room (so subsequent searches are local), and emit
 *      the merged list.
 */
class EquipmentRepository(
    private val db: AppDatabase,
    private val openFda: OpenFdaApi,
    private val openFdaApiKey: String? = null,
) {

    private val dao = db.equipment()

    fun search(query: String, limit: Int = 50): Flow<SearchState> = flow {
        val trimmed = query.trim()
        if (trimmed.length < 2) {
            emit(SearchState.Idle)
            return@flow
        }

        emit(SearchState.Loading)

        val ftsQuery = AppDatabase.toFtsQuery(trimmed)
        val local = if (ftsQuery.isNotEmpty()) dao.search(ftsQuery, limit) else emptyList()
        emit(
            SearchState.Results(
                items = local.map { it.toDomain() },
                source = ResultSource.LOCAL,
                exhaustedLocal = false,
            )
        )

        if (local.size >= LOCAL_FALLBACK_THRESHOLD) return@flow

        // Local didn't satisfy — try OpenFDA
        val remote: List<UdiResult> = try {
            openFda.searchUdi(
                search = openFdaSearchExpr(trimmed),
                limit = limit,
                apiKey = openFdaApiKey,
            ).results
        } catch (t: Throwable) {
            emit(
                SearchState.Results(
                    items = local.map { it.toDomain() },
                    source = ResultSource.LOCAL,
                    exhaustedLocal = true,
                    remoteError = t.message,
                )
            )
            return@flow
        }

        val cached = remote.mapNotNull { it.toEntity() }
        if (cached.isNotEmpty()) dao.upsertAll(cached)

        // Re-query Room so the merged list comes from a single source of truth.
        val merged = dao.search(ftsQuery, limit)
        emit(
            SearchState.Results(
                items = merged.map { it.toDomain() },
                source = ResultSource.LOCAL_AND_REMOTE,
                exhaustedLocal = true,
            )
        )
    }.flowOn(Dispatchers.IO)

    suspend fun get(id: Long): Equipment? = withContext(Dispatchers.IO) {
        dao.byId(id)?.toDomain()
    }

    suspend fun byCategory(category: String, limit: Int = 100): List<Equipment> =
        withContext(Dispatchers.IO) {
            dao.byCategory(category, limit).map { it.toDomain() }
        }

    fun categories(): Flow<List<String>> = dao.categories()

    suspend fun stats() = withContext(Dispatchers.IO) {
        Stats(
            total    = dao.count(),
            curated  = dao.countBySource("curated"),
            gudid    = dao.countBySource("gudid"),
            remote   = dao.countBySource("remote"),
        )
    }

    // -------- mappers --------

    private fun UdiResult.toEntity(): EquipmentEntity? {
        val brand = brandName ?: companyName ?: return null
        val item = deviceDescription ?: brandName ?: return null
        val model = versionOrModelNumber ?: catalogNumber
        val gmdn = gmdnTerms.firstOrNull()?.name.orEmpty()
        val udi = identifiers.firstOrNull { it.type.equals("Primary", ignoreCase = true) }?.id
            ?: identifiers.firstOrNull()?.id

        // Use the same coarse mapping as the Python pipeline so categorisation
        // is consistent whether a row was bulk-imported or live-fetched.
        val category = mapCategory(gmdn, brand, item)
        val type = when {
            isOtc == true -> "Consumable"
            gmdn.contains("single-use", true) || gmdn.contains("disposable", true) -> "Consumable"
            gmdn.contains("accessory", true) || gmdn.contains("cable", true) ||
                gmdn.contains("battery", true) || gmdn.contains("filter", true) -> "Spare/Accessory"
            else -> "Capital Equipment"
        }
        val specs = listOfNotNull(
            gmdn.takeIf { it.isNotBlank() },
            mriSafety?.takeIf { it.isNotBlank() }?.let { "MRI: $it" },
        ).joinToString(" · ")

        return EquipmentEntity(
            id = (udi ?: "$brand:$item").hashCode().toLong() and 0xFFFFFFFF, // pseudo-unique
            source = "remote",
            udi = udi,
            itemName = item,
            brand = brand,
            model = model,
            category = category,
            subCategory = gmdn.ifBlank { null },
            type = type,
            specifications = specs.ifBlank { null },
            priceInrLow = null,
            priceInrHigh = null,
            market = "Global",
            imageSearchUrl = imageSearchUrl(brand, model, item),
            notes = devicePublishDate?.let { "Published $it" },
        )
    }

    private fun openFdaSearchExpr(q: String): String {
        // Match brand_name OR device_description OR company_name (all OR'd, AND-tokenised).
        val terms = q.split(Regex("\\s+")).filter { it.isNotBlank() }
        return terms.joinToString(" AND ") { t ->
            "(brand_name:$t OR device_description:$t OR company_name:$t)"
        }
    }

    private fun imageSearchUrl(brand: String?, model: String?, item: String?): String {
        val q = listOfNotNull(brand, model, item).joinToString(" ").trim()
        return "https://www.google.com/search?tbm=isch&q=" + Uri.encode(q)
    }

    private fun mapCategory(gmdn: String, brand: String, item: String): String {
        val blob = "$gmdn $brand $item".lowercase()
        for ((cat, kws) in CATEGORY_RULES) if (kws.any { blob.contains(it) }) return cat
        return "Spare Parts & Consumables"
    }

    // ---------- types ----------

    enum class ResultSource { LOCAL, LOCAL_AND_REMOTE, REMOTE_ONLY }

    sealed interface SearchState {
        data object Idle : SearchState
        data object Loading : SearchState
        data class Results(
            val items: List<Equipment>,
            val source: ResultSource,
            val exhaustedLocal: Boolean,
            val remoteError: String? = null,
        ) : SearchState
    }

    data class Stats(val total: Int, val curated: Int, val gudid: Int, val remote: Int)

    companion object {
        /**
         * If the local DB returns at least this many rows we don't bother going
         * to the network. Tune as you like.
         */
        private const val LOCAL_FALLBACK_THRESHOLD = 10

        // Keyword rules duplicated from build_sqlite.py to keep live-fetched
        // rows categorised the same way.
        private val CATEGORY_RULES = listOf(
            "Imaging" to listOf(
                "mri", "magnetic resonance", "ct ", "computed tomography", "x-ray", "xray",
                "radiograph", "fluoroscopy", "mammograph", "ultrasound", "echocardiograph",
                "doppler", "pet/ct", "spect", "gamma camera", "bone densitomet",
                "angiograph", "cath lab", "optical coherence", "fundus",
            ),
            "ICU & Critical Care" to listOf(
                "ventilator", "anaesthesi", "anesthesi", "respirator", "cpap", "bipap",
                "patient monitor", "multi-parameter", "pulse oxim", "defibrill",
                "infusion pump", "syringe pump", "dialysis", "hemodialysis",
                "ecmo", "iabp", "blood gas", "capnograph",
            ),
            "Surgical & OR" to listOf(
                "surgical", "operating", "anaesthetic gas", "electrosurg", "diathermy",
                "vessel sealing", "harmonic", "laparoscop", "endoscop", "gastroscop",
                "colonoscop", "bronchoscop", "cystoscop", "hysteroscop", "robotic",
                "phaco", "vitrectom", "drill", "saw", "stapler", "suture", "scalpel",
                "trocar", "autoclave", "steriliser", "sterilizer",
            ),
            "Laboratory" to listOf(
                "haematolog", "hematolog", "biochem", "chemistry analyz", "immunoassay",
                "elisa", "pcr", "thermocycler", "thermal cycler", "cytomet", "centrifug",
                "microscope", "microtome", "cryostat", "incubator", "biosafety",
                "fume hood", "spectrophotomet", "balance, analyt", "ph meter",
            ),
            "Ward & Allied" to listOf(
                "hospital bed", "wheelchair", "stretcher", "iv stand", "examination",
                "stethoscop", "sphygmomanomet", "blood pressure", "thermomet", "ecg ",
                "electrocardiograph", "spiromet", "nebuliz", "phototherap",
                "radiant warmer", "fetal", "ctg", "dental chair", "audiomet",
                "tympanomet", "slit lamp", "tonomet",
            ),
            "Spare Parts & Consumables" to listOf(
                "sensor", "probe", "cable", "cuff", "lead wire", "electrode", "circuit",
                "filter", "accessory", "battery", "lamp", "transducer", "needle",
                "catheter", "cannula", "drape", "gown", "mask", "glove",
            ),
        )
    }
}
