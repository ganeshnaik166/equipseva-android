package com.equipseva.app.core.data.profile

import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * A successful role mutation invalidates the root's cached profile even if its
 * screen has already been removed. This carries no identity, role or navigation
 * authority: the root must fetch and validate its own current login again.
 */
@Singleton
class ProfileInvalidations @Inject constructor() {
    private val _revision = MutableStateFlow(0L)
    val revision = _revision.asStateFlow()

    fun invalidate() { _revision.update { it + 1 } }
}
