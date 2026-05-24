package com.equipseva.app.features.auth.google

import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class IsAcceptedGoogleIdCredentialTypeTest {

    @Test fun `legacy GOOGLE_ID_TOKEN_CREDENTIAL is accepted`() {
        assertTrue(
            isAcceptedGoogleIdCredentialType(
                GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL,
            ),
        )
    }

    @Test fun `SIWG GOOGLE_ID_TOKEN_SIWG_CREDENTIAL is accepted`() {
        // Critical pin — newer SIWG flow path. A regression that
        // narrowed the gate back to the legacy-only check would
        // surface "Unexpected credential type" for users that
        // Credential Manager routes through the SIWG provider
        // (passkey-paired Google accounts on some devices).
        assertTrue(
            isAcceptedGoogleIdCredentialType(
                GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL,
            ),
        )
    }

    @Test fun `unknown credential type is rejected`() {
        assertFalse(isAcceptedGoogleIdCredentialType("androidx.credentials.TYPE_PASSWORD_CREDENTIAL"))
        assertFalse(isAcceptedGoogleIdCredentialType("com.example.UnknownType"))
    }

    @Test fun `empty string is rejected`() {
        assertFalse(isAcceptedGoogleIdCredentialType(""))
    }

    @Test fun `case-sensitive match — lowercase variant rejected`() {
        // Defensive — credential type strings are wire-frozen
        // identifiers, NOT user-facing labels. A refactor that
        // lowercase()'d here would silently break against the
        // upstream googleid library which ships exact-case constants.
        assertFalse(
            isAcceptedGoogleIdCredentialType(
                GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL.lowercase(),
            ),
        )
    }

    @Test fun `legacy + SIWG constants have known wire-frozen values`() {
        // The two googleid type-strings are essentially wire-shared
        // identifiers between Credential Manager and the app. Pin the
        // exact values so a googleid lib update that silently renamed
        // either constant surfaces here, not as a sign-in outage in
        // the field.
        assertEquals(
            "com.google.android.libraries.identity.googleid.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL",
            GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL,
        )
        assertEquals(
            "com.google.android.libraries.identity.googleid.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL",
            GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL,
        )
    }
}
