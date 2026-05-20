package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The typing indicator runs entirely client-side over a Realtime broadcast.
 * Each incoming frame stamps a wall-clock millis into [lastSeen]; the
 * pruner drops anyone whose stamp aged past the TTL. A miss here means
 * the typing bubble stays on forever (no eviction) or never appears
 * (over-eager eviction).
 */
class TypingPruneTest {

    @Test fun `entries newer than the TTL are kept`() {
        val map = mutableMapOf("u1" to 9_000L, "u2" to 9_500L)
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = 3_000L)
        assertEquals(setOf("u1", "u2"), out)
        // Map itself wasn't mutated (no entries to drop).
        assertEquals(2, map.size)
    }

    @Test fun `entries older than the TTL are dropped and removed in place`() {
        val map = mutableMapOf("stale" to 5_000L, "fresh" to 9_500L)
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = 3_000L)
        assertEquals(setOf("fresh"), out)
        // The function mutates in place — the next call must see the smaller map.
        assertEquals(setOf("fresh"), map.keys)
    }

    @Test fun `exactly TTL boundary stays in the set (gt comparison)`() {
        // Documented contract: drop fires only when `now - ts > ttlMs`,
        // so an entry whose age is exactly == ttl survives. Pin that
        // so a refactor doesn't flip the inequality and silently
        // bounce typists in and out at the boundary.
        val map = mutableMapOf("edge" to 7_000L)
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = 3_000L)
        assertEquals(setOf("edge"), out)
    }

    @Test fun `one ms past the boundary is dropped`() {
        val map = mutableMapOf("edge" to 6_999L)
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = 3_000L)
        assertTrue(out.isEmpty())
        assertTrue(map.isEmpty())
    }

    @Test fun `empty map returns empty set without throwing`() {
        val map = mutableMapOf<String, Long>()
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = 3_000L)
        assertTrue(out.isEmpty())
    }

    @Test fun `mixed-age entries are partitioned correctly in a single pass`() {
        val map = mutableMapOf(
            "ancient" to 1_000L,
            "old" to 5_999L,
            "fresh" to 7_500L,
            "newest" to 9_900L,
        )
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = 3_000L)
        assertEquals(setOf("fresh", "newest"), out)
        assertEquals(setOf("fresh", "newest"), map.keys)
    }

    @Test fun `huge TTL keeps everything regardless of age`() {
        val map = mutableMapOf("u1" to 0L, "u2" to 5_000L)
        val out = pruneAndSnapshotTyping(map, nowMs = 10_000L, ttlMs = Long.MAX_VALUE)
        assertEquals(setOf("u1", "u2"), out)
    }
}
