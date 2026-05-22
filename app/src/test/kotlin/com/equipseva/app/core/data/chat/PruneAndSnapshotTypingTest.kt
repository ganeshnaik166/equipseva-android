package com.equipseva.app.core.data.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the typing-indicator TTL prune. Critical region: STRICTLY
 * greater than ttlMs is the cutoff — entries exactly at ttlMs stay
 * alive so a typist whose last frame just hit the boundary doesn't
 * blink out between ticks.
 *
 * The helper mutates the map in place (caller observes the side
 * effect) so the receiver-coroutine + tick-coroutine can share state.
 */
class PruneAndSnapshotTypingTest {

    @Test fun `empty map returns empty set (no allocation surprise)`() {
        val map = mutableMapOf<String, Long>()
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertTrue(out.isEmpty())
        assertTrue(map.isEmpty())
    }

    @Test fun `recent entries inside TTL survive`() {
        val map = mutableMapOf<String, Long>(
            "u-1" to 90L,
            "u-2" to 95L,
        )
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertEquals(setOf("u-1", "u-2"), out)
    }

    @Test fun `stale entries past TTL are removed`() {
        val map = mutableMapOf<String, Long>(
            "stale" to 10L,        // 90ms ago, past 50ms TTL
            "fresh" to 80L,        // 20ms ago, inside TTL
        )
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertEquals(setOf("fresh"), out)
        // Map mutated in place
        assertEquals(setOf("fresh"), map.keys)
    }

    @Test fun `entry exactly at TTL boundary stays alive (strict greater-than cutoff)`() {
        // now - ts = 50, ttl = 50 — NOT > ttl, so it stays.
        // Pin so a refactor to >= doesn't blink typists out on the
        // boundary tick.
        val map = mutableMapOf<String, Long>("edge" to 50L)
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertEquals(setOf("edge"), out)
    }

    @Test fun `entry one ms past TTL is removed`() {
        val map = mutableMapOf<String, Long>("just-past" to 49L)  // 51ms ago, past 50
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertTrue(out.isEmpty())
    }

    @Test fun `all-stale map prunes to empty`() {
        val map = mutableMapOf<String, Long>(
            "u-1" to 0L,
            "u-2" to 5L,
            "u-3" to 10L,
        )
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertTrue(out.isEmpty())
        assertTrue(map.isEmpty())
    }

    @Test fun `mutation is observable to the caller (side effect contract)`() {
        // The receiver-coroutine + tick-coroutine share the lastSeen
        // map; pin the in-place mutation so a future "return copy"
        // refactor surfaces.
        val map = mutableMapOf<String, Long>("stale" to 0L, "fresh" to 80L)
        pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertEquals(setOf("fresh"), map.keys)
    }

    @Test fun `future-dated entry stays (defensive — clock skew)`() {
        // A future timestamp (clock skew between sender and receiver)
        // produces a negative delta — the cutoff (delta > ttl) is
        // false, so the entry stays alive. Pin so a refactor to
        // absolute-value diff doesn't accidentally prune ahead-of-
        // clock frames.
        val map = mutableMapOf<String, Long>("future" to 150L)
        val out = pruneAndSnapshotTyping(map, nowMs = 100L, ttlMs = 50L)
        assertEquals(setOf("future"), out)
    }
}
