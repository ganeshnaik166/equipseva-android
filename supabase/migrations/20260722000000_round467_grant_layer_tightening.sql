-- Round 467 — grant-layer hardening.
--
-- Caught by the 2026-06-09 comprehensive verification workflow:
--
-- (1) MED — round-465 column-level REVOKE on (engineer_payout,
--     platform_commission, is_warranty_covered, engineer_id) was INERT.
--     Postgres semantics: a table-level UPDATE grant overrides
--     subsequent column-level REVOKEs. authenticated + anon still
--     held table-level UPDATE on public.repair_jobs (granted earlier
--     in the schema), so the column REVOKE never took effect.
--     Verification: has_column_privilege('authenticated',
--     'public.repair_jobs', 'engineer_payout', 'UPDATE') = TRUE.
--     Real-world impact today: ZERO (the three BEFORE-UPDATE triggers
--     introduced in round 465 still catch tamper attempts). But the
--     "defense in depth" claim in the round-465 PR was misleading.
--     Defense rests on one layer (triggers) not two.
--
-- (2) LOW — Three audit log + webhook tables had wide grants too:
--     engineer_payouts_admin_events, repair_invoice_emails,
--     payouts_webhook_events all let authenticated INSERT/UPDATE/DELETE
--     at the grant layer. RLS policies block (no write policy = no row
--     ever matches), but defense-in-depth would REVOKE all writes.
--
-- Fix:
--   * REVOKE UPDATE entirely from authenticated/anon on repair_jobs,
--     then re-GRANT UPDATE only on the columns clients legitimately
--     write (issue_description, photos, ratings, scheduled_date, etc.).
--     Locked columns stay locked at the GRANT layer, so even if a
--     future migration drops the BEFORE-UPDATE triggers, raw PATCH
--     to engineer_payout / platform_commission / is_warranty_covered /
--     engineer_id will error at Postgres-level "permission denied for
--     column".
--   * REVOKE INSERT/UPDATE/DELETE on the 3 audit-log tables. RLS still
--     does the row-level enforcement; this adds the GRANT layer.

-- ---------------------------------------------------------------------
-- 1. repair_jobs: tighten UPDATE to column-allowlist
-- ---------------------------------------------------------------------

-- First, revoke the wide table-level UPDATE.
REVOKE UPDATE ON public.repair_jobs FROM authenticated, anon;

-- Re-grant UPDATE on the columns clients legitimately set. Anything
-- NOT in this list is locked at the grant layer:
--   • id, job_number, created_at: identity / auto
--   • hospital_org_id, hospital_user_id: immutable after creation
--   • engineer_id: round 465 — locked after work starts
--   • engineer_payout, platform_commission: round 465 — computed by trigger only
--   • is_warranty_covered: round 465 — stamped at INSERT only
--   • contracted_amount_rupees: set via accept_bid / decide_cost_revision RPC only
--   • payment_status, payment_id: Razorpay webhook only
--   • started_at, completed_at: auto-stamped on status transition
--   • amc_visit_number, warranty_source_job_id: trigger-set
GRANT UPDATE (
  -- Equipment metadata (hospital writes pre-acceptance; engineer can correct)
  equipment_id, equipment_type, equipment_brand, equipment_model, equipment_serial,
  -- Job kind/urgency
  job_type, urgency, kind, amc_contract_id,
  -- Issue + diagnosis
  issue_description, issue_photos, error_codes,
  diagnosis, work_done, parts_used,
  -- Before / after photos + report
  before_photos, after_photos, service_report_url,
  -- Cost breakdown (advisory; doesn't drive payout — engineer_payout is locked)
  estimated_cost, actual_cost_parts, actual_cost_labor, actual_cost_total,
  -- Schedule
  scheduled_date, scheduled_time_slot,
  -- Engineer GPS check-in
  engineer_latitude, engineer_longitude,
  -- Ratings + reviews (hospital rates engineer; engineer rates hospital)
  hospital_rating, hospital_review,
  engineer_rating, engineer_review,
  -- Site location (hospital can update before acceptance)
  site_location, site_latitude, site_longitude,
  -- Cancellation
  cancellation_reason,
  -- Status (guarded by repair_jobs_status_transition_guard for valid FSM moves)
  status,
  -- Bookkeeping
  updated_at
) ON public.repair_jobs TO authenticated;

-- anon stays revoked entirely.

-- Document the change so future migrations don't accidentally re-grant
-- wide UPDATE (which would silently un-lock the protected columns).
COMMENT ON TABLE public.repair_jobs IS
  'Repair / AMC jobs. Round 467: UPDATE grant is column-allowlist for authenticated; anon has no UPDATE. Locked-at-grant-layer columns: engineer_payout, platform_commission, is_warranty_covered, engineer_id, contracted_amount_rupees, payment_status, payment_id, started_at, completed_at, hospital_user_id, hospital_org_id, job_number, id, created_at, amc_visit_number, warranty_source_job_id. Triggers provide a parallel defense; do NOT broaden the grant without removing the trigger checks too.';

-- ---------------------------------------------------------------------
-- 2. Audit-log tables: REVOKE writes from authenticated (RLS was the
--    only block before; grant layer was wide-open).
-- ---------------------------------------------------------------------

REVOKE INSERT, UPDATE, DELETE ON public.engineer_payouts_admin_events FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.repair_invoice_emails FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.payouts_webhook_events FROM authenticated, anon;

-- service_role retains full access (worker / webhook handlers write here).

COMMENT ON TABLE public.engineer_payouts_admin_events IS
  'Founder force-pay / force-settle audit trail. Round 467: writes locked at grant layer (was already RLS-locked; this adds defense-in-depth).';

COMMENT ON TABLE public.repair_invoice_emails IS
  'Round 463: one row per dispatched GST invoice email. Round 467: writes locked at grant layer.';

COMMENT ON TABLE public.payouts_webhook_events IS
  'Round 445: Cashfree webhook idempotency log. Round 467: writes locked at grant layer.';
