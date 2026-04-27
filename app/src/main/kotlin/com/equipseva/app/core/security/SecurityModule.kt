package com.equipseva.app.core.security

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module that binds the public [IntegrityVerifier] interface to the
 * concrete [PlayIntegrityClient] so unit tests can swap in a no-op verifier
 * without touching the Play Services SDK or building a real Supabase client.
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class SecurityModule {

    @Binds
    @Singleton
    abstract fun bindIntegrityVerifier(impl: PlayIntegrityClient): IntegrityVerifier
}
