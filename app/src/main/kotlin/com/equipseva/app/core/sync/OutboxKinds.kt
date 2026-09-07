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
    const val NOTIFICATION_READ = "notification_read"

    /**
     * round3820 — registers an already-uploaded repair photo (sha256 + size
     * from the upload receipt) in the §65B `evidence_ledger` via the
     * `register_evidence` RPC. Its own kind, not a tail step of
     * [PHOTO_UPLOAD], so a registration retry never re-uploads the photo
     * and a permanent registration failure never reads as a failed upload.
     */
    const val EVIDENCE_REGISTER = "evidence_register"
}
