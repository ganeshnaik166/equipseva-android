package com.equipseva.app.navigation

import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridge between [android.app.Activity.onNewIntent] / launch intents and the Compose nav
 * graph. The activity calls [dispatch] on each intent; the main nav graph collects [events]
 * and navigates accordingly.
 */
@Singleton
class DeepLinkRouter @Inject constructor() {

    sealed interface Event {
        data class OpenOrder(val orderId: String) : Event
    }

    private val channel = Channel<Event>(Channel.BUFFERED)
    val events = channel.receiveAsFlow()

    fun dispatch(intent: Intent?) {
        val data = intent?.data ?: return
        parse(data)?.let { channel.trySend(it) }
    }

    private fun parse(uri: Uri): Event? {
        val host = uri.host ?: return null
        val path = uri.path.orEmpty()
        return when {
            host == "equipseva.com" && path.startsWith("/pay/return") -> {
                uri.getQueryParameter("order_id")?.takeIf { it.isNotBlank() }
                    ?.let(Event::OpenOrder)
            }
            else -> null
        }
    }
}
