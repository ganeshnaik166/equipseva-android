package com.equipseva.app.testing

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import java.io.File

/**
 * Typed, read-once view over `supabase/tests/android_evidence_contract.json`,
 * the cross-layer fixture shared by the Kotlin INT-03/INT-04 tests and the
 * Node half (`supabase/tests/evidence_client_contract.test.mjs`). Every
 * regex, literal and expected value is READ from that file at runtime; a
 * test that needs one of these values must take it from here rather than
 * retype it, so the two layers cannot silently drift apart.
 *
 * Missing keys fail loudly with the fixture path in the message (an
 * `AssertionError`, so the failing test names the missing key instead of
 * an NPE). Keys another contributor may still be adding are read
 * defensively: `rules.prefixes` falls back to before/after, a variant's
 * `sqlstate` / `literal` / `sqlstate_key` may be absent, and the variant
 * count is never assumed.
 *
 * Root resolution: Gradle runs `:app` unit tests with cwd = `app/`, Android
 * Studio uses the repo root; walk up until a directory holds BOTH the
 * fixture and `settings.gradle.kts` (cf. TaxonomyDriftGuardTest /
 * StringsParityTest).
 */
internal class ContractFixture private constructor(root: JsonObject) {

    /** `rules` — the server-side shape the client must conform to. */
    class Rules internal constructor(rules: JsonObject) {
        val bucket = rules.str("bucket")
        val segmentCount = rules.int("segment_count")
        val uuidRegex = Regex(rules.str("uuid_regex"))
        val filenameRegex = Regex(rules.str("filename_regex"))
        val filenameForbidden = rules.strings("filename_forbidden")
        val storageUrlRegex = Regex(rules.str("storage_url_regex"))
        val clientStoredNameRegex = Regex(rules.str("client_stored_name_regex"))
        val sha256Regex = Regex(rules.str("content_sha256_regex"))
        val sizeMin = rules.int("content_size_min")
        val evidenceKinds = rules.strings("evidence_kinds")
        val sourceKind = rules.str("source_kind")
        val producerKind = rules.str("producer_kind")
        val metadataKeys = rules.strings("metadata_keys")
        val metadataCapturedFrom = rules.str("metadata_captured_from")
        val metadataClient = rules.str("metadata_client")
        val platformVersionRegex = Regex(rules.str("platform_version_regex"))

        /** `rules.prefixes` when present; the client's two literal prefixes otherwise. */
        val prefixes: List<String> = if (rules.containsKey("prefixes")) rules.strings("prefixes") else listOf("before", "after")

        /** RAISE literal (or `sqlstate_key`) → SQLSTATE, as the server declares them. */
        val serverSqlstates: Map<String, String> = rules.obj("server_sqlstates").mapValues { (_, v) -> v.jsonPrimitive.content }

        private val sanitizer = rules.obj("sanitizer")
        val sanitizerTake = sanitizer.int("take")
        val sanitizerReplaceRegex = Regex(sanitizer.str("replace_regex"))
        val sanitizerReplacement = sanitizer.str("replacement")
    }

    /** `identities` — synthetic ids of `supabase/tests/evidence_authorization.fixture.sql`. */
    class Identities internal constructor(identities: JsonObject) {
        val engineerUid = identities.str("engineer_uid")
        val hospitalUid = identities.str("hospital_uid")
        val jobId = identities.str("job_id")
    }

    /** `conforming_example` / `after_example` — one worked receipt per client kind. */
    class Example internal constructor(example: JsonObject) {
        val storageUrl = example.str("storage_url")
        val objectPath = example.str("object_path")
        val evidenceKind = example.str("evidence_kind")
        val attachToColumn = example.str("attach_to_column")
        val sourceKind = example.str("source_kind")
        val producerKind = example.str("producer_kind")
        val contentSha256 = example.str("content_sha256")
        val contentSizeBytes = example.req("content_size_bytes").jsonPrimitive.long
        val capturedAt = example.str("captured_at")
        val platformVersion = example.str("platform_version")
        val metadata: Map<String, String> = example.obj("metadata").mapValues { (_, v) -> v.jsonPrimitive.content }

        /** Last segment of [objectPath]: `<prefix>-<millis>-<uuid>-<sanitized40>`. */
        val storedName: String = objectPath.substringAfterLast('/')

        /** The `<prefix>` the example's stored name starts with (read, not retyped). */
        val storedNamePrefix: String = storedName.substringBefore('-')
    }

    /** `kotlin` — the bytes and constants the Kotlin side feeds through the real code. */
    class KotlinBlock internal constructor(block: JsonObject) {
        val photoBytes: ByteArray = block.req("photo_bytes").jsonArray.map { it.jsonPrimitive.int.toByte() }.toByteArray()
        val contentSha256 = block.str("content_sha256")
        val contentSizeBytes = block.req("content_size_bytes").jsonPrimitive.long
        val beforeContext = block.str("before_context")
        val afterContext = block.str("after_context")
        val capturedFrom = block.str("captured_from")
    }

    /** One `sanitizer_table` row. */
    data class SanitizerRow(val input: String, val expected: String, val why: String?)

    /** One migration's verdict on a variant (`r492` / `r3821`). */
    class Verdict internal constructor(verdict: JsonObject) {
        val outcome = verdict.str("outcome")
        val sqlstate: String? = verdict.optStr("sqlstate")
        val literal: String? = verdict.optStr("literal")
        val sqlstateKey: String? = verdict.optStr("sqlstate_key")
    }

    /** One `non_conforming_variants.variants` entry: exactly one mutated property of `conforming_example`. */
    class Variant internal constructor(variant: JsonObject) {
        val id = variant.str("id")
        val description: String? = variant.optStr("description")
        val mutation: Map<String, String> = variant.obj("mutation").mapValues { (_, v) -> v.jsonPrimitive.content }
        val r492 = Verdict(variant.obj("r492"))
        val r3821 = Verdict(variant.obj("r3821"))
        val discriminating: Boolean = variant["discriminating"]?.jsonPrimitive?.content?.toBooleanStrictOrNull() ?: false
    }

    val rules = Rules(root.obj("rules"))
    val identities = Identities(root.obj("identities"))
    val conformingExample = Example(root.obj("conforming_example"))
    val afterExample = Example(root.obj("after_example"))
    val kotlinBlock = KotlinBlock(root.obj("kotlin"))

    val sanitizerTable: List<SanitizerRow> = root.req("sanitizer_table").jsonArray
        .map { it.jsonObject }
        .map { SanitizerRow(input = it.str("input"), expected = it.str("expected"), why = it.optStr("why")) }

    val nonConformingVariants: List<Variant> = root.obj("non_conforming_variants").req("variants").jsonArray
        .map { Variant(it.jsonObject) }

    /** (variant id, mutated storage_url) for every variant whose mutation touches `storage_url`. */
    val nonConformingUrls: List<Pair<String, String>> =
        nonConformingVariants.mapNotNull { v -> v.mutation["storage_url"]?.let { url -> v.id to url } }

    val platformVersionExamplesAccepted: List<String> = root.strings("platform_version_examples_accepted")
    val notProvenHere: List<String> = root.strings("not_proven_here")

    fun variant(id: String): Variant? = nonConformingVariants.firstOrNull { it.id == id }

    companion object {
        const val FIXTURE_REL = "supabase/tests/android_evidence_contract.json"
        const val ROOT_MARKER = "settings.gradle.kts"

        /** Parsed once per JVM; every test class shares the same read. */
        val instance: ContractFixture by lazy { load() }

        fun load(): ContractFixture {
            val start = File(System.getProperty("user.dir") ?: ".").absoluteFile
            val tried = mutableListOf<String>()
            var dir: File? = start
            while (dir != null) {
                tried += dir.path
                if (File(dir, ROOT_MARKER).isFile && File(dir, FIXTURE_REL).isFile) {
                    val file = File(dir, FIXTURE_REL)
                    return ContractFixture(Json.parseToJsonElement(file.readText()).jsonObject)
                }
                dir = dir.parentFile
            }
            throw AssertionError(
                "Could not locate $FIXTURE_REL beside $ROOT_MARKER walking up from $start (tried $tried) — " +
                    "fix the test root resolution; do NOT delete the contract tests.",
            )
        }

        private fun JsonObject.req(key: String) = this[key] ?: throw AssertionError("fixture key '$key' is missing from $FIXTURE_REL")
        private fun JsonObject.obj(key: String) = req(key).jsonObject
        private fun JsonObject.str(key: String) = req(key).jsonPrimitive.content
        private fun JsonObject.optStr(key: String): String? = this[key]?.jsonPrimitive?.content
        private fun JsonObject.int(key: String) = req(key).jsonPrimitive.int
        private fun JsonObject.strings(key: String) = req(key).jsonArray.map { it.jsonPrimitive.content }
    }
}
