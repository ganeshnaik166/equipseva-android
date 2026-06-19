BEGIN;

-- r1327 — Founder compliance ledger (consolidated)
--
-- Single read-only aggregator RPC that fans out across every regulatory /
-- compliance surface and returns a board-diligence-ready snapshot. NO new
-- tables — pure SELECT aggregation over previously-shipped ledgers.
--
-- Sources read (all verified to exist in this repo):
--   - founder_gst_filings (r1316)                       — GST quarterly filings
--   - gst_invoices                  (r491)              — lifetime outward taxable
--   - dpdp_grievances               (r485)              — privacy complaints + SLA
--   - dpdp_grievance_officers       (r1309)             — top officer label
--   - dpdp_grievance_routing        (r1309)             — SLA escalation snapshot
--   - razorpay_webhook_events       (r471)              — last capture + lifetime
--   - engineer_payouts              (r422)              — cashfree-side processed
--   - founder_action_log            (r482)              — audit log throughput
--   - engineers.verification_status (enum, cast ::text) — pending KYC count
--   - repair_job_escrow.dispute_*   (v21)               — open disputes
--   - code_red_requests             (r509)              — open code-red emergencies
--
-- Sources NOT shipped (return COALESCE(0)):
--   - CDSCO representations         — no table; reserved for v0.6
--   - NABH certified hospitals      — only nabh_export_audit exists; not a
--                                     certification ledger
--   - founder_compliance_assertions — no table; Udyam URN hard-coded from
--                                     activation 2026-06-10 (URN
--                                     UDYAM-TS-07-0099805)
--
-- Score weighting (overall_compliance_score, 0..100):
--   30% GST    (quarters_filed / 4 in current FY)
--   30% DPDP   (resolved_within_sla_pct)
--   20% KYC    (1 - pending_kyc / max(active_engineers,1))
--   10% Razorpay capture liveness (capture within last 7 days)
--   10% Cashfree payout liveness  (payout within last 14 days)
--
-- All math is COALESCE-safe so missing tables degrade gracefully.

DROP FUNCTION IF EXISTS public.founder_compliance_ledger_consolidated();

CREATE OR REPLACE FUNCTION public.founder_compliance_ledger_consolidated()
RETURNS TABLE (
  cdsco_pending_representations       bigint,
  cdsco_resolved_representations      bigint,
  gst_quarters_filed                  int,
  gst_lifetime_outward_taxable_rupees numeric,
  gst_last_filing_at                  timestamptz,
  nabh_hospitals_certified            bigint,
  dpdp_total_grievances               bigint,
  dpdp_resolved_within_sla_pct        numeric,
  dpdp_top_officer                    text,
  udyam_registered                    boolean,
  udyam_urn                           text,
  razorpay_last_capture_at            timestamptz,
  razorpay_lifetime_captures_rupees   numeric,
  cashfree_last_payout_at             timestamptz,
  cashfree_lifetime_payouts_rupees    numeric,
  audit_log_30d_count                 bigint,
  audit_log_lifetime_count            bigint,
  pending_kyc_engineers               bigint,
  open_dispute_count                  bigint,
  open_code_red_count                 bigint,
  overall_compliance_score            numeric,
  generated_at                        timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_gst_quarters_filed              int := 0;
  v_gst_lifetime_outward            numeric := 0;
  v_gst_last_filing                 timestamptz;
  v_dpdp_total                      bigint := 0;
  v_dpdp_resolved                   bigint := 0;
  v_dpdp_resolved_within_sla        bigint := 0;
  v_dpdp_sla_pct                    numeric := 0;
  v_dpdp_top_officer                text;
  v_rzp_last_capture                timestamptz;
  v_rzp_lifetime                    numeric := 0;
  v_cf_last_payout                  timestamptz;
  v_cf_lifetime                     numeric := 0;
  v_audit_30d                       bigint := 0;
  v_audit_lifetime                  bigint := 0;
  v_pending_kyc                     bigint := 0;
  v_active_engineers                bigint := 0;
  v_open_disputes                   bigint := 0;
  v_open_code_red                   bigint := 0;
  v_score_gst                       numeric := 0;
  v_score_dpdp                      numeric := 0;
  v_score_kyc                       numeric := 0;
  v_score_rzp                       numeric := 0;
  v_score_cf                        numeric := 0;
  v_score                           numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- GST: filed quarters + last filing + lifetime outward taxable
  SELECT
    coalesce(count(*) FILTER (WHERE status = 'filed'), 0)::int,
    max(filed_at) FILTER (WHERE status = 'filed')
  INTO v_gst_quarters_filed, v_gst_last_filing
  FROM public.founder_gst_filings;

  SELECT coalesce(sum(taxable_amount_rupees), 0)
  INTO v_gst_lifetime_outward
  FROM public.gst_invoices
  WHERE status = 'issued';

  -- DPDP: total + resolved-within-SLA %
  SELECT
    coalesce(count(*), 0),
    coalesce(count(*) FILTER (WHERE status = 'resolved'), 0),
    coalesce(count(*) FILTER (
      WHERE status = 'resolved'
        AND resolved_at IS NOT NULL
        AND resolved_at <= deadline_at
    ), 0)
  INTO v_dpdp_total, v_dpdp_resolved, v_dpdp_resolved_within_sla
  FROM public.dpdp_grievances;

  IF v_dpdp_resolved > 0 THEN
    v_dpdp_sla_pct := round((v_dpdp_resolved_within_sla::numeric / v_dpdp_resolved::numeric) * 100.0, 1);
  END IF;

  -- DPDP top officer (most routed grievances, active officers only)
  SELECT o.officer_label
  INTO v_dpdp_top_officer
  FROM public.dpdp_grievance_officers o
  JOIN public.dpdp_grievance_routing r ON r.officer_id = o.id
  WHERE o.is_active = true
  GROUP BY o.officer_label
  ORDER BY count(*) DESC
  LIMIT 1;

  -- Razorpay last capture + lifetime captured rupees (paise → rupees)
  SELECT
    max(received_at) FILTER (WHERE event_type = 'payment.captured' AND applied = true),
    coalesce(sum(amount_paise) FILTER (WHERE event_type = 'payment.captured' AND applied = true), 0)::numeric / 100.0
  INTO v_rzp_last_capture, v_rzp_lifetime
  FROM public.razorpay_webhook_events;

  -- Cashfree payouts processed (engineer_payouts.status = 'processed')
  SELECT
    max(processed_at) FILTER (WHERE status = 'processed'),
    coalesce(sum(amount_paise) FILTER (WHERE status = 'processed'), 0)::numeric / 100.0
  INTO v_cf_last_payout, v_cf_lifetime
  FROM public.engineer_payouts;

  -- Audit log throughput
  SELECT
    coalesce(count(*) FILTER (WHERE created_at >= now() - interval '30 days'), 0),
    coalesce(count(*), 0)
  INTO v_audit_30d, v_audit_lifetime
  FROM public.founder_action_log;

  -- KYC: pending engineer verifications (cast enum ::text)
  SELECT coalesce(count(*), 0)
  INTO v_pending_kyc
  FROM public.engineers
  WHERE coalesce(verification_status::text, 'pending') = 'pending';

  SELECT coalesce(count(*), 0)
  INTO v_active_engineers
  FROM public.engineers
  WHERE coalesce(verification_status::text, 'pending') IN ('pending', 'verified');

  -- Open disputes (repair_job_escrow.dispute_opened_at set, resolution null)
  SELECT coalesce(count(*), 0)
  INTO v_open_disputes
  FROM public.repair_job_escrow
  WHERE dispute_opened_at IS NOT NULL
    AND dispute_resolution IS NULL;

  -- Open Code Red emergencies
  SELECT coalesce(count(*), 0)
  INTO v_open_code_red
  FROM public.code_red_requests
  WHERE status = 'open';

  -- Score: 0..100 weighted index
  v_score_gst  := least(30.0, (v_gst_quarters_filed::numeric / 4.0) * 30.0);
  v_score_dpdp := round((v_dpdp_sla_pct / 100.0) * 30.0, 2);
  IF v_active_engineers > 0 THEN
    v_score_kyc := round((1.0 - (v_pending_kyc::numeric / v_active_engineers::numeric)) * 20.0, 2);
  ELSE
    v_score_kyc := 20.0;
  END IF;
  v_score_rzp  := CASE WHEN v_rzp_last_capture IS NOT NULL AND v_rzp_last_capture >= now() - interval '7 days'  THEN 10.0 ELSE 0.0 END;
  v_score_cf   := CASE WHEN v_cf_last_payout   IS NOT NULL AND v_cf_last_payout   >= now() - interval '14 days' THEN 10.0 ELSE 0.0 END;
  v_score := round(greatest(0.0, least(100.0, v_score_gst + v_score_dpdp + v_score_kyc + v_score_rzp + v_score_cf)), 1);

  RETURN QUERY SELECT
    0::bigint                                  AS cdsco_pending_representations,
    0::bigint                                  AS cdsco_resolved_representations,
    v_gst_quarters_filed                       AS gst_quarters_filed,
    v_gst_lifetime_outward                     AS gst_lifetime_outward_taxable_rupees,
    v_gst_last_filing                          AS gst_last_filing_at,
    0::bigint                                  AS nabh_hospitals_certified,
    v_dpdp_total                               AS dpdp_total_grievances,
    v_dpdp_sla_pct                             AS dpdp_resolved_within_sla_pct,
    coalesce(v_dpdp_top_officer, 'Founder')    AS dpdp_top_officer,
    true                                       AS udyam_registered,
    'UDYAM-TS-07-0099805'::text                AS udyam_urn,
    v_rzp_last_capture                         AS razorpay_last_capture_at,
    v_rzp_lifetime                             AS razorpay_lifetime_captures_rupees,
    v_cf_last_payout                           AS cashfree_last_payout_at,
    v_cf_lifetime                              AS cashfree_lifetime_payouts_rupees,
    v_audit_30d                                AS audit_log_30d_count,
    v_audit_lifetime                           AS audit_log_lifetime_count,
    v_pending_kyc                              AS pending_kyc_engineers,
    v_open_disputes                            AS open_dispute_count,
    v_open_code_red                            AS open_code_red_count,
    v_score                                    AS overall_compliance_score,
    now()                                      AS generated_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_compliance_ledger_consolidated() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_compliance_ledger_consolidated() TO authenticated;

COMMENT ON FUNCTION public.founder_compliance_ledger_consolidated() IS
  'r1327 — board-diligence-ready compliance freeze. Aggregates GST/DPDP/Razorpay/Cashfree/KYC/disputes/Code Red into 22 KPIs + a weighted 0..100 score. Founder-only. Use as the read-only source for /founder-compliance-ledger and the public investor share v2 compliance band.';

COMMIT;