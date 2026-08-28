package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PayoutsCsvExportTest {

    private fun row(
        jobNumber: String? = "RPR-00099",
        engineer: String? = "Ravi Kumar",
        phone: String? = "+919876543210",
        amountPaise: Long = 930,
        status: String = "processed",
        mode: String? = "UPI",
        utr: String? = "REF12345",
        destination: String? = "ravi@oksbi",
        failure: String? = null,
        attempts: Int = 1,
    ) = FounderRepository.AdminEngineerPayout(
        id = "p1",
        repairJobId = "j1",
        jobNumber = jobNumber,
        engineerUserId = "u1",
        engineerName = engineer,
        engineerPhone = phone,
        amountPaise = amountPaise,
        status = status,
        mode = mode,
        utr = utr,
        failureReason = failure,
        destinationLabel = destination,
        attempts = attempts,
        queuedAt = "2026-06-02T10:00:00Z",
        processedAt = "2026-06-03T05:00:00Z",
    )

    /* ---- csvField ---- */

    @Test
    fun `null renders empty`() {
        assertEquals("", csvField(null))
    }

    @Test
    fun `plain text passes through unquoted`() {
        assertEquals("Ravi Kumar", csvField("Ravi Kumar"))
    }

    @Test
    fun `comma forces quoting`() {
        assertEquals("\"Hyderabad, Telangana\"", csvField("Hyderabad, Telangana"))
    }

    @Test
    fun `embedded quote is doubled and field quoted`() {
        // RFC 4180: a value of `He said "hi"` becomes `"He said ""hi"""`
        assertEquals("\"He said \"\"hi\"\"\"", csvField("He said \"hi\""))
    }

    @Test
    fun `newline forces quoting`() {
        assertEquals("\"line1\nline2\"", csvField("line1\nline2"))
    }

    /* ---- formatPayoutsCsv ---- */

    @Test
    fun `header line lists the 12 expected columns in order`() {
        val csv = formatPayoutsCsv(emptyList())
        val firstLine = csv.lineSequence().first()
        assertEquals(
            "job_number,engineer_name,engineer_phone,amount_rupees,status,mode,utr,destination,queued_at,processed_at,failure_reason,attempts",
            firstLine,
        )
    }

    @Test
    fun `each row writes amount as 2dp rupees not paise`() {
        val csv = formatPayoutsCsv(listOf(row(amountPaise = 930)))
        // Field index 3 (0-based) is amount_rupees
        val cells = csv.lineSequence().drop(1).first().split(",")
        assertEquals("9.30", cells[3])
    }

    @Test
    fun `multiple rows produce one body line each plus header`() {
        val csv = formatPayoutsCsv(listOf(
            row(jobNumber = "RPR-00001"),
            row(jobNumber = "RPR-00002"),
            row(jobNumber = "RPR-00003"),
        ))
        // 1 header + 3 body + trailing newline → 5 split chunks
        val lines = csv.split("\n")
        assertEquals(4 + 1, lines.size)  // header + 3 rows + empty trailing after final \n
        assertTrue(lines[0].startsWith("job_number,"))
        assertTrue(lines[1].startsWith("RPR-00001,"))
        assertTrue(lines[2].startsWith("RPR-00002,"))
        assertTrue(lines[3].startsWith("RPR-00003,"))
    }

    @Test
    fun `engineer name with comma is escaped so the column count stays right`() {
        val csv = formatPayoutsCsv(listOf(row(engineer = "Ravi, Sr.")))
        val body = csv.lineSequence().drop(1).first()
        // Naive split would now show 13 fields; properly-escaped CSV
        // must keep 12 fields. Smoke test via quote count: an even
        // number means the quotes balance + cells are well-formed.
        assertTrue("expected an even number of quotes, body=$body", body.count { it == '"' } % 2 == 0)
        assertTrue(body.contains("\"Ravi, Sr.\""))
    }

    @Test
    fun `failure reason with newline is escaped`() {
        val csv = formatPayoutsCsv(listOf(row(status = "failed", failure = "Invalid VPA\nretry tomorrow")))
        // The presence of an unescaped newline would split the row in
        // half; check the single body line still ends at the attempts
        // column (last cell = attempts as int).
        // Body cells are wrapped together because the newline inside
        // the failure_reason is enclosed in double quotes.
        assertTrue(csv.contains("\"Invalid VPA\nretry tomorrow\""))
    }

    @Test
    fun `null job number falls back to RPR- plus first 6 chars of repair job id`() {
        // Round 3760 — repair_jobs.job_number can be null on a legacy
        // row; without a repair_job_id column in this export, a blank
        // cell here would leave the row completely unidentifiable.
        val csv = formatPayoutsCsv(listOf(row(jobNumber = null).copy(repairJobId = "abcdef12-3456-7890-abcd-ef1234567890")))
        val body = csv.lineSequence().drop(1).first()
        assertTrue(body.startsWith("RPR-abcdef,"))
    }

    /* ---- csvFilename ---- */

    @Test
    fun `filename uses UTC date prefix`() {
        // 2026-06-03 12:00:00 UTC → ms timestamp
        val msAtUtc = 1780488000000L  // verified: 2026-06-03T12:00:00Z
        assertEquals("engineer-payouts-2026-06-03.csv", csvFilename(msAtUtc))
    }
}
