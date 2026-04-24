package com.equipseva.app.core.sync

/**
 * Registered outbox kinds. Adding a new kind here is the contract for
 * feature modules to hand in a [OutboxKindHandler] via Dagger multibinding
 * (see [OutboxHandlersModule]).
 */
object OutboxKinds {
    const val CHAT_MESSAGE = "chat_message"
    const val REPAIR_BID = "repair_bid"
    const val JOB_STATUS = "job_status"
    const val PHOTO_UPLOAD = "photo_upload"
    const val CART_MUTATION = "cart_mutation"
}
