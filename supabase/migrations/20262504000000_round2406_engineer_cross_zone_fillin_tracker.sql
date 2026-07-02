BEGIN;

-- =========================================================================
-- r2406 — Engineer cross-zone fill-in tracker
-- When an engineer fills in for an absent peer in another zone, log the
-- assignment, billable rate uplift, fatigue indicator, and fair-comp payout.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_cross_zone_fillins_r2406 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  absent_engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  home_zone text NOT NULL,
  fillin_zone text NOT NULL,
  fillin_date date NOT NULL,
  jobs_covered integer NOT NULL DEFAULT 0 CHECK (jobs_covered >= 0),
  hours_worked numeric(6,2) NOT NULL DEFAULT 0 CHECK (hours_worked >= 0),
  travel_km numeric(8,2) NOT NULL DEFAULT 0 CHECK (travel_km >= 0),
  base_rate_rupees integer NOT NULL DEFAULT 0 CHECK (base_rate_rupees >= 0),
  cross_zone_uplift_pct numeric(5,2) NOT NULL DEFAULT 25.00 CHECK (cross_zone_uplift_pct >= 0),
  billable_amount_rupees integer NOT NULL DEFAULT 0 CHECK (billable_amount_rupees >= 0),
  fair_comp_rupees integer NOT NULL DEFAULT 0 CHECK (fair_comp_rupees >= 0),
  fatigue_score integer NOT NULL DEFAULT 0 CHECK (fatigue_score BETWEEN 0 AND 100),
  fatigue_flag text NOT NULL DEFAULT 'ok' CHECK (fatigue_flag IN ('ok','watch','high','critical')),
  consecutive_fillin_days integer NOT NULL DEFAULT 1 CHECK (consecutive_fillin_days >= 1),
  status text NOT NULL DEFAULT 'logged' CHECK (status IN ('logged','approved','paid','disputed','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xzone_fillins_eng_r2406
  ON public.engineer_cross_zone_fillins_r2406(engineer_user_id, fillin_date DESC);
CREATE INDEX IF NOT EXISTS idx_xzone_fillins_zone_r2406
  ON public.engineer_cross_zone_fillins_r2406(fillin_zone, fillin_date DESC);
CREATE INDEX IF NOT EXISTS idx_xzone_fillins_status_r2406
  ON public.engineer_cross_zone_fillins_r2406(status, fillin_date DESC);

ALTER TABLE public.engineer_cross_zone_fillins_r2406 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_xzone_fillins_r2406
  ON public.engineer_cross_zone_fillins_r2406;
CREATE POLICY founder_all_xzone_fillins_r2406
  ON public.engineer_cross_zone_fillins_r2406
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_cross_zone_fatigue_alerts_r2406 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  alert_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  consecutive_days integer NOT NULL CHECK (consecutive_days >= 1),
  total_hours_7d numeric(7,2) NOT NULL DEFAULT 0,
  fatigue_score integer NOT NULL CHECK (fatigue_score BETWEEN 0 AND 100),
  severity text NOT NULL CHECK (severity IN ('watch','high','critical')),
  recommended_rest_days integer NOT NULL DEFAULT 1 CHECK (recommended_rest_days >= 0),
  acknowledged boolean NOT NULL DEFAULT false,
  acknowledged_at timestamptz,
  acknowledged_by_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xzone_alerts_eng_r2406
  ON public.engineer_cross_zone_fatigue_alerts_r2406(engineer_user_id, alert_date DESC);
CREATE INDEX IF NOT EXISTS idx_xzone_alerts_open_r2406
  ON public.engineer_cross_zone_fatigue_alerts_r2406(acknowledged, severity);

ALTER TABLE public.engineer_cross_zone_fatigue_alerts_r2406 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_xzone_alerts_r2406
  ON public.engineer_cross_zone_fatigue_alerts_r2406;
CREATE POLICY founder_all_xzone_alerts_r2406
  ON public.engineer_cross_zone_fatigue_alerts_r2406
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1 — list all fill-ins (most recent first)
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_cross_zone_fillins_r2406();
CREATE FUNCTION public.list_cross_zone_fillins_r2406()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  absent_engineer_user_id uuid,
  absent_engineer_email text,
  home_zone text,
  fillin_zone text,
  fillin_date date,
  jobs_covered integer,
  hours_worked numeric,
  travel_km numeric,
  base_rate_rupees integer,
  cross_zone_uplift_pct numeric,
  billable_amount_rupees integer,
  fair_comp_rupees integer,
  fatigue_score integer,
  fatigue_flag text,
  consecutive_fillin_days integer,
  status text,
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
  SELECT
    f.id,
    f.engineer_user_id,
    pe.email AS engineer_email,
    f.absent_engineer_user_id,
    pa.email AS absent_engineer_email,
    f.home_zone,
    f.fillin_zone,
    f.fillin_date,
    f.jobs_covered,
    f.hours_worked,
    f.travel_km,
    f.base_rate_rupees,
    f.cross_zone_uplift_pct,
    f.billable_amount_rupees,
    f.fair_comp_rupees,
    f.fatigue_score,
    f.fatigue_flag,
    f.consecutive_fillin_days,
    f.status,
    f.notes,
    f.created_at
  FROM public.engineer_cross_zone_fillins_r2406 f
  LEFT JOIN public.profiles pe ON pe.id = f.engineer_user_id
  LEFT JOIN public.profiles pa ON pa.id = f.absent_engineer_user_id
  ORDER BY f.fillin_date DESC, f.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.list_cross_zone_fillins_r2406() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cross_zone_fillins_r2406() TO authenticated;

-- =========================================================================
-- RPC 2 — per-engineer summary (billable, fair comp, fatigue)
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_fillin_summary_r2406();
CREATE FUNCTION public.engineer_fillin_summary_r2406()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  home_zone text,
  fillin_count integer,
  total_jobs integer,
  total_hours numeric,
  total_billable_rupees bigint,
  total_fair_comp_rupees bigint,
  avg_fatigue_score numeric,
  current_consecutive_days integer,
  worst_fatigue_flag text,
  last_fillin_date date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.engineer_user_id,
    pe.email AS engineer_email,
    MAX(f.home_zone) AS home_zone,
    COUNT(*)::integer AS fillin_count,
    COALESCE(SUM(f.jobs_covered), 0)::integer AS total_jobs,
    COALESCE(SUM(f.hours_worked), 0)::numeric AS total_hours,
    COALESCE(SUM(f.billable_amount_rupees), 0)::bigint AS total_billable_rupees,
    COALESCE(SUM(f.fair_comp_rupees), 0)::bigint AS total_fair_comp_rupees,
    COALESCE(AVG(f.fatigue_score), 0)::numeric AS avg_fatigue_score,
    MAX(f.consecutive_fillin_days)::integer AS current_consecutive_days,
    CASE
      WHEN MAX(CASE f.fatigue_flag WHEN 'critical' THEN 4 WHEN 'high' THEN 3 WHEN 'watch' THEN 2 ELSE 1 END) = 4 THEN 'critical'
      WHEN MAX(CASE f.fatigue_flag WHEN 'critical' THEN 4 WHEN 'high' THEN 3 WHEN 'watch' THEN 2 ELSE 1 END) = 3 THEN 'high'
      WHEN MAX(CASE f.fatigue_flag WHEN 'critical' THEN 4 WHEN 'high' THEN 3 WHEN 'watch' THEN 2 ELSE 1 END) = 2 THEN 'watch'
      ELSE 'ok'
    END AS worst_fatigue_flag,
    MAX(f.fillin_date) AS last_fillin_date
  FROM public.engineer_cross_zone_fillins_r2406 f
  LEFT JOIN public.profiles pe ON pe.id = f.engineer_user_id
  GROUP BY f.engineer_user_id, pe.email
  ORDER BY total_billable_rupees DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_fillin_summary_r2406() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_fillin_summary_r2406() TO authenticated;

-- =========================================================================
-- RPC 3 — zone-pair flow (home_zone -> fillin_zone)
-- =========================================================================
DROP FUNCTION IF EXISTS public.zone_pair_flow_r2406();
CREATE FUNCTION public.zone_pair_flow_r2406()
RETURNS TABLE (
  home_zone text,
  fillin_zone text,
  fillin_count integer,
  total_jobs integer,
  total_billable_rupees bigint,
  total_fair_comp_rupees bigint,
  avg_travel_km numeric,
  unique_engineers integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.home_zone,
    f.fillin_zone,
    COUNT(*)::integer AS fillin_count,
    COALESCE(SUM(f.jobs_covered), 0)::integer AS total_jobs,
    COALESCE(SUM(f.billable_amount_rupees), 0)::bigint AS total_billable_rupees,
    COALESCE(SUM(f.fair_comp_rupees), 0)::bigint AS total_fair_comp_rupees,
    COALESCE(AVG(f.travel_km), 0)::numeric AS avg_travel_km,
    COUNT(DISTINCT f.engineer_user_id)::integer AS unique_engineers
  FROM public.engineer_cross_zone_fillins_r2406 f
  GROUP BY f.home_zone, f.fillin_zone
  ORDER BY fillin_count DESC, total_billable_rupees DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.zone_pair_flow_r2406() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.zone_pair_flow_r2406() TO authenticated;

-- =========================================================================
-- RPC 4 — open fatigue alerts (watch/high/critical, unacked)
-- =========================================================================
DROP FUNCTION IF EXISTS public.open_fatigue_alerts_r2406();
CREATE FUNCTION public.open_fatigue_alerts_r2406()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  alert_date date,
  consecutive_days integer,
  total_hours_7d numeric,
  fatigue_score integer,
  severity text,
  recommended_rest_days integer,
  acknowledged boolean,
  acknowledged_at timestamptz,
  acknowledged_by_email text,
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
  SELECT
    a.id,
    a.engineer_user_id,
    pe.email AS engineer_email,
    a.alert_date,
    a.consecutive_days,
    a.total_hours_7d,
    a.fatigue_score,
    a.severity,
    a.recommended_rest_days,
    a.acknowledged,
    a.acknowledged_at,
    a.acknowledged_by_email,
    a.notes,
    a.created_at
  FROM public.engineer_cross_zone_fatigue_alerts_r2406 a
  LEFT JOIN public.profiles pe ON pe.id = a.engineer_user_id
  ORDER BY
    CASE a.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'watch' THEN 3 ELSE 4 END,
    a.acknowledged ASC,
    a.alert_date DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.open_fatigue_alerts_r2406() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_fatigue_alerts_r2406() TO authenticated;

-- =========================================================================
-- RPC 5 — overall console stats
-- =========================================================================
DROP FUNCTION IF EXISTS public.cross_zone_console_stats_r2406();
CREATE FUNCTION public.cross_zone_console_stats_r2406()
RETURNS TABLE (
  total_fillins integer,
  total_engineers integer,
  total_jobs_covered integer,
  total_hours_worked numeric,
  total_billable_rupees bigint,
  total_fair_comp_rupees bigint,
  avg_uplift_pct numeric,
  open_alerts integer,
  critical_alerts integer,
  pending_payouts integer,
  pending_payout_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::integer FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COUNT(DISTINCT engineer_user_id)::integer FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COALESCE(SUM(jobs_covered), 0)::integer FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COALESCE(SUM(hours_worked), 0)::numeric FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COALESCE(SUM(billable_amount_rupees), 0)::bigint FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COALESCE(SUM(fair_comp_rupees), 0)::bigint FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COALESCE(AVG(cross_zone_uplift_pct), 0)::numeric FROM public.engineer_cross_zone_fillins_r2406),
    (SELECT COUNT(*)::integer FROM public.engineer_cross_zone_fatigue_alerts_r2406 WHERE acknowledged = false),
    (SELECT COUNT(*)::integer FROM public.engineer_cross_zone_fatigue_alerts_r2406 WHERE acknowledged = false AND severity = 'critical'),
    (SELECT COUNT(*)::integer FROM public.engineer_cross_zone_fillins_r2406 WHERE status IN ('logged','approved')),
    (SELECT COALESCE(SUM(fair_comp_rupees), 0)::bigint FROM public.engineer_cross_zone_fillins_r2406 WHERE status IN ('logged','approved'));
END;
$$;

REVOKE ALL ON FUNCTION public.cross_zone_console_stats_r2406() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cross_zone_console_stats_r2406() TO authenticated;

-- =========================================================================
-- RPC 6 — approve / mark paid (status transition)
-- =========================================================================
DROP FUNCTION IF EXISTS public.update_fillin_status_r2406(uuid, text);
CREATE FUNCTION public.update_fillin_status_r2406(p_id uuid, p_status text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('logged','approved','paid','disputed','cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  v_email := auth.jwt()->>'email';
  UPDATE public.engineer_cross_zone_fillins_r2406
  SET status = p_status,
      updated_at = now(),
      notes = COALESCE(notes,'') || E'\n[' || COALESCE(v_email,'founder') || ' set status=' || p_status || ' at ' || now()::text || ']'
  WHERE id = p_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'fill-in not found'; END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.update_fillin_status_r2406(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_fillin_status_r2406(uuid, text) TO authenticated;

-- =========================================================================
-- RPC 7 — acknowledge fatigue alert
-- =========================================================================
DROP FUNCTION IF EXISTS public.ack_fatigue_alert_r2406(uuid, text);
CREATE FUNCTION public.ack_fatigue_alert_r2406(p_id uuid, p_notes text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  UPDATE public.engineer_cross_zone_fatigue_alerts_r2406
  SET acknowledged = true,
      acknowledged_at = now(),
      acknowledged_by_email = v_email,
      notes = COALESCE(p_notes, notes)
  WHERE id = p_id
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'alert not found'; END IF;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ack_fatigue_alert_r2406(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ack_fatigue_alert_r2406(uuid, text) TO authenticated;

COMMIT;
