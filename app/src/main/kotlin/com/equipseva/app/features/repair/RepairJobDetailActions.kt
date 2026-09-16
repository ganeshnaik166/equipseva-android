package com.equipseva.app.features.repair

import com.equipseva.app.core.data.moderation.ContentReportReason

/**
 * Every command the repair-job detail UI can issue. The screen body takes
 * this instead of the ViewModel so it can be rendered from a hand-built
 * state (screenshot fixtures, previews) without Hilt or a lifecycle owner.
 *
 * Member signatures mirror the ViewModel's one-to-one, so [asActions] stays
 * a plain delegation with no argument mapping to drift out of sync.
 */
internal interface RepairJobDetailActions {
    fun retry()
    fun onOpenReport()
    fun onDismissReport()
    fun onSubmitReport(reason: ContentReportReason, notes: String?)
    fun generateServiceReport()
    fun generateInvoice()
    fun refreshEscrow()
    fun openEscrowPaymentSheet()
    fun closeEscrowPaymentSheet()
    fun closeOrderSummarySheet()
    fun proceedToPaymentFromSummary()
    fun openEscrowDisputeSheet()
    fun closeEscrowDisputeSheet()
    fun confirmEscrowRelease()
    fun openEngineerResponseSheet()
    fun closeEngineerResponseSheet()
    fun submitEngineerResponse(response: String)
    fun openEscrowDispute(reason: String)
    fun openBidComposer()
    fun closeBidComposer()
    fun submitBid(amountRupees: Double, etaHours: Int?, note: String?)
    fun openChatWithHospital()
    fun openChatWithEngineer()
    fun withdrawBid()
    fun submitCheckinWithProof(photos: List<RepairJobDetailViewModel.CompletionProofPhoto>)
    fun openProofSheet()
    fun closeProofSheet()
    fun openReviseQuoteSheet()
    fun closeReviseQuoteSheet()
    fun proposeCostRevision(revisedRupees: Double, reason: String)
    fun openRevisionDecisionSheet()
    fun closeRevisionDecisionSheet()
    fun decideCostRevision(approve: Boolean)
    fun submitCompletionProof(photos: List<RepairJobDetailViewModel.CompletionProofPhoto>)
    // The ViewModel defaults `reason` to null; interface members cannot carry
    // defaults, and the cancel sheet always supplies the (possibly null) reason.
    fun cancelJob(reason: String?)
    fun submitRating(stars: Int, review: String?)
    fun acceptBid(bidId: String)
}

/** Forwards every action to the ViewModel unchanged; what the production wrapper hands the body. */
internal fun RepairJobDetailViewModel.asActions(): RepairJobDetailActions {
    val viewModel = this
    return object : RepairJobDetailActions {
        override fun retry() { viewModel.retry() }
        override fun onOpenReport() { viewModel.onOpenReport() }
        override fun onDismissReport() { viewModel.onDismissReport() }
        override fun onSubmitReport(reason: ContentReportReason, notes: String?) { viewModel.onSubmitReport(reason, notes) }
        override fun generateServiceReport() { viewModel.generateServiceReport() }
        override fun generateInvoice() { viewModel.generateInvoice() }
        override fun refreshEscrow() { viewModel.refreshEscrow() }
        override fun openEscrowPaymentSheet() { viewModel.openEscrowPaymentSheet() }
        override fun closeEscrowPaymentSheet() { viewModel.closeEscrowPaymentSheet() }
        override fun closeOrderSummarySheet() { viewModel.closeOrderSummarySheet() }
        override fun proceedToPaymentFromSummary() { viewModel.proceedToPaymentFromSummary() }
        override fun openEscrowDisputeSheet() { viewModel.openEscrowDisputeSheet() }
        override fun closeEscrowDisputeSheet() { viewModel.closeEscrowDisputeSheet() }
        override fun confirmEscrowRelease() { viewModel.confirmEscrowRelease() }
        override fun openEngineerResponseSheet() { viewModel.openEngineerResponseSheet() }
        override fun closeEngineerResponseSheet() { viewModel.closeEngineerResponseSheet() }
        override fun submitEngineerResponse(response: String) { viewModel.submitEngineerResponse(response) }
        override fun openEscrowDispute(reason: String) { viewModel.openEscrowDispute(reason) }
        override fun openBidComposer() { viewModel.openBidComposer() }
        override fun closeBidComposer() { viewModel.closeBidComposer() }
        override fun submitBid(amountRupees: Double, etaHours: Int?, note: String?) { viewModel.submitBid(amountRupees, etaHours, note) }
        override fun openChatWithHospital() { viewModel.openChatWithHospital() }
        override fun openChatWithEngineer() { viewModel.openChatWithEngineer() }
        override fun withdrawBid() { viewModel.withdrawBid() }
        override fun submitCheckinWithProof(photos: List<RepairJobDetailViewModel.CompletionProofPhoto>) { viewModel.submitCheckinWithProof(photos) }
        override fun openProofSheet() { viewModel.openProofSheet() }
        override fun closeProofSheet() { viewModel.closeProofSheet() }
        override fun openReviseQuoteSheet() { viewModel.openReviseQuoteSheet() }
        override fun closeReviseQuoteSheet() { viewModel.closeReviseQuoteSheet() }
        override fun proposeCostRevision(revisedRupees: Double, reason: String) { viewModel.proposeCostRevision(revisedRupees, reason) }
        override fun openRevisionDecisionSheet() { viewModel.openRevisionDecisionSheet() }
        override fun closeRevisionDecisionSheet() { viewModel.closeRevisionDecisionSheet() }
        override fun decideCostRevision(approve: Boolean) { viewModel.decideCostRevision(approve) }
        override fun submitCompletionProof(photos: List<RepairJobDetailViewModel.CompletionProofPhoto>) { viewModel.submitCompletionProof(photos) }
        override fun cancelJob(reason: String?) { viewModel.cancelJob(reason) }
        override fun submitRating(stars: Int, review: String?) { viewModel.submitRating(stars, review) }
        override fun acceptBid(bidId: String) { viewModel.acceptBid(bidId) }
    }
}

/** Swallows every action; for fixtures and previews that only need the body to draw. */
internal object NoOpRepairJobDetailActions : RepairJobDetailActions {
    override fun retry() = Unit
    override fun onOpenReport() = Unit
    override fun onDismissReport() = Unit
    override fun onSubmitReport(reason: ContentReportReason, notes: String?) = Unit
    override fun generateServiceReport() = Unit
    override fun generateInvoice() = Unit
    override fun refreshEscrow() = Unit
    override fun openEscrowPaymentSheet() = Unit
    override fun closeEscrowPaymentSheet() = Unit
    override fun closeOrderSummarySheet() = Unit
    override fun proceedToPaymentFromSummary() = Unit
    override fun openEscrowDisputeSheet() = Unit
    override fun closeEscrowDisputeSheet() = Unit
    override fun confirmEscrowRelease() = Unit
    override fun openEngineerResponseSheet() = Unit
    override fun closeEngineerResponseSheet() = Unit
    override fun submitEngineerResponse(response: String) = Unit
    override fun openEscrowDispute(reason: String) = Unit
    override fun openBidComposer() = Unit
    override fun closeBidComposer() = Unit
    override fun submitBid(amountRupees: Double, etaHours: Int?, note: String?) = Unit
    override fun openChatWithHospital() = Unit
    override fun openChatWithEngineer() = Unit
    override fun withdrawBid() = Unit
    override fun submitCheckinWithProof(photos: List<RepairJobDetailViewModel.CompletionProofPhoto>) = Unit
    override fun openProofSheet() = Unit
    override fun closeProofSheet() = Unit
    override fun openReviseQuoteSheet() = Unit
    override fun closeReviseQuoteSheet() = Unit
    override fun proposeCostRevision(revisedRupees: Double, reason: String) = Unit
    override fun openRevisionDecisionSheet() = Unit
    override fun closeRevisionDecisionSheet() = Unit
    override fun decideCostRevision(approve: Boolean) = Unit
    override fun submitCompletionProof(photos: List<RepairJobDetailViewModel.CompletionProofPhoto>) = Unit
    override fun cancelJob(reason: String?) = Unit
    override fun submitRating(stars: Int, review: String?) = Unit
    override fun acceptBid(bidId: String) = Unit
}
