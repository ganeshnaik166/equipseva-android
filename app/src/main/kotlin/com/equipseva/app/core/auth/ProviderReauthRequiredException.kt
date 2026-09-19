package com.equipseva.app.core.auth

/**
 * Raised instead of [InvalidCurrentPasswordException] when the signed-in account
 * has no password identity at all (Google-only sign-up). Re-authenticating such
 * a user by password can never succeed, so callers must offer the provider's
 * own re-auth (a fresh Google ID token) rather than reporting "incorrect
 * password" — which used to leave Google users with no way to delete their
 * account or change their email.
 */
class ProviderReauthRequiredException(val provider: String) :
    Exception("This account signs in with $provider and has no password to confirm.")
