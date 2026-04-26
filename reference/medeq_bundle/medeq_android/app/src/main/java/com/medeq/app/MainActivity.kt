package com.medeq.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.medeq.app.ui.search.SearchScreen
import com.medeq.app.ui.search.SearchViewModel
import com.medeq.app.ui.search.SearchViewModelFactory

class MainActivity : ComponentActivity() {

    private val vm: SearchViewModel by viewModels { SearchViewModelFactory(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface { SearchScreen(vm) }
            }
        }
    }
}
