BEGIN;
DROP FUNCTION IF EXISTS public.founder_platform_pulse();
CREATE OR REPLACE FUNCTION public.founder_platform_pulse()
RETURNS TABLE (
  metric         text,
  value_text     text,
  value_numeric  numeric,
  ord            int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_engineers bigint;
  v_verified_engineers bigint;
  v_total_hospitals bigint;
  v_active_amcs bigint;
  v_total_mrr numeric;
  v_jobs_30d bigint;
  v_completed_30d bigint;
  v_gross_30d numeric;
  v_signups_30d bigint;
  v_paid_30d numeric;
  v_disputes_open bigint;
  v_escrow_held numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total_engineers FROM public.engineers;
  SELECT count(*)::bigint INTO v_verified_engineers FROM public.engineers WHERE verification_status = 'verified';
  SELECT count(DISTINCT hospital_user_id)::bigint INTO v_total_hospitals FROM public.repair_jobs;
  SELECT count(*)::bigint INTO v_active_amcs FROM public.amc_contracts WHERE status = 'active';
  SELECT coalesce(sum(monthly_fee_rupees), 0)::numeric INTO v_total_mrr FROM public.amc_contracts WHERE status = 'active';
  SELECT count(*)::bigint INTO v_jobs_30d FROM public.repair_jobs WHERE created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_completed_30d FROM public.repair_jobs
    WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_gross_30d FROM public.repair_jobs
    WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_signups_30d FROM auth.users WHERE created_at >= now() - interval '30 days';
  SELECT coalesce(round(sum(amount_paise)::numeric / 100.0, 2), 0)::numeric INTO v_paid_30d
    FROM public.engineer_payouts WHERE status = 'paid' AND queued_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_disputes_open FROM public.dispute_evidence_packs WHERE status = 'submitted';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_escrow_held FROM public.repair_job_escrow WHERE status IN ('pending','held','in_dispute');

  RETURN QUERY
  SELECT * FROM (VALUES
    ('Total engineers'::text,      v_total_engineers::text,           v_total_engineers::numeric,    1),
    ('Verified engineers'::text,    v_verified_engineers::text,        v_verified_engineers::numeric, 2),
    ('Hospitals (ever-active)'::text, v_total_hospitals::text,         v_total_hospitals::numeric,    3),
    ('Active AMCs'::text,           v_active_amcs::text,               v_active_amcs::numeric,        4),
    ('Total MRR'::text,             v_total_mrr::text,                 v_total_mrr,                   5),
    ('Jobs posted (30d)'::text,     v_jobs_30d::text,                  v_jobs_30d::numeric,           6),
    ('Jobs completed (30d)'::text,  v_completed_30d::text,             v_completed_30d::numeric,      7),
    ('GMV (30d)'::text,             v_gross_30d::text,                 v_gross_30d,                   8),
    ('Signups (30d)'::text,         v_signups_30d::text,               v_signups_30d::numeric,        9),
    ('Engineer payouts (30d)'::text, v_paid_30d::text,                 v_paid_30d,                   10),
    ('Open disputes'::text,         v_disputes_open::text,             v_disputes_open::numeric,     11),
    ('Live escrow balance'::text,   v_escrow_held::text,               v_escrow_held,                12)
  ) AS t(metric, value_text, value_numeric, ord);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_platform_pulse() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_platform_pulse() TO authenticated;
COMMIT;
