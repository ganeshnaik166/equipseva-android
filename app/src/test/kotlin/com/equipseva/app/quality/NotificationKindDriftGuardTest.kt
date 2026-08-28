package com.equipseva.app.quality

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Regression guard for push-kind drift (r1503; method proven manually in
 * r1502, which found FOUR server-emitted kinds the client dumped to the
 * generic inbox — including engineer_payout_failed, the highest-intent push
 * in the app).
 *
 * The server's notification triggers live in supabase/migrations (.sql) in
 * THIS repo, so a JVM test can diff them against the client's deep-link map:
 * every `kind` literal inserted into public.notifications must either be
 * mapped in NotificationDeepLink.kt or listed here as deliberately-inbox.
 *
 * When this fails: either add a KIND_* mapping in NotificationDeepLink.kt
 * (routing the push to its real surface), or — if the inbox genuinely is the
 * right destination, or the literal is a payload key the extractor
 * mis-caught — add it to [DELIBERATELY_UNMAPPED] / [NOT_KINDS] below with a
 * one-line reason. Do NOT delete the guard.
 */
class NotificationKindDriftGuardTest {

    /** Kinds we consciously leave on the inbox fallback. */
    private val DELIBERATELY_UNMAPPED = setOf(
        // Marketplace-era kinds; their surfaces were dropped in the v1
        // cleanup (see NotificationDeepLink KDoc).
        "rfq_bid_accepted",
        "order_shipped",
    )

    /**
     * Snake-case literals the block extractor catches that are NOT kinds —
     * payload-JSON keys/values sitting inside the same INSERT statement.
     */
    private val NOT_KINDS = setOf(
        "job_number", "reason", "repair_job_id", "flag_count", "processed",
        "released", "engineer_payout_", "cash_payment_flags", "payout_id",
        "engineer_payout_id", "amc_contract_id", "conversation_id",
        "engineer_id", "invitation_id", "escrow_id", "visit_id",
        "contract_id", "user_id", "old_engineer", "new_engineer",
        "bid_id", "end_date", "hospital_user_id", "old_rate", "order_id",
        "order_number", "revision_id", "rfq_bid_id", "rfq_id",
        "sender_user_id", "threshold", "tier", "verification_status",
    )

    @Test fun `every server-emitted notification kind is routed or deliberately inboxed`() {
        val repoRoot = findRepoRoot()
        assertTrue(
            "Could not locate supabase/migrations from ${File(".").absolutePath} — fix this " +
                "test's root resolution; do NOT delete the guard.",
            repoRoot != null,
        )
        val migrations = File(repoRoot!!, "supabase/migrations")
        val deepLink = File(repoRoot, "app/src/main/kotlin/com/equipseva/app/navigation/NotificationDeepLink.kt")
        assertTrue("NotificationDeepLink.kt moved — update this guard's path.", deepLink.isFile)

        // Client-mapped kinds: the const val KIND_* string literals.
        val mapped = Regex("""const val KIND_[A-Z_]+ = "([a-z_]+)"""")
            .findAll(deepLink.readText())
            .map { it.groupValues[1] }
            .toSet()
        assertTrue("Extractor found no KIND_ constants — regex rotted; fix, don't delete.", mapped.isNotEmpty())

        // Server-emitted kinds: snake_case literals inside the 8 lines
        // following each INSERT INTO public.notifications (the kind value
        // plus, unavoidably, payload keys — filtered via NOT_KINDS).
        val literal = Regex("""'([a-z_]{4,45})'""")
        val emitted = mutableSetOf<String>()
        migrations.walkTopDown()
            .filter { it.isFile && it.extension == "sql" }
            .forEach { file ->
                val lines = file.readLines()
                lines.forEachIndexed { i, line ->
                    if (!line.contains("INSERT INTO public.notifications")) return@forEachIndexed
                    (i..minOf(i + 8, lines.lastIndex)).forEach { j ->
                        literal.findAll(lines[j]).forEach { m -> emitted.add(m.groupValues[1]) }
                    }
                }
            }
        assertTrue("Extractor found no server kinds — heuristic rotted; fix, don't delete.", emitted.isNotEmpty())

        val unrouted = emitted - mapped - DELIBERATELY_UNMAPPED - NOT_KINDS
        assertTrue(
            "Server emits notification kind(s) the client doesn't route — pushes for these " +
                "dump to the generic inbox. Map them in NotificationDeepLink.kt, or add to " +
                "DELIBERATELY_UNMAPPED / NOT_KINDS with a reason:\n" +
                unrouted.sorted().joinToString("\n"),
            unrouted.isEmpty(),
        )
    }

    private fun findRepoRoot(): File? =
        listOf(".", "..", "../..")
            .map(::File)
            .firstOrNull { File(it, "supabase/migrations").isDirectory }
}
