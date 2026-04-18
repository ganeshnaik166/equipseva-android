package com.equipseva.app.core.data.prefs

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.prefsStore by preferencesDataStore(name = "equipseva_prefs")

@Singleton
class UserPrefs @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private object Keys {
        val ACTIVE_ROLE = stringPreferencesKey("active_role")
        val THEME = stringPreferencesKey("theme")
        val ONBOARDING_DONE = stringPreferencesKey("onboarding_done")
    }

    val activeRole: Flow<String?> = context.prefsStore.data.map { it[Keys.ACTIVE_ROLE] }
    val theme: Flow<String?> = context.prefsStore.data.map { it[Keys.THEME] }
    val onboardingDone: Flow<Boolean> = context.prefsStore.data.map { it[Keys.ONBOARDING_DONE] == "1" }

    suspend fun setActiveRole(role: String) {
        context.prefsStore.edit { it[Keys.ACTIVE_ROLE] = role }
    }

    suspend fun setTheme(theme: String) {
        context.prefsStore.edit { it[Keys.THEME] = theme }
    }

    suspend fun markOnboardingDone() {
        context.prefsStore.edit { it[Keys.ONBOARDING_DONE] = "1" }
    }
}

@Module
@InstallIn(SingletonComponent::class)
object PrefsModule {
    @Provides
    @Singleton
    fun provideUserPrefs(@ApplicationContext context: Context): UserPrefs = UserPrefs(context)
}
