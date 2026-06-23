-- Round 2412 — Customer PM vs CM Ratio Dashboard
-- Per-hospital preventive (PM) vs corrective (CM) maintenance ratio trending.
-- CM-rising = retention risk signal.

BEGIN;

-- ============================================================================
-- TABLE: hospital_pm_cm_monthly_r2412
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.hospital_pm_cm_monthly_r2412 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  hospital_email text NOT NULL,
  month_start date NOT NULL,
  pm_visits integer NOT NULL DEFAULT 0 CHECK (pm_visits >= 0),
  cm_visits integer NOT NULL DEFAULT 0 CHECK (cm_visits >= 0),
  pm_minutes integer NOT NULL DEFAULT 0 CHECK (pm_minutes >= 0),
  cm_minutes integer NOT NULL DEFAULT 0 CHECK (cm_minutes >= 0),
  pm_cost_rupees integer NOT NULL DEFAULT 0 CHECK (pm_cost_rupees >= 0),
  cm_cost_rupees integer NOT NULL DEFAULT 0 CHECK (cm_cost_rupees >= 0),
  total_visits integer NOT NULL DEFAULT 0 CHECK (total_visits >= 0),
  pm_ratio_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (pm_ratio_pct >= 0 AND pm_ratio_pct <= 100),
  cm_ratio_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (cm_ratio_pct >= 0 AND cm_ratio_pct <= 100),
  downtime_minutes integer NOT NULL DEFAULT 0 CHECK (downtime_minutes >= 0),
  slo_breaches integer NOT NULL DEFAULT 0 CHECK (slo_breaches >= 0),
  notes text
);

ALTER TABLE public.hospital_pm_cm_monthly_r2412 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.hospital_pm_cm_monthly_r2412
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: pm_cm_trend_alerts_r2412
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pm_cm_trend_alerts_r2412 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  detected_at timestamptz NOT NULL DEFAULT now(),
  alert_kind text NOT NULL CHECK (alert_kind IN ('cm_rising','pm_dropping','slo_breach_surge')),
  prior_pm_ratio_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (prior_pm_ratio_pct >= 0 AND prior_pm_ratio_pct <= 100),
  current_pm_ratio_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (current_pm_ratio_pct >= 0 AND current_pm_ratio_pct <= 100),
  ratio_delta_pct numeric(6,2) NOT NULL DEFAULT 0,
  recommended_action text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  notes text
);

ALTER TABLE public.pm_cm_trend_alerts_r2412 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.pm_cm_trend_alerts_r2412
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_monthly_ratios_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_monthly_ratios_r2412()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  month_start date,
  pm_visits integer,
  cm_visits integer,
  total_visits integer,
  pm_ratio_pct numeric,
  cm_ratio_pct numeric,
  downtime_minutes integer,
  slo_breaches integer,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_email, r.month_start, r.pm_visits, r.cm_visits,
           r.total_visits, r.pm_ratio_pct, r.cm_ratio_pct,
           r.downtime_minutes, r.slo_breaches, r.notes
    FROM public.hospital_pm_cm_monthly_r2412 r
    ORDER BY r.month_start DESC, r.hospital_email ASC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_monthly_ratios_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_monthly_ratios_r2412() TO authenticated;

-- ============================================================================
-- RPC 2: list_alerts_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_alerts_r2412()
RETURNS TABLE(
  id uuid,
  detected_at timestamptz,
  alert_kind text,
  prior_pm_ratio_pct numeric,
  current_pm_ratio_pct numeric,
  ratio_delta_pct numeric,
  recommended_action text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.detected_at, a.alert_kind, a.prior_pm_ratio_pct,
           a.current_pm_ratio_pct, a.ratio_delta_pct, a.recommended_action,
           a.owner_email, a.status, a.notes
    FROM public.pm_cm_trend_alerts_r2412 a
    ORDER BY a.detected_at DESC
    LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_alerts_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_alerts_r2412() TO authenticated;

-- ============================================================================
-- RPC 3: top_cm_rising_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_cm_rising_r2412()
RETURNS TABLE(
  hospital_email text,
  current_pm_ratio_pct numeric,
  prior_pm_ratio_pct numeric,
  ratio_delta_pct numeric,
  recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(p.email, 'unknown') AS hospital_email,
           a.current_pm_ratio_pct, a.prior_pm_ratio_pct,
           a.ratio_delta_pct, a.recommended_action
    FROM public.pm_cm_trend_alerts_r2412 a
    LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
    WHERE a.alert_kind = 'cm_rising' AND a.status IN ('open','in_progress')
    ORDER BY a.ratio_delta_pct ASC
    LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_cm_rising_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_cm_rising_r2412() TO authenticated;

-- ============================================================================
-- RPC 4: hospitals_under_50pct_pm_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.hospitals_under_50pct_pm_r2412()
RETURNS TABLE(
  hospital_email text,
  month_start date,
  pm_ratio_pct numeric,
  cm_ratio_pct numeric,
  total_visits integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.hospital_email, r.month_start, r.pm_ratio_pct, r.cm_ratio_pct, r.total_visits
    FROM public.hospital_pm_cm_monthly_r2412 r
    WHERE r.pm_ratio_pct < 50
    ORDER BY r.pm_ratio_pct ASC, r.month_start DESC
    LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.hospitals_under_50pct_pm_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospitals_under_50pct_pm_r2412() TO authenticated;

-- ============================================================================
-- RPC 5: ratio_distribution_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.ratio_distribution_r2412()
RETURNS TABLE(
  bucket text,
  hospital_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.bucket, COUNT(*)::integer AS hospital_count
    FROM (
      SELECT CASE
        WHEN r.pm_ratio_pct >= 80 THEN '80-100% PM (healthy)'
        WHEN r.pm_ratio_pct >= 60 THEN '60-79% PM (ok)'
        WHEN r.pm_ratio_pct >= 40 THEN '40-59% PM (watch)'
        WHEN r.pm_ratio_pct >= 20 THEN '20-39% PM (risk)'
        ELSE '0-19% PM (red)'
      END AS bucket
      FROM public.hospital_pm_cm_monthly_r2412 r
      WHERE r.month_start = (SELECT MAX(month_start) FROM public.hospital_pm_cm_monthly_r2412)
    ) b
    GROUP BY b.bucket
    ORDER BY b.bucket ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ratio_distribution_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ratio_distribution_r2412() TO authenticated;

-- ============================================================================
-- RPC 6: monthly_company_avg_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_company_avg_r2412()
RETURNS TABLE(
  month_start date,
  avg_pm_ratio_pct numeric,
  avg_cm_ratio_pct numeric,
  total_pm_visits bigint,
  total_cm_visits bigint,
  total_slo_breaches bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.month_start,
           ROUND(AVG(r.pm_ratio_pct), 2) AS avg_pm_ratio_pct,
           ROUND(AVG(r.cm_ratio_pct), 2) AS avg_cm_ratio_pct,
           SUM(r.pm_visits)::bigint AS total_pm_visits,
           SUM(r.cm_visits)::bigint AS total_cm_visits,
           SUM(r.slo_breaches)::bigint AS total_slo_breaches
    FROM public.hospital_pm_cm_monthly_r2412 r
    GROUP BY r.month_start
    ORDER BY r.month_start DESC
    LIMIT 24;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.monthly_company_avg_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_company_avg_r2412() TO authenticated;

-- ============================================================================
-- RPC 7: intervention_plan_summary_r2412
-- ============================================================================
CREATE OR REPLACE FUNCTION public.intervention_plan_summary_r2412()
RETURNS TABLE(
  status text,
  alert_kind text,
  alert_count integer,
  avg_ratio_delta_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.status, a.alert_kind,
           COUNT(*)::integer AS alert_count,
           ROUND(AVG(a.ratio_delta_pct), 2) AS avg_ratio_delta_pct
    FROM public.pm_cm_trend_alerts_r2412 a
    GROUP BY a.status, a.alert_kind
    ORDER BY a.status ASC, a.alert_kind ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.intervention_plan_summary_r2412() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.intervention_plan_summary_r2412() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.hospital_pm_cm_monthly_r2412
  (hospital_user_id, hospital_email, month_start, pm_visits, cm_visits, pm_minutes, cm_minutes,
   pm_cost_rupees, cm_cost_rupees, total_visits, pm_ratio_pct, cm_ratio_pct, downtime_minutes, slo_breaches, notes)
VALUES
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'apollo.hyd@example.com', DATE '2026-05-01', 12, 3, 720, 240, 60000, 36000, 15, 80.00, 20.00, 120, 0,
   'Healthy PM cadence, low CM ratio.'),
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'apollo.hyd@example.com', DATE '2026-06-01', 8, 7, 480, 560, 40000, 84000, 15, 53.33, 46.67, 380, 2,
   'CM rising sharply — check engineer assignment.'),
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'careplus.blr@example.com', DATE '2026-06-01', 10, 2, 600, 160, 50000, 24000, 12, 83.33, 16.67, 90, 0,
   'Stable, AMC well-honored.'),
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'medstar.del@example.com', DATE '2026-06-01', 4, 11, 240, 880, 20000, 132000, 15, 26.67, 73.33, 720, 5,
   'Red zone — CM dominant, retention risk.');

INSERT INTO public.pm_cm_trend_alerts_r2412
  (hospital_user_id, alert_kind, prior_pm_ratio_pct, current_pm_ratio_pct, ratio_delta_pct,
   recommended_action, owner_email, status, notes)
VALUES
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'cm_rising', 80.00, 53.33, -26.67,
   'Schedule biomed review call; re-baseline PM checklist.',
   'csm@equipseva.com', 'open', 'Apollo HYD trend reversed in June.'),
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'pm_dropping', 65.00, 26.67, -38.33,
   'Escalate to CEO; account at risk of churn.',
   'founder@equipseva.com', 'in_progress', 'Medstar DEL needs intervention this week.'),
  ((SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   'slo_breach_surge', 70.00, 26.67, -43.33,
   'Spot audit + engineer rotation review.',
   'ops@equipseva.com', 'open', '5 SLO breaches in June at Medstar DEL.');

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE public.hospital_pm_cm_monthly_r2412 IS 'Per-hospital monthly preventive vs corrective maintenance ratio rollup.';
COMMENT ON TABLE public.pm_cm_trend_alerts_r2412 IS 'Alerts when CM ratio rises or PM drops — retention risk signals.';
COMMENT ON FUNCTION public.list_monthly_ratios_r2412() IS 'List recent monthly PM/CM ratio rollups.';
COMMENT ON FUNCTION public.list_alerts_r2412() IS 'List PM/CM trend alerts.';
COMMENT ON FUNCTION public.top_cm_rising_r2412() IS 'Top open CM-rising alerts by largest negative ratio delta.';
COMMENT ON FUNCTION public.hospitals_under_50pct_pm_r2412() IS 'Hospitals with PM ratio under 50% — watch list.';
COMMENT ON FUNCTION public.ratio_distribution_r2412() IS 'Bucketed distribution of latest month PM ratio across hospitals.';
COMMENT ON FUNCTION public.monthly_company_avg_r2412() IS 'Company-wide monthly average PM and CM ratios + totals.';
COMMENT ON FUNCTION public.intervention_plan_summary_r2412() IS 'Alert counts and average delta grouped by status and kind.';

