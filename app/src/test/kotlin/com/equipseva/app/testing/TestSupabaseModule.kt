package com.equipseva.app.testing

import dagger.Module
import dagger.Provides
import dagger.hilt.components.SingletonComponent
import dagger.hilt.testing.TestInstallIn
import io.github.jan.supabase.SupabaseClient
import io.mockk.mockk
import javax.inject.Singleton

/**
 * Replaces the prod [com.equipseva.app.core.supabase.SupabaseModule] in
 * Hilt JVM tests so the boot doesn't try to construct a real
 * [SupabaseClient] (which fails outside an emulator because
 * `SettingsSessionManager` can't initialise on the JVM — see PR #928
 * commit message for the gory details).
 *
 * The provided client is a relaxed MockK mock. Tests that need to drive
 * specific Supabase calls bind their own fakes via `@BindValue` or with
 * MockK's `coEvery { client.from(...) ... } returns ...` setup on the
 * injected instance. The mock itself returns sensible defaults for
 * every read path (empty lists / null / Unit) so a ViewModel that
 * eagerly observes auth state on init doesn't crash on construction.
 *
 * Scope is SingletonComponent — same as the prod module — so every
 * `@Inject SupabaseClient` site across the graph gets the same mock
 * instance per test class.
 *
 * Lives under `testing/` so the rest of the test source set can
 * discover it via package-walk; the @TestInstallIn annotation does the
 * actual swap.
 */
@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [com.equipseva.app.core.supabase.SupabaseModule::class],
)
object TestSupabaseModule {

    @Provides
    @Singleton
    fun provideFakeSupabaseClient(): SupabaseClient = mockk(relaxed = true)
}
