package com.medeq.app.ui.search

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.medeq.app.data.local.AppDatabase
import com.medeq.app.data.remote.NetworkModule
import com.medeq.app.data.repository.EquipmentRepository

/** Lightweight factory so the project doesn't have to pull in Hilt to compile. */
class SearchViewModelFactory(private val context: Context) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(SearchViewModel::class.java))
        val db = AppDatabase.get(context)
        val api = NetworkModule.openFdaApi(context, debugLogging = false)
        @Suppress("UNCHECKED_CAST")
        return SearchViewModel(EquipmentRepository(db, api)) as T
    }
}
