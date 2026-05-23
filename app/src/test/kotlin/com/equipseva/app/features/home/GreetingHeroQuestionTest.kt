package com.equipseva.app.features.home

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the role-aware hero question on the home greeting card.
 *
 * Critical surfaces: the question mark on both branches (the card's
 * conversational tone depends on it), and the hospital-as-default
 * for null role (cold-load before role resolves).
 */
class GreetingHeroQuestionTest {

    @Test fun `engineer role reads Ready for work today`() {
        assertEquals(
            "Ready for work today?",
            greetingHeroQuestion(UserRole.ENGINEER),
        )
    }

    @Test fun `hospital role reads What needs fixing today`() {
        assertEquals(
            "What needs fixing today?",
            greetingHeroQuestion(UserRole.HOSPITAL),
        )
    }

    @Test fun `null role falls back to hospital question`() {
        // Critical pin — cold-load default. Pin so a refactor that
        // returned blank on null doesn't leave the hero looking
        // unfinished during the brief role-resolve window.
        assertEquals(
            "What needs fixing today?",
            greetingHeroQuestion(null),
        )
    }

    @Test fun `both branches end with a question mark`() {
        // Pin the conversational tone — a refactor that dropped the
        // '?' would soften the call-to-action.
        assertTrue(greetingHeroQuestion(UserRole.ENGINEER).endsWith("?"))
        assertTrue(greetingHeroQuestion(UserRole.HOSPITAL).endsWith("?"))
        assertTrue(greetingHeroQuestion(null).endsWith("?"))
    }

    @Test fun `engineer question uses Ready not Are you ready`() {
        // Pin the punchy imperative — "Are you ready" is verbose
        // and reads as a survey question rather than a prompt.
        val out = greetingHeroQuestion(UserRole.ENGINEER)
        assertTrue(out.startsWith("Ready "))
    }

    @Test fun `hospital question uses What needs fixing not What can we fix`() {
        // Pin the present-tense ownership framing — "what needs
        // fixing" frames the equipment as the subject (which it is)
        // rather than the agency on the platform side.
        val out = greetingHeroQuestion(UserRole.HOSPITAL)
        assertTrue(out.startsWith("What needs fixing"))
    }
}
