-- Round 840 — /pulse-extended v3 adds 5 more high-frequency KPIs.
-- r790 shipped 13. Add 5 more health metrics:
--   14. Disputes resolved (WoW)
--   15. AMC paid orders (WoW count)
--   16. Supervised completions (WoW)
--   17. Bids accepted (WoW)
--   18. AMC renewal attempts (WoW)
BEGIN;
DROP FUNCTION IF EXISTS public.founder_pulse_extended();
CREATE OR REPLACE FUNCTION public.founder_pulse_extended()
RETURNS TABLE (
  metric text,
  this_week numeric,
  last_week numeric,
  delta_pct numeric,
  ord int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cur_start timestamptz := now() - interval '7 days';
  v_prior_start timestamptz := now() - interval '14 days';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH rows(metric, ord, t, l) AS (
    VALUES
    ('Signups'::text, 1,
      (SELECT count(*)::numeric FROM auth.users WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM auth.users WHERE created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Jobs posted', 2,
      (SELECT count(*)::numeric FROM public.repair_jobs WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.repair_jobs WHERE created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Jobs completed', 3,
      (SELECT count(*)::numeric FROM public.repair_jobs WHERE status='completed' AND completed_at >= v_cur_start AND completed_at < now()),
      (SELECT count(*)::numeric FROM public.repair_jobs WHERE status='completed' AND completed_at >= v_prior_start AND completed_at < v_cur_start)),
    ('GMV (₹)', 4,
      (SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric FROM public.repair_jobs WHERE status='completed' AND completed_at >= v_cur_start AND completed_at < now()),
      (SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric FROM public.repair_jobs WHERE status='completed' AND completed_at >= v_prior_start AND completed_at < v_cur_start)),
    ('Bids placed', 5,
      (SELECT count(*)::numeric FROM public.repair_job_bids WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.repair_job_bids WHERE created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Payouts paid (₹)', 6,
      (SELECT round(coalesce(sum(amount_paise), 0)::numeric / 100.0, 2) FROM public.engineer_payouts WHERE status='processed' AND queued_at >= v_cur_start AND queued_at < now()),
      (SELECT round(coalesce(sum(amount_paise), 0)::numeric / 100.0, 2) FROM public.engineer_payouts WHERE status='processed' AND queued_at >= v_prior_start AND queued_at < v_cur_start)),
    ('New AMCs', 7,
      (SELECT count(*)::numeric FROM public.amc_contracts WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.amc_contracts WHERE created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Disputes opened', 8,
      (SELECT count(*)::numeric FROM public.dispute_evidence_packs WHERE status='submitted' AND created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.dispute_evidence_packs WHERE status='submitted' AND created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Code Red opened', 9,
      (SELECT count(*)::numeric FROM public.code_red_requests WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.code_red_requests WHERE created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Referrals created', 10,
      (SELECT count(*)::numeric FROM public.engineer_referrals WHERE created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.engineer_referrals WHERE created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Failed payouts', 11,
      (SELECT count(*)::numeric FROM public.engineer_payouts WHERE status='failed' AND queued_at >= v_cur_start AND queued_at < now()),
      (SELECT count(*)::numeric FROM public.engineer_payouts WHERE status='failed' AND queued_at >= v_prior_start AND queued_at < v_cur_start)),
    ('New paused AMCs', 12,
      (SELECT count(*)::numeric FROM public.amc_contracts WHERE status='paused' AND updated_at >= v_cur_start AND updated_at < now()),
      (SELECT count(*)::numeric FROM public.amc_contracts WHERE status='paused' AND updated_at >= v_prior_start AND updated_at < v_cur_start)),
    ('Spot audit responses', 13,
      (SELECT count(*)::numeric FROM public.spot_audit_responses WHERE responded_at >= v_cur_start AND responded_at < now()),
      (SELECT count(*)::numeric FROM public.spot_audit_responses WHERE responded_at >= v_prior_start AND responded_at < v_cur_start)),
    ('Disputes resolved', 14,
      (SELECT count(*)::numeric FROM public.dispute_evidence_packs WHERE mediator_decision_at >= v_cur_start AND mediator_decision_at < now()),
      (SELECT count(*)::numeric FROM public.dispute_evidence_packs WHERE mediator_decision_at >= v_prior_start AND mediator_decision_at < v_cur_start)),
    ('AMC paid orders', 15,
      (SELECT count(*)::numeric FROM public.amc_payment_orders WHERE status='paid' AND created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.amc_payment_orders WHERE status='paid' AND created_at >= v_prior_start AND created_at < v_cur_start)),
    ('Supervised completions', 16,
      (SELECT count(*)::numeric FROM public.supervised_job_assignments WHERE status IN ('completed_successful','completed_failed') AND completed_at >= v_cur_start AND completed_at < now()),
      (SELECT count(*)::numeric FROM public.supervised_job_assignments WHERE status IN ('completed_successful','completed_failed') AND completed_at >= v_prior_start AND completed_at < v_cur_start)),
    ('Bids accepted', 17,
      (SELECT count(*)::numeric FROM public.repair_job_bids WHERE status='accepted' AND created_at >= v_cur_start AND created_at < now()),
      (SELECT count(*)::numeric FROM public.repair_job_bids WHERE status='accepted' AND created_at >= v_prior_start AND created_at < v_cur_start)),
    ('AMC renewal attempts', 18,
      (SELECT count(*)::numeric FROM public.amc_renewal_attempts WHERE attempted_at >= v_cur_start AND attempted_at < now()),
      (SELECT count(*)::numeric FROM public.amc_renewal_attempts WHERE attempted_at >= v_prior_start AND attempted_at < v_cur_start))
  )
  SELECT r.metric, r.t, r.l,
    CASE WHEN r.l = 0 THEN NULL ELSE round((r.t - r.l) / r.l * 100.0, 1) END,
    r.ord
  FROM rows r
  ORDER BY r.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_extended() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pulse_extended() TO authenticated;
COMMIT;
