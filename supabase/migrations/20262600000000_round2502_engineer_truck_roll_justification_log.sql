-- Round r2502: Engineer Truck Roll Justification Log
-- Tracks every engineer site visit (truck roll), classifies reason + avoidability,
-- captures whether phone-fix was attempted, and rolls up to an avoidability analysis.

CREATE TABLE IF NOT EXISTS public.engineer_truck_rolls_r2502 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  rolled_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason_kind text NOT NULL CHECK (reason_kind IN ('diagnosis','repair','install','training','code_red','audit')),
  billable boolean NOT NULL DEFAULT false,
  billed_rupees int NOT NULL DEFAULT 0,
  phone_fix_attempted boolean NOT NULL DEFAULT false,
  phone_fix_minutes int NOT NULL DEFAULT 0,
  avoidability text NOT NULL CHECK (avoidability IN ('unavoidable','marginal','avoidable','preventable_with_better_tools')),
  cost_rupees int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','cancelled','no_show')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.truck_roll_avoidability_analysis_r2502 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_start date NOT NULL,
  period_end date NOT NULL,
  total_rolls int NOT NULL DEFAULT 0,
  avoidable_rolls int NOT NULL DEFAULT 0,
  marginal_rolls int NOT NULL DEFAULT 0,
  unavoidable_rolls int NOT NULL DEFAULT 0,
  total_cost_rupees bigint NOT NULL DEFAULT 0,
  avoidable_cost_rupees bigint NOT NULL DEFAULT 0,
  top_avoidable_reason text,
  kill_plan_md text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_truck_rolls_r2502 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.truck_roll_avoidability_analysis_r2502 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_truck_rolls_r2502;
CREATE POLICY founder_all ON public.engineer_truck_rolls_r2502
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.truck_roll_avoidability_analysis_r2502;
CREATE POLICY founder_all ON public.truck_roll_avoidability_analysis_r2502
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed truck rolls (all enum values pass CHECK)
INSERT INTO public.engineer_truck_rolls_r2502
  (rolled_at, reason_kind, billable, billed_rupees, phone_fix_attempted, phone_fix_minutes, avoidability, cost_rupees, owner_email, status, notes)
VALUES
  ('2026-06-15 10:00:00+05:30'::timestamptz, 'diagnosis', false, 0, true, 12, 'avoidable', 1800, 'ops@equipseva.com', 'completed', 'Could have been resolved via WhatsApp video — engineer agreed post-visit'),
  ('2026-06-16 09:30:00+05:30'::timestamptz, 'repair', true, 4500, false, 0, 'unavoidable', 2200, 'ops@equipseva.com', 'completed', 'Compressor swap — physical hands required'),
  ('2026-06-17 14:00:00+05:30'::timestamptz, 'training', false, 0, false, 0, 'marginal', 1500, 'ops@equipseva.com', 'completed', 'Onboarding new biomed; could pair with another visit'),
  ('2026-06-18 11:00:00+05:30'::timestamptz, 'code_red', true, 6000, true, 8, 'preventable_with_better_tools', 2500, 'ops@equipseva.com', 'completed', 'Remote diagnostic tool would have caught error code earlier'),
  ('2026-06-19 16:00:00+05:30'::timestamptz, 'install', false, 0, false, 0, 'unavoidable', 1900, 'ops@equipseva.com', 'planned', 'New ventilator install scheduled');

INSERT INTO public.truck_roll_avoidability_analysis_r2502
  (period_start, period_end, total_rolls, avoidable_rolls, marginal_rolls, unavoidable_rolls, total_cost_rupees, avoidable_cost_rupees, top_avoidable_reason, kill_plan_md, status, notes)
VALUES
  ('2026-06-01'::date, '2026-06-07'::date, 18, 6, 4, 8, 35000, 11000, 'diagnosis', '- Add WhatsApp video triage step\n- Train Tier-1 on remote diagnostic tool\n- Require phone-fix attempt before dispatching', 'in_progress', 'Week 1 — high diagnostic avoidability'),
  ('2026-06-08'::date, '2026-06-14'::date, 22, 7, 5, 10, 42000, 13000, 'diagnosis', '- Ship remote diagnostic kit to top-5 engineers\n- Codify phone-fix SOP', 'open', 'Week 2 — same pattern; tool rollout pending'),
  ('2026-06-15'::date, '2026-06-21'::date, 20, 4, 6, 10, 38000, 7500, 'training', '- Batch training visits with nearby repair runs\n- Use video for refresher training', 'open', 'Week 3 — diagnosis dropping, training emerging');

-- RPC 1: list truck rolls
CREATE OR REPLACE FUNCTION public.list_truck_rolls_r2502()
RETURNS SETOF public.engineer_truck_rolls_r2502
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_truck_rolls_r2502 ORDER BY rolled_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_truck_rolls_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_truck_rolls_r2502() TO authenticated;

-- RPC 2: list avoidability analysis
CREATE OR REPLACE FUNCTION public.list_avoidability_analysis_r2502()
RETURNS SETOF public.truck_roll_avoidability_analysis_r2502
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.truck_roll_avoidability_analysis_r2502 ORDER BY period_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_avoidability_analysis_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_avoidability_analysis_r2502() TO authenticated;

-- RPC 3: top avoidable engineers
CREATE OR REPLACE FUNCTION public.top_avoidable_engineers_r2502()
RETURNS TABLE(engineer_user_id uuid, avoidable_count bigint, avoidable_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.engineer_user_id,
      count(*)::bigint,
      sum(t.cost_rupees)::bigint
    FROM public.engineer_truck_rolls_r2502 t
    WHERE t.avoidability IN ('avoidable','preventable_with_better_tools')
    GROUP BY t.engineer_user_id
    ORDER BY count(*) DESC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_avoidable_engineers_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_avoidable_engineers_r2502() TO authenticated;

-- RPC 4: reason kind breakdown
CREATE OR REPLACE FUNCTION public.reason_kind_breakdown_r2502()
RETURNS TABLE(reason_kind text, roll_count bigint, total_cost bigint, avoidable_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.reason_kind,
      count(*)::bigint,
      sum(t.cost_rupees)::bigint,
      count(*) FILTER (WHERE t.avoidability IN ('avoidable','preventable_with_better_tools'))::bigint
    FROM public.engineer_truck_rolls_r2502 t
    GROUP BY t.reason_kind
    ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.reason_kind_breakdown_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reason_kind_breakdown_r2502() TO authenticated;

-- RPC 5: weekly avoidable trend
CREATE OR REPLACE FUNCTION public.weekly_avoidable_trend_r2502()
RETURNS TABLE(week_start date, total_rolls bigint, avoidable_rolls bigint, avoidable_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      date_trunc('week', t.rolled_at)::date AS week_start,
      count(*)::bigint,
      count(*) FILTER (WHERE t.avoidability IN ('avoidable','preventable_with_better_tools'))::bigint,
      sum(t.cost_rupees) FILTER (WHERE t.avoidability IN ('avoidable','preventable_with_better_tools'))::bigint
    FROM public.engineer_truck_rolls_r2502 t
    GROUP BY 1
    ORDER BY 1 DESC
    LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_avoidable_trend_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_avoidable_trend_r2502() TO authenticated;

-- RPC 6: top avoidable hospitals
CREATE OR REPLACE FUNCTION public.top_avoidable_hospitals_r2502()
RETURNS TABLE(hospital_user_id uuid, avoidable_count bigint, avoidable_cost bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.hospital_user_id,
      count(*)::bigint,
      sum(t.cost_rupees)::bigint
    FROM public.engineer_truck_rolls_r2502 t
    WHERE t.avoidability IN ('avoidable','preventable_with_better_tools')
    GROUP BY t.hospital_user_id
    ORDER BY count(*) DESC
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_avoidable_hospitals_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_avoidable_hospitals_r2502() TO authenticated;

-- RPC 7: phone fix success rate
CREATE OR REPLACE FUNCTION public.phone_fix_success_rate_r2502()
RETURNS TABLE(total_rolls bigint, phone_attempted bigint, phone_attempted_pct numeric, avg_phone_minutes numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      count(*)::bigint,
      count(*) FILTER (WHERE t.phone_fix_attempted)::bigint,
      ROUND(
        100.0 * count(*) FILTER (WHERE t.phone_fix_attempted) / NULLIF(count(*),0),
        2
      )::numeric,
      ROUND(AVG(t.phone_fix_minutes) FILTER (WHERE t.phone_fix_attempted), 2)::numeric
    FROM public.engineer_truck_rolls_r2502 t;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.phone_fix_success_rate_r2502() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.phone_fix_success_rate_r2502() TO authenticated;
