BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_time_on_task_daily_r2498 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  day date NOT NULL,
  drive_hours numeric NOT NULL DEFAULT 0 CHECK (drive_hours >= 0),
  repair_hours numeric NOT NULL DEFAULT 0 CHECK (repair_hours >= 0),
  admin_hours numeric NOT NULL DEFAULT 0 CHECK (admin_hours >= 0),
  wait_hours numeric NOT NULL DEFAULT 0 CHECK (wait_hours >= 0),
  idle_hours numeric NOT NULL DEFAULT 0 CHECK (idle_hours >= 0),
  training_hours numeric NOT NULL DEFAULT 0 CHECK (training_hours >= 0),
  billable_hours numeric NOT NULL DEFAULT 0 CHECK (billable_hours >= 0),
  non_billable_pct numeric NOT NULL DEFAULT 0 CHECK (non_billable_pct >= 0 AND non_billable_pct <= 100),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.time_distribution_insights_r2498 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  insight_kind text NOT NULL CHECK (insight_kind IN ('high_drive','high_admin','high_idle','balanced','high_training')),
  observed_engineer_user_id uuid NOT NULL,
  period_start date NOT NULL,
  period_end date NOT NULL,
  observed_pct numeric NOT NULL DEFAULT 0 CHECK (observed_pct >= 0 AND observed_pct <= 100),
  target_pct numeric NOT NULL DEFAULT 0 CHECK (target_pct >= 0 AND target_pct <= 100),
  action_md text NOT NULL DEFAULT '',
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_time_on_task_daily_r2498 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_distribution_insights_r2498 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_time_on_task_daily_r2498;
CREATE POLICY founder_all ON public.engineer_time_on_task_daily_r2498
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.time_distribution_insights_r2498;
CREATE POLICY founder_all ON public.time_distribution_insights_r2498
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed daily time-on-task rows
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
BEGIN
  SELECT user_id INTO v_eng1 FROM public.engineers WHERE user_id IS NOT NULL ORDER BY created_at ASC LIMIT 1;
  SELECT user_id INTO v_eng2 FROM public.engineers WHERE user_id IS NOT NULL AND user_id <> v_eng1 ORDER BY created_at ASC LIMIT 1;
  SELECT user_id INTO v_eng3 FROM public.engineers WHERE user_id IS NOT NULL AND user_id NOT IN (COALESCE(v_eng1, gen_random_uuid()), COALESCE(v_eng2, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;

  IF v_eng1 IS NULL THEN v_eng1 := gen_random_uuid(); END IF;
  IF v_eng2 IS NULL THEN v_eng2 := gen_random_uuid(); END IF;
  IF v_eng3 IS NULL THEN v_eng3 := gen_random_uuid(); END IF;

  INSERT INTO public.engineer_time_on_task_daily_r2498
    (engineer_user_id, day, drive_hours, repair_hours, admin_hours, wait_hours, idle_hours, training_hours, billable_hours, non_billable_pct, notes)
  VALUES
    (v_eng1, '2026-06-15'::date, 3.5, 4.0, 0.5, 0.5, 0.0, 0.0, 4.0, 50.0, 'long drive to Karimnagar'),
    (v_eng1, '2026-06-16'::date, 1.5, 5.5, 1.0, 0.0, 0.0, 0.0, 5.5, 31.25, 'city day, dense schedule'),
    (v_eng2, '2026-06-15'::date, 2.0, 3.0, 0.5, 1.0, 1.5, 0.0, 3.0, 62.5, 'waited for spare delivery'),
    (v_eng2, '2026-06-16'::date, 1.0, 2.0, 0.5, 0.5, 0.0, 4.0, 2.0, 75.0, 'CAS training afternoon'),
    (v_eng3, '2026-06-16'::date, 2.5, 4.5, 1.0, 0.0, 0.0, 0.0, 4.5, 43.75, 'balanced day')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.time_distribution_insights_r2498
    (insight_kind, observed_engineer_user_id, period_start, period_end, observed_pct, target_pct, action_md, owner_email, status, notes)
  VALUES
    ('high_drive', v_eng1, '2026-06-15'::date, '2026-06-16'::date, 31.25, 20.0, 'Rebalance route: cluster Karimnagar jobs to one trip per week', 'ops@equipseva.com', 'open', 'driver waste cost ~Rs 600/day'),
    ('high_idle', v_eng2, '2026-06-15'::date, '2026-06-15'::date, 18.75, 5.0, 'Pre-confirm spare ETA before dispatch', 'ops@equipseva.com', 'in_progress', 'spare wait killed 1.5h'),
    ('high_training', v_eng2, '2026-06-16'::date, '2026-06-16'::date, 50.0, 10.0, 'Training is good but schedule on Saturdays not weekday peak', 'l_d@equipseva.com', 'open', 'CAS cert push'),
    ('balanced', v_eng3, '2026-06-16'::date, '2026-06-16'::date, 56.25, 60.0, 'Sustain — engineer is well-routed', 'ops@equipseva.com', 'done', 'use as benchmark'),
    ('high_admin', v_eng1, '2026-06-16'::date, '2026-06-16'::date, 12.5, 5.0, 'Move invoice prep to ops desk; engineer should not key in GST line items', 'ops@equipseva.com', 'open', 'admin creep')
  ON CONFLICT DO NOTHING;
END
$seed$;

-- RPC 1: list_time_distribution
CREATE OR REPLACE FUNCTION public.list_time_distribution_r2498()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  day date,
  drive_hours numeric,
  repair_hours numeric,
  admin_hours numeric,
  wait_hours numeric,
  idle_hours numeric,
  training_hours numeric,
  billable_hours numeric,
  non_billable_pct numeric,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, p.email::text, d.day,
    d.drive_hours, d.repair_hours, d.admin_hours, d.wait_hours, d.idle_hours, d.training_hours,
    d.billable_hours, d.non_billable_pct, d.notes, d.created_at
  FROM public.engineer_time_on_task_daily_r2498 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  ORDER BY d.day DESC, p.email ASC NULLS LAST;
END;
$$;

-- RPC 2: list_insights
CREATE OR REPLACE FUNCTION public.list_insights_r2498()
RETURNS TABLE (
  id uuid,
  insight_kind text,
  observed_engineer_user_id uuid,
  engineer_email text,
  period_start date,
  period_end date,
  observed_pct numeric,
  target_pct numeric,
  action_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.insight_kind, i.observed_engineer_user_id, p.email::text,
    i.period_start, i.period_end, i.observed_pct, i.target_pct,
    i.action_md, i.owner_email, i.status, i.notes, i.created_at
  FROM public.time_distribution_insights_r2498 i
  LEFT JOIN public.profiles p ON p.id = i.observed_engineer_user_id
  ORDER BY i.period_end DESC, i.observed_pct DESC;
END;
$$;

-- RPC 3: top_non_billable_engineers
CREATE OR REPLACE FUNCTION public.top_non_billable_engineers_r2498()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  days_logged int,
  avg_non_billable_pct numeric,
  total_idle_hours numeric,
  total_wait_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.engineer_user_id,
    p.email::text AS engineer_email,
    (COUNT(*))::int AS days_logged,
    ROUND(AVG(d.non_billable_pct), 2) AS avg_non_billable_pct,
    ROUND(SUM(d.idle_hours), 2) AS total_idle_hours,
    ROUND(SUM(d.wait_hours), 2) AS total_wait_hours
  FROM public.engineer_time_on_task_daily_r2498 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  GROUP BY d.engineer_user_id, p.email
  ORDER BY avg_non_billable_pct DESC
  LIMIT 25;
END;
$$;

-- RPC 4: weekly_drive_trend
CREATE OR REPLACE FUNCTION public.weekly_drive_trend_r2498()
RETURNS TABLE (
  week_start date,
  total_drive_hours numeric,
  total_repair_hours numeric,
  drive_share_pct numeric,
  days_logged int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', d.day)::date AS week_start,
    ROUND(SUM(d.drive_hours), 2) AS total_drive_hours,
    ROUND(SUM(d.repair_hours), 2) AS total_repair_hours,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.drive_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS drive_share_pct,
    (COUNT(*))::int AS days_logged
  FROM public.engineer_time_on_task_daily_r2498 d
  GROUP BY date_trunc('week', d.day)
  ORDER BY week_start DESC;
END;
$$;

-- RPC 5: billable_vs_non_billable_summary
CREATE OR REPLACE FUNCTION public.billable_vs_non_billable_summary_r2498()
RETURNS TABLE (
  days_logged int,
  total_billable_hours numeric,
  total_non_billable_hours numeric,
  avg_non_billable_pct numeric,
  worst_day date,
  worst_day_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_worst_day date;
  v_worst_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT d.day, d.non_billable_pct
    INTO v_worst_day, v_worst_pct
  FROM public.engineer_time_on_task_daily_r2498 d
  ORDER BY d.non_billable_pct DESC, d.day DESC
  LIMIT 1;

  RETURN QUERY
  SELECT (COUNT(*))::int AS days_logged,
    ROUND(SUM(d.billable_hours), 2) AS total_billable_hours,
    ROUND(SUM(d.drive_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours), 2) AS total_non_billable_hours,
    ROUND(AVG(d.non_billable_pct), 2) AS avg_non_billable_pct,
    v_worst_day AS worst_day,
    COALESCE(v_worst_pct, 0) AS worst_day_pct
  FROM public.engineer_time_on_task_daily_r2498 d;
END;
$$;

-- RPC 6: engineer_distribution_heatmap
CREATE OR REPLACE FUNCTION public.engineer_distribution_heatmap_r2498()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  drive_pct numeric,
  repair_pct numeric,
  admin_pct numeric,
  wait_pct numeric,
  idle_pct numeric,
  training_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.engineer_user_id,
    p.email::text AS engineer_email,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.drive_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS drive_pct,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.repair_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS repair_pct,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.admin_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS admin_pct,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.wait_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS wait_pct,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.idle_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS idle_pct,
    CASE WHEN SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours) = 0 THEN 0
      ELSE ROUND((SUM(d.training_hours)::numeric /
        SUM(d.drive_hours + d.repair_hours + d.admin_hours + d.wait_hours + d.idle_hours + d.training_hours)::numeric) * 100, 2)
    END AS training_pct
  FROM public.engineer_time_on_task_daily_r2498 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  GROUP BY d.engineer_user_id, p.email
  ORDER BY repair_pct ASC;
END;
$$;

-- RPC 7: top_idle_focus
CREATE OR REPLACE FUNCTION public.top_idle_focus_r2498()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  day date,
  idle_hours numeric,
  wait_hours numeric,
  non_billable_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.engineer_user_id, p.email::text, d.day,
    d.idle_hours, d.wait_hours, d.non_billable_pct, d.notes
  FROM public.engineer_time_on_task_daily_r2498 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  WHERE (d.idle_hours + d.wait_hours) > 0
  ORDER BY (d.idle_hours + d.wait_hours) DESC, d.non_billable_pct DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_time_distribution_r2498() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_insights_r2498() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_non_billable_engineers_r2498() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.weekly_drive_trend_r2498() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.billable_vs_non_billable_summary_r2498() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.engineer_distribution_heatmap_r2498() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_idle_focus_r2498() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_time_distribution_r2498() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_insights_r2498() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_non_billable_engineers_r2498() TO authenticated;
GRANT EXECUTE ON FUNCTION public.weekly_drive_trend_r2498() TO authenticated;
GRANT EXECUTE ON FUNCTION public.billable_vs_non_billable_summary_r2498() TO authenticated;
GRANT EXECUTE ON FUNCTION public.engineer_distribution_heatmap_r2498() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_idle_focus_r2498() TO authenticated;

