package com.equipseva.app.navigation

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

/**
 * Thin Hilt-injected ViewModel that exposes the singleton [DeepLinkRouter]'s event stream to
 * the Compose nav graph. A ViewModel wrapper is the simplest way to inject a singleton into
 * an `@Composable` without reaching through `LocalContext`.
 */
@HiltViewModel
class DeepLinkHost @Inject constructor(
    router: DeepLinkRouter,
) : ViewModel() {
    val events: Flow<DeepLinkRouter.Event> = router.events
}
