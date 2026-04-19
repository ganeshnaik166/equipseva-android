package com.equipseva.app.core.data.orgroles

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class OrgRolesModule {
    @Binds
    @Singleton
    abstract fun bindOrgRoleRepository(impl: SupabaseOrgRoleRepository): OrgRoleRepository
}
