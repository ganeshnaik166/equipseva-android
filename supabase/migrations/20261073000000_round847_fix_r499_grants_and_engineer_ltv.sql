-- Round 847 — Fix r499 founder cockpit RPCs.
--
-- Two bugs latent since 2026-08-18:
--
-- A) GRANT EXECUTE on all five r499 functions was service_role-only:
--      REVOKE FROM PUBLIC, anon, authenticated
--      GRANT  TO service_role
--    But the founder console pages (/unit-economics, /engineers/[id])
--    call them from an *authenticated* SSR context with the founder's
--    JWT — never with the service-role key. Result: every load of
--    those pages threw `permission denied for function ...` and
--    rendered the Next error boundary instead of the actual data.
--    Fix: GRANT to authenticated. The body's is_founder() gate still
--    blocks non-founders.
--
-- B) founder_engineer_ltv_ranked referenced ep.amount_rupees on
--    engineer_payouts, but that table stores amount_paise (bigint);
--    no amount_rupees column exists. Recreate the function body to
--    use round(ep.amount_paise / 100.0, 2). Same answer when both
--    exist; correct one when only amount_paise does.
--
-- We don't touch r489 / r490 (three-way recon, TDS 194O) here. They
-- also reference ep.amount_rupees, but they only run from cron via
-- service_role — bug surface there is "cron silently fails" which
-- needs its own audit + a careful schema-fact-check (maybe there IS
-- an amount_rupees added via a Supabase dashboard SQL outside of
-- the migration history). Out of scope for this round.

BEGIN;

GRANT EXECUTE ON FUNCTION public.founder_hero_kpis()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_gmv_by_equipment_type(integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_dispute_rate_monthly(integer)
  TO authenticated;

-- founder_engineer_ltv_ranked — fix the amount_rupees reference AND
-- the grant in one go via DROP + CREATE.
DROP FUNCTION IF EXISTS public.founder_engineer_ltv_ranked(integer);
CREATE OR REPLACE FUNCTION public.founder_engineer_ltv_ranked(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  engineer_user_id        uuid,
  engineer_email          text,
  first_active_at         timestamptz,
  total_jobs_completed    bigint,
  total_gross_rupees      numeric,
  total_net_paid_rupees   numeric,
  total_tds_rupees        numeric,
  avg_rating              numeric,
  dispute_count           bigint,
  current_risk_score      int,
  risk_band               text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      ep.engineer_user_id,
      min(ep.updated_at) AS first_active_at,
      count(*) FILTER (WHERE ep.status = 'processed') AS jobs_paid,
      coalesce(
        sum(round(ep.amount_paise::numeric / 100.0, 2))
          FILTER (WHERE ep.status = 'processed'),
        0
      ) AS gross,
      coalesce(sum(t.net_payable_rupees) FILTER (WHERE t.id IS NOT NULL), 0) AS net_paid,
      coalesce(sum(t.tds_rupees) FILTER (WHERE t.id IS NOT NULL), 0) AS tds
    FROM public.engineer_payouts ep
    LEFT JOIN public.tds_deductions t ON t.payout_id = ep.id
    GROUP BY ep.engineer_user_id
  ),
  ratings AS (
    SELECT b.engineer_user_id, avg(rj.hospital_rating)::numeric(3,2) AS avg_rating
      FROM public.repair_job_bids b
      JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
     WHERE b.status = 'accepted'
       AND rj.status = 'completed'
       AND rj.hospital_rating IS NOT NULL
     GROUP BY b.engineer_user_id
  ),
  disputes AS (
    SELECT b.engineer_user_id, count(*)::bigint AS dispute_count
      FROM public.repair_job_bids b
      JOIN public.repair_job_escrow e ON e.repair_job_id = b.repair_job_id
     WHERE b.status = 'accepted'
       AND e.status = 'disputed'
     GROUP BY b.engineer_user_id
  ),
  risk AS (
    SELECT DISTINCT ON (s.user_id) s.user_id, s.score, s.band
      FROM public.risk_score_snapshots s
     WHERE s.role = 'engineer'
     ORDER BY s.user_id, s.computed_at DESC
  )
  SELECT
    base.engineer_user_id,
    coalesce((SELECT email FROM auth.users WHERE id = base.engineer_user_id), 'unknown'),
    base.first_active_at,
    base.jobs_paid,
    base.gross,
    base.net_paid,
    base.tds,
    ratings.avg_rating,
    coalesce(disputes.dispute_count, 0)::bigint,
    risk.score,
    risk.band
  FROM base
  LEFT JOIN ratings  ON ratings.engineer_user_id  = base.engineer_user_id
  LEFT JOIN disputes ON disputes.engineer_user_id = base.engineer_user_id
  LEFT JOIN risk     ON risk.user_id              = base.engineer_user_id
  ORDER BY base.gross DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_ltv_ranked(integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_ltv_ranked(integer) TO authenticated, service_role;

COMMIT;
