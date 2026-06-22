BEGIN;

-- =========================================================================
-- r2304: Customer onboarding-to-first-success latency
-- Tables:
--   founder_onboarding_journeys_r2304 — one row per customer onboarding journey
--   founder_onboarding_blockers_r2304 — blocker events per journey (root cause log)
-- Purpose: track days from contract signed to first successful service,
-- by tier, by region; surface blockers that stretched the latency.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_onboarding_journeys_r2304 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id             uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  customer_label              text NOT NULL,
  customer_tier               text NOT NULL DEFAULT 'standard'
    CHECK (customer_tier IN ('starter','standard','growth','premium','enterprise','strategic')),
  region                      text NOT NULL DEFAULT 'south'
    CHECK (region IN ('north','south','east','west','central','northeast','metro_blr','metro_hyd','metro_chn','metro_mum','metro_del','other')),
  city                        text,
  contract_signed_on          date NOT NULL,
  kickoff_on                  date,
  first_engineer_assigned_on  date,
  first_service_attempted_on  date,
  first_service_success_on    date,
  status                      text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress','succeeded','stalled','aborted','escalated','at_risk')),
  target_latency_days         int  NOT NULL DEFAULT 14 CHECK (target_latency_days BETWEEN 1 AND 365),
  actual_latency_days         int  CHECK (actual_latency_days IS NULL OR actual_latency_days >= 0),
  health_band                 text NOT NULL DEFAULT 'on_target'
    CHECK (health_band IN ('on_target','slight_delay','at_risk','breached','severely_breached')),
  csm_owner_id                uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes                       text,
  created_by                  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_foj_r2304_tier   ON public.founder_onboarding_journeys_r2304(customer_tier);
CREATE INDEX IF NOT EXISTS idx_foj_r2304_region ON public.founder_onboarding_journeys_r2304(region);
CREATE INDEX IF NOT EXISTS idx_foj_r2304_status ON public.founder_onboarding_journeys_r2304(status);
CREATE INDEX IF NOT EXISTS idx_foj_r2304_signed ON public.founder_onboarding_journeys_r2304(contract_signed_on);
CREATE INDEX IF NOT EXISTS idx_foj_r2304_band   ON public.founder_onboarding_journeys_r2304(health_band);
CREATE INDEX IF NOT EXISTS idx_foj_r2304_org    ON public.founder_onboarding_journeys_r2304(customer_org_id);

CREATE TABLE IF NOT EXISTS public.founder_onboarding_blockers_r2304 (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journey_id                  uuid NOT NULL REFERENCES public.founder_onboarding_journeys_r2304(id) ON DELETE CASCADE,
  blocker_category            text NOT NULL DEFAULT 'kyc'
    CHECK (blocker_category IN ('kyc','contract','payment','engineer_shortage','spare_parts','customer_delay','training','permit','logistics','data_migration','integration','other')),
  blocker_severity            text NOT NULL DEFAULT 'medium'
    CHECK (blocker_severity IN ('low','medium','high','critical')),
  detected_on                 date NOT NULL DEFAULT CURRENT_DATE,
  resolved_on                 date,
  days_stalled                int  CHECK (days_stalled IS NULL OR days_stalled >= 0),
  owner_role                  text NOT NULL DEFAULT 'csm'
    CHECK (owner_role IN ('csm','engineer','founder','customer','supplier','manufacturer','logistics','hospital_admin','ops')),
  owner_id                    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  root_cause                  text,
  remediation_action          text,
  prevented_future_count      int  NOT NULL DEFAULT 0 CHECK (prevented_future_count >= 0),
  created_by                  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fob_r2304_journey ON public.founder_onboarding_blockers_r2304(journey_id);
CREATE INDEX IF NOT EXISTS idx_fob_r2304_cat     ON public.founder_onboarding_blockers_r2304(blocker_category);
CREATE INDEX IF NOT EXISTS idx_fob_r2304_sev     ON public.founder_onboarding_blockers_r2304(blocker_severity);
CREATE INDEX IF NOT EXISTS idx_fob_r2304_detect  ON public.founder_onboarding_blockers_r2304(detected_on);

-- =========================================================================
-- RLS — founder_all
-- =========================================================================
ALTER TABLE public.founder_onboarding_journeys_r2304 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_onboarding_blockers_r2304 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_foj_r2304 ON public.founder_onboarding_journeys_r2304;
CREATE POLICY founder_all_foj_r2304 ON public.founder_onboarding_journeys_r2304
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fob_r2304 ON public.founder_onboarding_blockers_r2304;
CREATE POLICY founder_all_fob_r2304 ON public.founder_onboarding_blockers_r2304
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs (7) — all is_founder gated, plpgsql SECURITY DEFINER
-- =========================================================================

-- 1. list_onboarding_journeys_r2304
CREATE OR REPLACE FUNCTION public.list_onboarding_journeys_r2304()
RETURNS TABLE (
  id uuid,
  customer_label text,
  customer_tier text,
  region text,
  city text,
  contract_signed_on date,
  kickoff_on date,
  first_engineer_assigned_on date,
  first_service_attempted_on date,
  first_service_success_on date,
  status text,
  target_latency_days int,
  actual_latency_days int,
  effective_days_so_far int,
  health_band text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.customer_label, j.customer_tier, j.region, j.city,
         j.contract_signed_on, j.kickoff_on, j.first_engineer_assigned_on,
         j.first_service_attempted_on, j.first_service_success_on,
         j.status, j.target_latency_days, j.actual_latency_days,
         COALESCE(j.actual_latency_days,
                  (CURRENT_DATE - j.contract_signed_on))::int AS effective_days_so_far,
         j.health_band, j.notes, j.created_at
    FROM public.founder_onboarding_journeys_r2304 j
   ORDER BY j.contract_signed_on DESC, j.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_onboarding_journeys_r2304() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_onboarding_journeys_r2304() TO authenticated;

-- 2. create_onboarding_journey_r2304
CREATE OR REPLACE FUNCTION public.create_onboarding_journey_r2304(
  p_customer_label text,
  p_customer_tier text,
  p_region text,
  p_city text,
  p_contract_signed_on date,
  p_target_latency_days int,
  p_customer_org_id uuid,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_actor uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  INSERT INTO public.founder_onboarding_journeys_r2304 (
    customer_org_id, customer_label, customer_tier, region, city,
    contract_signed_on, target_latency_days, notes, created_by
  )
  VALUES (
    p_customer_org_id, p_customer_label,
    COALESCE(p_customer_tier,'standard'),
    COALESCE(p_region,'south'),
    p_city,
    p_contract_signed_on,
    COALESCE(p_target_latency_days, 14),
    p_notes, v_actor
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_onboarding_journey_r2304(text,text,text,text,date,int,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_onboarding_journey_r2304(text,text,text,text,date,int,uuid,text) TO authenticated;

-- 3. update_onboarding_milestone_r2304
CREATE OR REPLACE FUNCTION public.update_onboarding_milestone_r2304(
  p_journey_id uuid,
  p_kickoff_on date,
  p_first_engineer_assigned_on date,
  p_first_service_attempted_on date,
  p_first_service_success_on date,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_signed date;
  v_success date;
  v_actual int;
  v_target int;
  v_band text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_onboarding_journeys_r2304
     SET kickoff_on                  = COALESCE(p_kickoff_on, kickoff_on),
         first_engineer_assigned_on  = COALESCE(p_first_engineer_assigned_on, first_engineer_assigned_on),
         first_service_attempted_on  = COALESCE(p_first_service_attempted_on, first_service_attempted_on),
         first_service_success_on    = COALESCE(p_first_service_success_on, first_service_success_on),
         status                      = COALESCE(p_status, status),
         updated_at                  = now()
   WHERE id = p_journey_id;

  SELECT contract_signed_on, first_service_success_on, target_latency_days
    INTO v_signed, v_success, v_target
    FROM public.founder_onboarding_journeys_r2304
   WHERE id = p_journey_id;

  IF v_success IS NOT NULL THEN
    v_actual := (v_success - v_signed)::int;
    IF v_actual <= v_target THEN v_band := 'on_target';
    ELSIF v_actual <= v_target * 1.25 THEN v_band := 'slight_delay';
    ELSIF v_actual <= v_target * 1.5 THEN v_band := 'at_risk';
    ELSIF v_actual <= v_target * 2 THEN v_band := 'breached';
    ELSE v_band := 'severely_breached';
    END IF;
    UPDATE public.founder_onboarding_journeys_r2304
       SET actual_latency_days = v_actual,
           health_band         = v_band,
           status              = CASE WHEN status IN ('in_progress','at_risk','stalled') THEN 'succeeded' ELSE status END,
           updated_at          = now()
     WHERE id = p_journey_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_onboarding_milestone_r2304(uuid,date,date,date,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_onboarding_milestone_r2304(uuid,date,date,date,date,text) TO authenticated;

-- 4. log_onboarding_blocker_r2304
CREATE OR REPLACE FUNCTION public.log_onboarding_blocker_r2304(
  p_journey_id uuid,
  p_blocker_category text,
  p_blocker_severity text,
  p_owner_role text,
  p_root_cause text,
  p_remediation_action text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_actor uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_actor FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1;
  INSERT INTO public.founder_onboarding_blockers_r2304 (
    journey_id, blocker_category, blocker_severity, owner_role,
    root_cause, remediation_action, owner_id, created_by
  )
  VALUES (
    p_journey_id,
    COALESCE(p_blocker_category,'kyc'),
    COALESCE(p_blocker_severity,'medium'),
    COALESCE(p_owner_role,'csm'),
    p_root_cause, p_remediation_action, v_actor, v_actor
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_onboarding_blocker_r2304(uuid,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_onboarding_blocker_r2304(uuid,text,text,text,text,text) TO authenticated;

-- 5. resolve_onboarding_blocker_r2304
CREATE OR REPLACE FUNCTION public.resolve_onboarding_blocker_r2304(
  p_blocker_id uuid,
  p_prevented_future_count int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_detected date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT detected_on INTO v_detected
    FROM public.founder_onboarding_blockers_r2304
   WHERE id = p_blocker_id;
  UPDATE public.founder_onboarding_blockers_r2304
     SET resolved_on            = CURRENT_DATE,
         days_stalled           = GREATEST((CURRENT_DATE - v_detected)::int, 0),
         prevented_future_count = GREATEST(COALESCE(p_prevented_future_count, 0), 0)
   WHERE id = p_blocker_id;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_onboarding_blocker_r2304(uuid,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolve_onboarding_blocker_r2304(uuid,int) TO authenticated;

-- 6. list_onboarding_blockers_r2304
CREATE OR REPLACE FUNCTION public.list_onboarding_blockers_r2304(p_journey_id uuid)
RETURNS TABLE (
  id uuid,
  journey_id uuid,
  customer_label text,
  blocker_category text,
  blocker_severity text,
  detected_on date,
  resolved_on date,
  days_stalled int,
  owner_role text,
  root_cause text,
  remediation_action text,
  prevented_future_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.journey_id, j.customer_label,
         b.blocker_category, b.blocker_severity,
         b.detected_on, b.resolved_on,
         COALESCE(b.days_stalled,
                  CASE WHEN b.resolved_on IS NOT NULL
                       THEN (b.resolved_on - b.detected_on)::int
                       ELSE (CURRENT_DATE - b.detected_on)::int
                  END)::int AS days_stalled,
         b.owner_role, b.root_cause, b.remediation_action,
         b.prevented_future_count, b.created_at
    FROM public.founder_onboarding_blockers_r2304 b
    JOIN public.founder_onboarding_journeys_r2304 j ON j.id = b.journey_id
   WHERE p_journey_id IS NULL OR b.journey_id = p_journey_id
   ORDER BY b.detected_on DESC, b.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_onboarding_blockers_r2304(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_onboarding_blockers_r2304(uuid) TO authenticated;

-- 7. onboarding_latency_summary_r2304 — KPI roll-up + tier + region breakdowns
CREATE OR REPLACE FUNCTION public.onboarding_latency_summary_r2304()
RETURNS TABLE (
  total_journeys int,
  succeeded int,
  in_progress int,
  stalled int,
  at_risk int,
  aborted int,
  on_target_count int,
  breached_count int,
  avg_actual_latency_days numeric,
  median_actual_latency_days numeric,
  p90_actual_latency_days numeric,
  avg_target_latency_days numeric,
  total_blockers int,
  open_blockers int,
  critical_blockers int,
  avg_days_stalled numeric,
  top_blocker_category text,
  worst_tier text,
  worst_region text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_cat text;
  v_worst_tier text;
  v_worst_region text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT b.blocker_category
    INTO v_top_cat
    FROM public.founder_onboarding_blockers_r2304 b
   GROUP BY b.blocker_category
   ORDER BY count(*) DESC
   LIMIT 1;

  SELECT j.customer_tier
    INTO v_worst_tier
    FROM public.founder_onboarding_journeys_r2304 j
   WHERE j.actual_latency_days IS NOT NULL
   GROUP BY j.customer_tier
   ORDER BY avg(j.actual_latency_days) DESC
   LIMIT 1;

  SELECT j.region
    INTO v_worst_region
    FROM public.founder_onboarding_journeys_r2304 j
   WHERE j.actual_latency_days IS NOT NULL
   GROUP BY j.region
   ORDER BY avg(j.actual_latency_days) DESC
   LIMIT 1;

  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE status = 'succeeded'),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE status = 'in_progress'),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE status = 'stalled'),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE status = 'at_risk'),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE status = 'aborted'),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE health_band = 'on_target'),
    (SELECT count(*)::int FROM public.founder_onboarding_journeys_r2304 WHERE health_band IN ('breached','severely_breached')),
    COALESCE((SELECT avg(actual_latency_days) FROM public.founder_onboarding_journeys_r2304 WHERE actual_latency_days IS NOT NULL), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY actual_latency_days) FROM public.founder_onboarding_journeys_r2304 WHERE actual_latency_days IS NOT NULL), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY actual_latency_days) FROM public.founder_onboarding_journeys_r2304 WHERE actual_latency_days IS NOT NULL), 0)::numeric,
    COALESCE((SELECT avg(target_latency_days) FROM public.founder_onboarding_journeys_r2304), 0)::numeric,
    (SELECT count(*)::int FROM public.founder_onboarding_blockers_r2304),
    (SELECT count(*)::int FROM public.founder_onboarding_blockers_r2304 WHERE resolved_on IS NULL),
    (SELECT count(*)::int FROM public.founder_onboarding_blockers_r2304 WHERE blocker_severity = 'critical'),
    COALESCE((SELECT avg(COALESCE(days_stalled,
                                  CASE WHEN resolved_on IS NOT NULL
                                       THEN (resolved_on - detected_on)::int
                                       ELSE (CURRENT_DATE - detected_on)::int END))
                FROM public.founder_onboarding_blockers_r2304), 0)::numeric,
    COALESCE(v_top_cat, '—'),
    COALESCE(v_worst_tier, '—'),
    COALESCE(v_worst_region, '—');
END;
$$;

REVOKE ALL ON FUNCTION public.onboarding_latency_summary_r2304() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.onboarding_latency_summary_r2304() TO authenticated;

COMMIT;
