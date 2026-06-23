BEGIN;

-- Round 2401: Founder weekly time-allocation tracker
-- Track where founder time went each week (customers/team/strategy/admin)
-- vs ideal allocation, with variance flags + coaching notes.

CREATE TABLE IF NOT EXISTS public.founder_time_weeks_r2401 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_start date NOT NULL,
  week_end date NOT NULL,
  total_hours_logged numeric(6,2) NOT NULL DEFAULT 0,
  customer_hours numeric(6,2) NOT NULL DEFAULT 0,
  team_hours numeric(6,2) NOT NULL DEFAULT 0,
  strategy_hours numeric(6,2) NOT NULL DEFAULT 0,
  admin_hours numeric(6,2) NOT NULL DEFAULT 0,
  ideal_customer_pct numeric(5,2) NOT NULL DEFAULT 40.00,
  ideal_team_pct numeric(5,2) NOT NULL DEFAULT 25.00,
  ideal_strategy_pct numeric(5,2) NOT NULL DEFAULT 25.00,
  ideal_admin_pct numeric(5,2) NOT NULL DEFAULT 10.00,
  variance_flag text NOT NULL DEFAULT 'on_track' CHECK (variance_flag IN ('on_track','admin_overload','strategy_starved','customer_starved','team_starved')),
  coaching_note text,
  reviewed_by_coach boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (founder_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_ftw_r2401_week ON public.founder_time_weeks_r2401 (week_start DESC);
CREATE INDEX IF NOT EXISTS idx_ftw_r2401_variance ON public.founder_time_weeks_r2401 (variance_flag, week_start DESC);

CREATE TABLE IF NOT EXISTS public.founder_time_entries_r2401 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_id uuid NOT NULL REFERENCES public.founder_time_weeks_r2401(id) ON DELETE CASCADE,
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  logged_on date NOT NULL,
  bucket text NOT NULL CHECK (bucket IN ('customer','team','strategy','admin')),
  activity_label text NOT NULL,
  hours numeric(5,2) NOT NULL CHECK (hours > 0 AND hours <= 24),
  related_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fte_r2401_week ON public.founder_time_entries_r2401 (week_id);
CREATE INDEX IF NOT EXISTS idx_fte_r2401_bucket ON public.founder_time_entries_r2401 (bucket, logged_on DESC);

ALTER TABLE public.founder_time_weeks_r2401 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_time_entries_r2401 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_time_weeks_r2401;
CREATE POLICY founder_all ON public.founder_time_weeks_r2401 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_time_entries_r2401;
CREATE POLICY founder_all ON public.founder_time_entries_r2401 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: weekly summary list with computed actual percentages + gap to ideal
DROP FUNCTION IF EXISTS public.founder_time_weeks_list_r2401(int);
CREATE FUNCTION public.founder_time_weeks_list_r2401(p_limit int DEFAULT 26)
RETURNS TABLE (
  id uuid,
  week_start date,
  week_end date,
  total_hours numeric,
  customer_pct numeric,
  team_pct numeric,
  strategy_pct numeric,
  admin_pct numeric,
  ideal_customer_pct numeric,
  ideal_team_pct numeric,
  ideal_strategy_pct numeric,
  ideal_admin_pct numeric,
  customer_gap numeric,
  team_gap numeric,
  strategy_gap numeric,
  admin_gap numeric,
  variance_flag text,
  reviewed_by_coach boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    w.id,
    w.week_start,
    w.week_end,
    w.total_hours_logged,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.customer_hours / w.total_hours_logged * 100, 1) ELSE 0 END,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.team_hours / w.total_hours_logged * 100, 1) ELSE 0 END,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.strategy_hours / w.total_hours_logged * 100, 1) ELSE 0 END,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.admin_hours / w.total_hours_logged * 100, 1) ELSE 0 END,
    w.ideal_customer_pct,
    w.ideal_team_pct,
    w.ideal_strategy_pct,
    w.ideal_admin_pct,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.customer_hours / w.total_hours_logged * 100 - w.ideal_customer_pct, 1) ELSE -w.ideal_customer_pct END,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.team_hours / w.total_hours_logged * 100 - w.ideal_team_pct, 1) ELSE -w.ideal_team_pct END,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.strategy_hours / w.total_hours_logged * 100 - w.ideal_strategy_pct, 1) ELSE -w.ideal_strategy_pct END,
    CASE WHEN w.total_hours_logged > 0 THEN ROUND(w.admin_hours / w.total_hours_logged * 100 - w.ideal_admin_pct, 1) ELSE -w.ideal_admin_pct END,
    w.variance_flag,
    w.reviewed_by_coach
  FROM public.founder_time_weeks_r2401 w
  ORDER BY w.week_start DESC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_weeks_list_r2401(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_weeks_list_r2401(int) TO authenticated;

-- RPC 2: bucket totals across last N weeks
DROP FUNCTION IF EXISTS public.founder_time_bucket_rollup_r2401(int);
CREATE FUNCTION public.founder_time_bucket_rollup_r2401(p_weeks int DEFAULT 12)
RETURNS TABLE (
  bucket text,
  total_hours numeric,
  share_pct numeric,
  ideal_pct numeric,
  gap_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_total numeric;
  v_cust numeric; v_team numeric; v_strat numeric; v_admin numeric;
  v_icust numeric; v_iteam numeric; v_istrat numeric; v_iadmin numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT
    COALESCE(SUM(total_hours_logged),0),
    COALESCE(SUM(customer_hours),0),
    COALESCE(SUM(team_hours),0),
    COALESCE(SUM(strategy_hours),0),
    COALESCE(SUM(admin_hours),0),
    COALESCE(AVG(ideal_customer_pct),40),
    COALESCE(AVG(ideal_team_pct),25),
    COALESCE(AVG(ideal_strategy_pct),25),
    COALESCE(AVG(ideal_admin_pct),10)
  INTO v_total, v_cust, v_team, v_strat, v_admin, v_icust, v_iteam, v_istrat, v_iadmin
  FROM public.founder_time_weeks_r2401
  WHERE week_start >= (current_date - (p_weeks * 7));

  RETURN QUERY
  SELECT 'customer'::text, v_cust,
    CASE WHEN v_total > 0 THEN ROUND(v_cust/v_total*100,1) ELSE 0 END,
    v_icust,
    CASE WHEN v_total > 0 THEN ROUND(v_cust/v_total*100 - v_icust,1) ELSE -v_icust END
  UNION ALL
  SELECT 'team', v_team,
    CASE WHEN v_total > 0 THEN ROUND(v_team/v_total*100,1) ELSE 0 END,
    v_iteam,
    CASE WHEN v_total > 0 THEN ROUND(v_team/v_total*100 - v_iteam,1) ELSE -v_iteam END
  UNION ALL
  SELECT 'strategy', v_strat,
    CASE WHEN v_total > 0 THEN ROUND(v_strat/v_total*100,1) ELSE 0 END,
    v_istrat,
    CASE WHEN v_total > 0 THEN ROUND(v_strat/v_total*100 - v_istrat,1) ELSE -v_istrat END
  UNION ALL
  SELECT 'admin', v_admin,
    CASE WHEN v_total > 0 THEN ROUND(v_admin/v_total*100,1) ELSE 0 END,
    v_iadmin,
    CASE WHEN v_total > 0 THEN ROUND(v_admin/v_total*100 - v_iadmin,1) ELSE -v_iadmin END;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_bucket_rollup_r2401(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_bucket_rollup_r2401(int) TO authenticated;

-- RPC 3: latest week entries (drill into where time went)
DROP FUNCTION IF EXISTS public.founder_time_entries_recent_r2401(int);
CREATE FUNCTION public.founder_time_entries_recent_r2401(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  logged_on date,
  bucket text,
  activity_label text,
  hours numeric,
  related_org text,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.logged_on,
    e.bucket,
    e.activity_label,
    e.hours,
    o.name,
    e.notes
  FROM public.founder_time_entries_r2401 e
  LEFT JOIN public.organizations o ON o.id = e.related_org_id
  ORDER BY e.logged_on DESC, e.created_at DESC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_entries_recent_r2401(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_entries_recent_r2401(int) TO authenticated;

-- RPC 4: variance flag breakdown
DROP FUNCTION IF EXISTS public.founder_time_variance_summary_r2401();
CREATE FUNCTION public.founder_time_variance_summary_r2401()
RETURNS TABLE (
  variance_flag text,
  week_count int,
  pct_of_weeks numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.founder_time_weeks_r2401;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT
    w.variance_flag,
    COUNT(*)::int,
    ROUND(COUNT(*)::numeric / v_total * 100, 1)
  FROM public.founder_time_weeks_r2401 w
  GROUP BY w.variance_flag
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_variance_summary_r2401() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_variance_summary_r2401() TO authenticated;

-- RPC 5: log a time entry (also updates week totals + variance flag)
DROP FUNCTION IF EXISTS public.founder_time_entry_log_r2401(date, text, text, numeric, uuid, text);
CREATE FUNCTION public.founder_time_entry_log_r2401(
  p_logged_on date,
  p_bucket text,
  p_activity_label text,
  p_hours numeric,
  p_related_org_id uuid,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_week_start date;
  v_week_end date;
  v_week_id uuid;
  v_entry_id uuid;
  v_founder uuid;
  v_total numeric; v_c numeric; v_t numeric; v_s numeric; v_a numeric;
  v_ic numeric; v_it numeric; v_is numeric; v_ia numeric;
  v_flag text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_bucket NOT IN ('customer','team','strategy','admin') THEN RAISE EXCEPTION 'bad_bucket'; END IF;
  IF p_hours <= 0 OR p_hours > 24 THEN RAISE EXCEPTION 'bad_hours'; END IF;

  SELECT id INTO v_founder FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;
  IF v_founder IS NULL THEN RAISE EXCEPTION 'no_profile'; END IF;

  v_week_start := date_trunc('week', p_logged_on)::date;
  v_week_end := v_week_start + 6;

  INSERT INTO public.founder_time_weeks_r2401 (founder_id, week_start, week_end)
  VALUES (v_founder, v_week_start, v_week_end)
  ON CONFLICT (founder_id, week_start) DO UPDATE SET updated_at = now()
  RETURNING id INTO v_week_id;

  INSERT INTO public.founder_time_entries_r2401 (week_id, founder_id, logged_on, bucket, activity_label, hours, related_org_id, notes)
  VALUES (v_week_id, v_founder, p_logged_on, p_bucket, p_activity_label, p_hours, p_related_org_id, p_notes)
  RETURNING id INTO v_entry_id;

  -- recompute week totals
  SELECT
    COALESCE(SUM(hours),0),
    COALESCE(SUM(hours) FILTER (WHERE bucket='customer'),0),
    COALESCE(SUM(hours) FILTER (WHERE bucket='team'),0),
    COALESCE(SUM(hours) FILTER (WHERE bucket='strategy'),0),
    COALESCE(SUM(hours) FILTER (WHERE bucket='admin'),0)
  INTO v_total, v_c, v_t, v_s, v_a
  FROM public.founder_time_entries_r2401 WHERE week_id = v_week_id;

  SELECT ideal_customer_pct, ideal_team_pct, ideal_strategy_pct, ideal_admin_pct
  INTO v_ic, v_it, v_is, v_ia
  FROM public.founder_time_weeks_r2401 WHERE id = v_week_id;

  -- determine variance flag
  v_flag := 'on_track';
  IF v_total > 0 THEN
    IF (v_a / v_total * 100) > (v_ia + 15) THEN v_flag := 'admin_overload';
    ELSIF (v_s / v_total * 100) < (v_is - 15) THEN v_flag := 'strategy_starved';
    ELSIF (v_c / v_total * 100) < (v_ic - 15) THEN v_flag := 'customer_starved';
    ELSIF (v_t / v_total * 100) < (v_it - 15) THEN v_flag := 'team_starved';
    END IF;
  END IF;

  UPDATE public.founder_time_weeks_r2401
  SET total_hours_logged = v_total,
      customer_hours = v_c,
      team_hours = v_t,
      strategy_hours = v_s,
      admin_hours = v_a,
      variance_flag = v_flag,
      updated_at = now()
  WHERE id = v_week_id;

  RETURN v_entry_id;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_entry_log_r2401(date, text, text, numeric, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_entry_log_r2401(date, text, text, numeric, uuid, text) TO authenticated;

-- RPC 6: set coaching note + mark reviewed
DROP FUNCTION IF EXISTS public.founder_time_week_coach_note_r2401(uuid, text, boolean);
CREATE FUNCTION public.founder_time_week_coach_note_r2401(
  p_week_id uuid,
  p_note text,
  p_reviewed boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_time_weeks_r2401
  SET coaching_note = p_note,
      reviewed_by_coach = p_reviewed,
      updated_at = now()
  WHERE id = p_week_id;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_week_coach_note_r2401(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_week_coach_note_r2401(uuid, text, boolean) TO authenticated;

-- RPC 7: top activity labels by hours
DROP FUNCTION IF EXISTS public.founder_time_top_activities_r2401(int);
CREATE FUNCTION public.founder_time_top_activities_r2401(p_limit int DEFAULT 15)
RETURNS TABLE (
  activity_label text,
  bucket text,
  total_hours numeric,
  entry_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.activity_label,
    e.bucket,
    SUM(e.hours),
    COUNT(*)::int
  FROM public.founder_time_entries_r2401 e
  GROUP BY e.activity_label, e.bucket
  ORDER BY SUM(e.hours) DESC
  LIMIT p_limit;
END $$;
REVOKE ALL ON FUNCTION public.founder_time_top_activities_r2401(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_time_top_activities_r2401(int) TO authenticated;

COMMIT;
