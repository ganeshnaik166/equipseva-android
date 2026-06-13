package com.equipseva.app.core.data.analytics

/**
 * Funnel event keys mirrored from the seeded
 * `public.analytics_funnel_steps` rows in round 510. The server enforces
 * the `^[a-z][a-z0-9_]{1,63}$` shape via a CHECK constraint, so keep new
 * keys in lowercase snake_case.
 *
 * Three seeded funnels these compose into:
 *  - hospital_first_repair: APP_OPEN → HOSPITAL_SIGNED_UP → JOB_POST_STARTED → JOB_POST_SUBMITTED → JOB_BID_ACCEPTED
 *  - engineer_first_bid:    ENGINEER_KYC_VERIFIED → JOB_FEED_VIEWED → JOB_BID_SUBMITTED → JOB_BID_ACCEPTED
 *  - amc_signup:            AMC_PLANS_VIEWED → AMC_WIZARD_STARTED → AMC_PAYMENT_INITIATED → AMC_CONTRACT_ACTIVE
 */
enum class AnalyticsEvent(val key: String) {
    APP_OPEN("app_open"),
    HOSPITAL_SIGNED_UP("hospital_signed_up"),
    ENGINEER_SIGNED_UP("engineer_signed_up"),
    JOB_POST_STARTED("job_post_started"),
    JOB_POST_SUBMITTED("job_post_submitted"),
    JOB_FEED_VIEWED("job_feed_viewed"),
    JOB_BID_SUBMITTED("job_bid_submitted"),
    JOB_BID_ACCEPTED("job_bid_accepted"),
    ENGINEER_KYC_VERIFIED("engineer_kyc_verified"),
    AMC_PLANS_VIEWED("amc_plans_viewed"),
    AMC_WIZARD_STARTED("amc_wizard_started"),
    AMC_PAYMENT_INITIATED("amc_payment_initiated"),
    AMC_CONTRACT_ACTIVE("amc_contract_active"),
}
