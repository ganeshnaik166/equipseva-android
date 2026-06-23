-- Round 2566: engineer rest-day rotation tracker
-- engineer x planned rest day x actual taken x debt x recovery rate x wellbeing impact

BEGIN;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_rest_day_rotation_r2566 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  rest_planned_date date NOT NULL,
  rest_actual_taken boolean NOT NULL DEFAULT false,
  rest_debt_days int NOT NULL DEFAULT 0,
  wellbeing_score int CHECK (wellbeing_score IS NULL OR (wellbeing_score >= 0 AND wellbeing_score <= 10)),
  recovery_rate_pct numeric(5,2),
  top_reason_skipped text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','taken','skipped','debt_carry')),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_rest_rotation_r2566_planned ON public.engineer_rest_day_rotation_r2566(rest_planned_date DESC);
CREATE INDEX IF NOT EXISTS idx_rest_rotation_r2566_eng ON public.engineer_rest_day_rotation_r2566(engineer_user_id);

CREATE TABLE IF NOT EXISTS public.rest_debt_recovery_actions_r2566 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  rotation_id uuid REFERENCES public.engineer_rest_day_rotation_r2566(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('mandatory_off','comp_off_grant','load_reduce','manager_check')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_rest_recovery_r2566_rot ON public.rest_debt_recovery_actions_r2566(rotation_id);
CREATE INDEX IF NOT EXISTS idx_rest_recovery_r2566_at ON public.rest_debt_recovery_actions_r2566(action_at DESC);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.engineer_rest_day_rotation_r2566 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rest_debt_recovery_actions_r2566 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_rest_day_rotation_r2566;
CREATE POLICY founder_all ON public.engineer_rest_day_rotation_r2566
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.rest_debt_recovery_actions_r2566;
CREATE POLICY founder_all ON public.rest_debt_recovery_actions_r2566
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEEDS (3-5 rows each)
-- ============================================================

INSERT INTO public.engineer_rest_day_rotation_r2566
  (rest_planned_date, rest_actual_taken, rest_debt_days, wellbeing_score, recovery_rate_pct, top_reason_skipped, owner_email, status, notes)
VALUES
  ('2026-06-15', true,  0, 8, 92.50, NULL,                    'ops@equipseva.in',    'taken',      'Full rest day taken'),
  ('2026-06-16', false, 1, 5, 60.00, 'P1 incident escalation','ops@equipseva.in',    'skipped',    'On-call carry-in'),
  ('2026-06-17', false, 2, 4, 45.00, 'AMC quarterly visit',   'manager@equipseva.in','debt_carry', 'Two consecutive skips'),
  ('2026-06-20', true,  0, 7, 80.00, NULL,                    'ops@equipseva.in',    'taken',      'Comp-off honored'),
  ('2026-06-22', false, 0, 6, 70.00, 'Hospital chain demo',   'founder@equipseva.in','planned',    'Will be rescheduled');

INSERT INTO public.rest_debt_recovery_actions_r2566
  (rotation_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '2 days', 'mandatory_off',  'positive', 'ops@equipseva.in',     'done', 'Forced off after 2-day debt'
FROM public.engineer_rest_day_rotation_r2566 WHERE status = 'debt_carry' LIMIT 1;

INSERT INTO public.rest_debt_recovery_actions_r2566
  (rotation_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now() - interval '1 day', 'comp_off_grant', 'positive', 'manager@equipseva.in', 'done', 'Comp-off booked for next week'
FROM public.engineer_rest_day_rotation_r2566 WHERE status = 'skipped' LIMIT 1;

INSERT INTO public.rest_debt_recovery_actions_r2566
  (rotation_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now(), 'load_reduce', 'pending', 'ops@equipseva.in', 'open', 'Removing 2 AMC visits this week'
FROM public.engineer_rest_day_rotation_r2566 WHERE status = 'debt_carry' LIMIT 1;

INSERT INTO public.rest_debt_recovery_actions_r2566
  (rotation_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, now(), 'manager_check', 'neutral', 'founder@equipseva.in', 'open', 'Manager 1:1 scheduled'
FROM public.engineer_rest_day_rotation_r2566 WHERE status = 'planned' LIMIT 1;

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_rotation_r2566()
RETURNS SETOF public.engineer_rest_day_rotation_r2566
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_rest_day_rotation_r2566 ORDER BY rest_planned_date DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_rotation_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_rotation_r2566() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2566()
RETURNS SETOF public.rest_debt_recovery_actions_r2566
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.rest_debt_recovery_actions_r2566 ORDER BY action_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2566() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_debt_engineers_r2566()
RETURNS TABLE(engineer_user_id uuid, total_debt_days bigint, skipped_count bigint, avg_wellbeing numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_user_id,
         COALESCE(SUM(r.rest_debt_days),0)::bigint,
         COUNT(*) FILTER (WHERE r.status IN ('skipped','debt_carry'))::bigint,
         ROUND(AVG(r.wellbeing_score)::numeric, 2)
  FROM public.engineer_rest_day_rotation_r2566 r
  GROUP BY r.engineer_user_id
  ORDER BY COALESCE(SUM(r.rest_debt_days),0) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_debt_engineers_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_debt_engineers_r2566() TO authenticated;

CREATE OR REPLACE FUNCTION public.wellbeing_distribution_r2566()
RETURNS TABLE(bucket text, n bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT CASE
           WHEN wellbeing_score IS NULL THEN 'unknown'
           WHEN wellbeing_score >= 8 THEN 'high (8-10)'
           WHEN wellbeing_score >= 5 THEN 'mid (5-7)'
           ELSE 'low (0-4)'
         END AS bucket,
         COUNT(*)::bigint
  FROM public.engineer_rest_day_rotation_r2566
  GROUP BY 1
  ORDER BY 1 ASC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.wellbeing_distribution_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wellbeing_distribution_r2566() TO authenticated;

CREATE OR REPLACE FUNCTION public.recovery_rate_trend_r2566()
RETURNS TABLE(week_start date, avg_recovery_pct numeric, taken_count bigint, skipped_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', rest_planned_date)::date AS week_start,
         ROUND(AVG(recovery_rate_pct)::numeric, 2),
         COUNT(*) FILTER (WHERE rest_actual_taken)::bigint,
         COUNT(*) FILTER (WHERE NOT rest_actual_taken)::bigint
  FROM public.engineer_rest_day_rotation_r2566
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.recovery_rate_trend_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recovery_rate_trend_r2566() TO authenticated;

CREATE OR REPLACE FUNCTION public.skipped_reason_breakdown_r2566()
RETURNS TABLE(top_reason_skipped text, n bigint, total_debt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.top_reason_skipped, 'unspecified'),
         COUNT(*)::bigint,
         COALESCE(SUM(r.rest_debt_days),0)::bigint
  FROM public.engineer_rest_day_rotation_r2566 r
  WHERE r.status IN ('skipped','debt_carry')
  GROUP BY 1
  ORDER BY COUNT(*) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.skipped_reason_breakdown_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.skipped_reason_breakdown_r2566() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2566()
RETURNS TABLE(owner_email text, rotations_owned bigint, actions_open bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(r.owner_email, 'unassigned') AS owner_email,
         COUNT(DISTINCT r.id)::bigint,
         COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'open')::bigint
  FROM public.engineer_rest_day_rotation_r2566 r
  LEFT JOIN public.rest_debt_recovery_actions_r2566 a ON a.owner_email = r.owner_email
  GROUP BY 1
  ORDER BY COUNT(DISTINCT r.id) DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2566() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2566() TO authenticated;

