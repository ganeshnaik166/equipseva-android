package com.equipseva.app.features.auth

/** Process-local identity for an observed login, including a same-user re-login. */
data class SessionOwner(val userId: String, val generation: Long)

/** One atomic root rendering input; never combine separately collected identity/gate flows. */
data class SessionPresentation(
    val state: SessionState = SessionState.Loading,
    val owner: SessionOwner? = null,
    val baseProfileComplete: Boolean = false,
    val retainedState: SessionState? = null,
    val resolvingAuth: Boolean = false,
    val profileLoading: Boolean = false,
    val profileFailed: Boolean = false,
    val signingOut: Boolean = false,
)
