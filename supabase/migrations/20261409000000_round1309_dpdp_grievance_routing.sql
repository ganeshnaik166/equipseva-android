BEGIN;
-- r1309 — v0.5 Phase 7: DPDP grievance auto-routing + SLA escalator.
-- Adds a per-grievance routing snapshot RPC and a 24-hour cron job that:
--   • Auto-classifies new dpdp_grievances by grievance_type into routing buckets
--   • Creates a dpdp_grievance_routing row pointing at the assigned officer
--   • Flips approaching-SLA grievances (≥25 days) to status='escalated' if still open
--
-- Two new tables:
--   • dpdp_grievance_officers — directory of who handles which grievance_type
--   • dpdp_grievance_routing  — per-grievance routing log + SLA breach forecast
--
-- v0.5 roadmap Phase 7 — was P2 in weeks 3-5. Landing now.

CREATE TABLE IF NOT EXISTS public.dpdp_grievance_officers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  officer_label text NOT NULL,           -- "Founder" / "Legal" / "Privacy" etc.
  grievance_type text NOT NULL CHECK (grievance_type IN ('correction','erasure','portability','consent_withdrawal','other')),
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.dpdp_grievance_officers IS
  'Directory of grievance officers by type — founder owns all types until delegated.';

ALTER TABLE public.dpdp_grievance_officers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dpdp_grievance_officers_no_direct ON public.dpdp_grievance_officers;
CREATE POLICY dpdp_grievance_officers_no_direct ON public.dpdp_grievance_officers FOR ALL USING (false);
REVOKE ALL ON TABLE public.dpdp_grievance_officers FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.dpdp_grievance_routing (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grievance_id    uuid NOT NULL REFERENCES public.dpdp_grievances(id) ON DELETE CASCADE,
  officer_id      uuid REFERENCES public.dpdp_grievance_officers(id) ON DELETE SET NULL,
  classified_type text NOT NULL,
  sla_breach_at   timestamptz NOT NULL,    -- 30 days from grievance.created_at
  escalated       boolean NOT NULL DEFAULT false,
  escalated_at    timestamptz,
  routed_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_dpdp_routing_grievance ON public.dpdp_grievance_routing (grievance_id);
CREATE INDEX IF NOT EXISTS idx_dpdp_routing_sla_breach ON public.dpdp_grievance_routing (sla_breach_at) WHERE escalated = false;

ALTER TABLE public.dpdp_grievance_routing ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dpdp_grievance_routing_no_direct ON public.dpdp_grievance_routing;
CREATE POLICY dpdp_grievance_routing_no_direct ON public.dpdp_grievance_routing FOR ALL USING (false);
REVOKE ALL ON TABLE public.dpdp_grievance_routing FROM PUBLIC, anon, authenticated;

-- Seed: founder owns all 5 grievance types (delegate later)
INSERT INTO public.dpdp_grievance_officers (officer_label, grievance_type)
SELECT 'Founder', t FROM unnest(ARRAY['correction','erasure','portability','consent_withdrawal','other']::text[]) t
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Cron job: dpdp_route_and_escalate (runs every hour)
--   1. Find any dpdp_grievances without a routing row → classify + insert routing
--   2. Find routing rows where sla_breach_at < now() + 5 days AND grievance is still open → escalate
-- ============================================================================
DROP FUNCTION IF EXISTS public.dpdp_route_and_escalate();
CREATE OR REPLACE FUNCTION public.dpdp_route_and_escalate()
RETURNS TABLE (routed_count int, escalated_count int)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_routed int := 0;
  v_escalated int := 0;
BEGIN
  -- 1. Route new grievances
  WITH new_grievances AS (
    SELECT g.id AS grievance_id, g.grievance_type, g.created_at,
      (SELECT o.id FROM public.dpdp_grievance_officers o
        WHERE o.grievance_type = coalesce(g.grievance_type, 'other')
          AND o.is_active = true
        ORDER BY o.created_at ASC LIMIT 1) AS officer_id
    FROM public.dpdp_grievances g
    WHERE NOT EXISTS (SELECT 1 FROM public.dpdp_grievance_routing r WHERE r.grievance_id = g.id)
  ),
  inserted AS (
    INSERT INTO public.dpdp_grievance_routing
      (grievance_id, officer_id, classified_type, sla_breach_at)
    SELECT
      ng.grievance_id, ng.officer_id, coalesce(ng.grievance_type, 'other'), ng.created_at + interval '30 days'
    FROM new_grievances ng
    RETURNING 1
  )
  SELECT count(*)::int INTO v_routed FROM inserted;

  -- 2. Escalate routing rows where SLA breach approaches (within 5 days) and grievance still open
  WITH approaching AS (
    UPDATE public.dpdp_grievance_routing r
    SET escalated = true, escalated_at = now()
    WHERE r.escalated = false
      AND r.sla_breach_at < now() + interval '5 days'
      AND EXISTS (
        SELECT 1 FROM public.dpdp_grievances g
        WHERE g.id = r.grievance_id
          AND coalesce(g.status::text, 'open') IN ('open','in_review')
      )
    RETURNING 1
  )
  SELECT count(*)::int INTO v_escalated FROM approaching;

  RETURN QUERY SELECT v_routed, v_escalated;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dpdp_route_and_escalate() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.dpdp_route_and_escalate() TO authenticated;

-- ============================================================================
-- founder_dpdp_routing_summary — for founder UI
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_dpdp_routing_summary();
CREATE OR REPLACE FUNCTION public.founder_dpdp_routing_summary()
RETURNS TABLE (
  total_routed             bigint,
  routed_today             bigint,
  approaching_sla          bigint,
  escalated_count          bigint,
  escalated_today          bigint,
  by_type_correction       bigint,
  by_type_erasure          bigint,
  by_type_portability      bigint,
  by_type_consent_withdrawal bigint,
  by_type_other            bigint,
  median_age_days          numeric,
  oldest_unresolved_age_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE routed_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing
              WHERE escalated = false AND sla_breach_at < now() + interval '5 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE escalated = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE escalated_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'correction'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'erasure'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'portability'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'consent_withdrawal'), 0),
    coalesce((SELECT count(*)::bigint FROM public.dpdp_grievance_routing WHERE classified_type = 'other'), 0),
    coalesce((SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch from (now() - routed_at)) / 86400.0)::numeric, 1)
              FROM public.dpdp_grievance_routing), 0),
    coalesce((SELECT extract(day from (now() - min(g.created_at)))::int
              FROM public.dpdp_grievances g
              WHERE coalesce(g.status::text, 'open') IN ('open','in_review')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_dpdp_routing_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dpdp_routing_summary() TO authenticated;

-- Initial route+escalate run (idempotent)
SELECT public.dpdp_route_and_escalate();

COMMIT;
