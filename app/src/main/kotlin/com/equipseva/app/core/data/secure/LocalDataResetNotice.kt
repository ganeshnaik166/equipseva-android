package com.equipseva.app.core.data.secure

import android.content.Context
import androidx.core.content.edit
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * One-time notice that the encrypted local database had to be discarded because its Keystore
 * key was lost, so offline changes that had not synced yet are gone. The flag is written
 * synchronously when the files are discarded and stays set until the notice has been shown,
 * so a process death in between shows it again on the next launch.
 */
@Singleton
class LocalDataResetNotice @Inject constructor(@ApplicationContext context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val _pending = MutableStateFlow(prefs.getBoolean(KEY_PENDING, false))
    val pending: StateFlow<Boolean> = _pending.asStateFlow()

    /** Written synchronously: the database files are deleted right after this returns. */
    fun markPending() {
        prefs.edit(commit = true) { putBoolean(KEY_PENDING, true) }
        _pending.value = true
    }

    fun acknowledge() {
        prefs.edit { remove(KEY_PENDING) }
        _pending.value = false
    }

    private companion object {
        const val PREFS = "local_data_reset"
        const val KEY_PENDING = "pending"
    }
}
