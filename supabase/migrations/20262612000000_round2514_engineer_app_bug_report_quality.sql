-- Round 2514: engineer-app-bug-report-quality
-- Bug reports x screenshot x repro steps x severity x fix time x reporter productivity bonus

CREATE TABLE IF NOT EXISTS public.engineer_bug_reports_r2514 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  bug_title text NOT NULL,
  bug_kind text NOT NULL CHECK (bug_kind IN ('crash','slow','wrong_data','ui','sync_failure','auth','network')),
  screenshot_attached boolean NOT NULL DEFAULT false,
  repro_steps_md text,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  reported_at timestamptz NOT NULL DEFAULT now(),
  fixed_at timestamptz,
  fix_time_hours int,
  reporter_bonus_rupees int NOT NULL DEFAULT 0 CHECK (reporter_bonus_rupees >= 0),
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','triaged','in_progress','fixed','duplicate','wont_fix')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bug_report_quality_scores_r2514 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  reports_count int NOT NULL DEFAULT 0 CHECK (reports_count >= 0),
  useful_count int NOT NULL DEFAULT 0 CHECK (useful_count >= 0),
  useful_pct numeric NOT NULL DEFAULT 0,
  total_bonus_rupees bigint NOT NULL DEFAULT 0,
  top_bug_kind text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','coaching','excellent')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_bug_reports_r2514 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bug_report_quality_scores_r2514 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_bug_reports_r2514;
CREATE POLICY founder_all ON public.engineer_bug_reports_r2514
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.bug_report_quality_scores_r2514;
CREATE POLICY founder_all ON public.bug_report_quality_scores_r2514
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed bug reports
INSERT INTO public.engineer_bug_reports_r2514 (id, engineer_user_id, bug_title, bug_kind, screenshot_attached, repro_steps_md, severity, reported_at, fixed_at, fix_time_hours, reporter_bonus_rupees, status, owner_email, notes)
VALUES
  ('33333333-3333-3333-3333-333333333301', NULL, 'App crashes on photo upload >5MB', 'crash', true, '1. Open job\n2. Take 12MP photo\n3. Tap upload\n4. App force closes', 'critical', now() - interval '20 days', now() - interval '18 days', 36, 500, 'fixed', 'eng-ravi@equipseva.in', 'Repro perfect, fix landed in v0.5.3'),
  ('33333333-3333-3333-3333-333333333302', NULL, 'AMC contract sync stuck on slow network', 'sync_failure', true, '1. Toggle airplane mode\n2. Save AMC contract\n3. Toggle back on\n4. Spinner forever', 'high', now() - interval '15 days', now() - interval '12 days', 48, 300, 'fixed', 'eng-suman@equipseva.in', 'Added retry with backoff'),
  ('33333333-3333-3333-3333-333333333303', NULL, 'Job list shows wrong customer name', 'wrong_data', true, '1. Open jobs tab\n2. Customer name shows previous customer for 1s', 'medium', now() - interval '10 days', now() - interval '8 days', 30, 200, 'fixed', 'eng-priya@equipseva.in', 'Stale state issue, useEffect cleanup'),
  ('33333333-3333-3333-3333-333333333304', NULL, 'Login button overlaps with keyboard on small screens', 'ui', true, '1. Open login on 4.7in screen\n2. Tap email field\n3. Keyboard hides login button', 'low', now() - interval '7 days', NULL, NULL, 0, 'triaged', 'eng-aakash@equipseva.in', 'Low priority, schedule v0.6'),
  ('33333333-3333-3333-3333-333333333305', NULL, 'Slow load on parts catalog 8s+', 'slow', false, 'Catalog tab takes 8+ seconds to load', 'medium', now() - interval '5 days', NULL, NULL, 0, 'in_progress', 'eng-naveen@equipseva.in', 'Missing screenshot but legit complaint')
ON CONFLICT (id) DO NOTHING;

-- Seed quality scores
INSERT INTO public.bug_report_quality_scores_r2514 (engineer_user_id, quarter_label, reports_count, useful_count, useful_pct, total_bonus_rupees, top_bug_kind, owner_email, status, notes)
VALUES
  (NULL, '2026-Q2', 12, 10, 83.3, 2400, 'crash', 'eng-ravi@equipseva.in', 'excellent', 'Top reporter, always with repro'),
  (NULL, '2026-Q2', 8, 6, 75.0, 1500, 'sync_failure', 'eng-suman@equipseva.in', 'excellent', 'Sync expert'),
  (NULL, '2026-Q2', 5, 3, 60.0, 600, 'wrong_data', 'eng-priya@equipseva.in', 'monitoring', 'Solid but inconsistent screenshots'),
  (NULL, '2026-Q2', 3, 1, 33.3, 100, 'ui', 'eng-aakash@equipseva.in', 'coaching', 'Mostly cosmetic, train on severity'),
  (NULL, '2026-Q2', 2, 0, 0.0, 0, 'slow', 'eng-naveen@equipseva.in', 'coaching', 'No screenshots, vague repros');

-- RPC 1: list_bug_reports_r2514
CREATE OR REPLACE FUNCTION public.list_bug_reports_r2514()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  bug_title text,
  bug_kind text,
  screenshot_attached boolean,
  repro_steps_md text,
  severity text,
  reported_at timestamptz,
  fixed_at timestamptz,
  fix_time_hours int,
  reporter_bonus_rupees int,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.engineer_user_id, b.bug_title, b.bug_kind, b.screenshot_attached,
         b.repro_steps_md, b.severity, b.reported_at, b.fixed_at, b.fix_time_hours,
         b.reporter_bonus_rupees, b.status, b.owner_email, b.notes
  FROM public.engineer_bug_reports_r2514 b
  ORDER BY b.reported_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_bug_reports_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bug_reports_r2514() TO authenticated;

-- RPC 2: list_quality_scores_r2514
CREATE OR REPLACE FUNCTION public.list_quality_scores_r2514()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  quarter_label text,
  reports_count int,
  useful_count int,
  useful_pct numeric,
  total_bonus_rupees bigint,
  top_bug_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.engineer_user_id, q.quarter_label, q.reports_count, q.useful_count,
         q.useful_pct, q.total_bonus_rupees, q.top_bug_kind, q.owner_email, q.status, q.notes
  FROM public.bug_report_quality_scores_r2514 q
  ORDER BY q.useful_pct DESC, q.reports_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_quality_scores_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_quality_scores_r2514() TO authenticated;

-- RPC 3: top_reporter_engineers_r2514
CREATE OR REPLACE FUNCTION public.top_reporter_engineers_r2514()
RETURNS TABLE (
  owner_email text,
  reports_count bigint,
  useful_count bigint,
  total_bonus_rupees bigint,
  useful_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.owner_email,
         SUM(q.reports_count)::bigint AS reports_count,
         SUM(q.useful_count)::bigint AS useful_count,
         SUM(q.total_bonus_rupees)::bigint AS total_bonus_rupees,
         CASE WHEN SUM(q.reports_count) > 0
              THEN ROUND((SUM(q.useful_count)::numeric * 100.0 / SUM(q.reports_count)), 1)
              ELSE 0 END AS useful_pct
  FROM public.bug_report_quality_scores_r2514 q
  WHERE q.owner_email IS NOT NULL
  GROUP BY q.owner_email
  ORDER BY reports_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_reporter_engineers_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reporter_engineers_r2514() TO authenticated;

-- RPC 4: severity_breakdown_r2514
CREATE OR REPLACE FUNCTION public.severity_breakdown_r2514()
RETURNS TABLE (
  severity text,
  reports_count bigint,
  fixed_count bigint,
  avg_fix_hours numeric,
  total_bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.severity,
         COUNT(*)::bigint AS reports_count,
         COUNT(*) FILTER (WHERE b.status = 'fixed')::bigint AS fixed_count,
         ROUND(COALESCE(AVG(b.fix_time_hours)::numeric, 0), 1) AS avg_fix_hours,
         COALESCE(SUM(b.reporter_bonus_rupees), 0)::bigint AS total_bonus_rupees
  FROM public.engineer_bug_reports_r2514 b
  GROUP BY b.severity
  ORDER BY CASE b.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.severity_breakdown_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severity_breakdown_r2514() TO authenticated;

-- RPC 5: bug_kind_distribution_r2514
CREATE OR REPLACE FUNCTION public.bug_kind_distribution_r2514()
RETURNS TABLE (
  bug_kind text,
  reports_count bigint,
  with_screenshot bigint,
  fixed_count bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.engineer_bug_reports_r2514;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT b.bug_kind,
         COUNT(*)::bigint AS reports_count,
         COUNT(*) FILTER (WHERE b.screenshot_attached)::bigint AS with_screenshot,
         COUNT(*) FILTER (WHERE b.status = 'fixed')::bigint AS fixed_count,
         ROUND((COUNT(*)::numeric * 100.0 / total), 1) AS pct_of_total
  FROM public.engineer_bug_reports_r2514 b
  GROUP BY b.bug_kind
  ORDER BY reports_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.bug_kind_distribution_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bug_kind_distribution_r2514() TO authenticated;

-- RPC 6: monthly_report_trend_r2514
CREATE OR REPLACE FUNCTION public.monthly_report_trend_r2514()
RETURNS TABLE (
  month_label text,
  reports_count bigint,
  fixed_count bigint,
  with_screenshot bigint,
  total_bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', b.reported_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS reports_count,
         COUNT(*) FILTER (WHERE b.status = 'fixed')::bigint AS fixed_count,
         COUNT(*) FILTER (WHERE b.screenshot_attached)::bigint AS with_screenshot,
         COALESCE(SUM(b.reporter_bonus_rupees), 0)::bigint AS total_bonus_rupees
  FROM public.engineer_bug_reports_r2514 b
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_report_trend_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_report_trend_r2514() TO authenticated;

-- RPC 7: useful_rate_summary_r2514
CREATE OR REPLACE FUNCTION public.useful_rate_summary_r2514()
RETURNS TABLE (
  total_reports bigint,
  fixed_count bigint,
  wont_fix_count bigint,
  duplicate_count bigint,
  with_screenshot_pct numeric,
  fixed_pct numeric,
  total_bonus_rupees bigint,
  avg_fix_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO tot FROM public.engineer_bug_reports_r2514;
  IF tot = 0 THEN tot := 1; END IF;
  RETURN QUERY
  SELECT COUNT(*)::bigint AS total_reports,
         COUNT(*) FILTER (WHERE b.status = 'fixed')::bigint AS fixed_count,
         COUNT(*) FILTER (WHERE b.status = 'wont_fix')::bigint AS wont_fix_count,
         COUNT(*) FILTER (WHERE b.status = 'duplicate')::bigint AS duplicate_count,
         ROUND((COUNT(*) FILTER (WHERE b.screenshot_attached)::numeric * 100.0 / tot), 1) AS with_screenshot_pct,
         ROUND((COUNT(*) FILTER (WHERE b.status = 'fixed')::numeric * 100.0 / tot), 1) AS fixed_pct,
         COALESCE(SUM(b.reporter_bonus_rupees), 0)::bigint AS total_bonus_rupees,
         ROUND(COALESCE(AVG(b.fix_time_hours)::numeric, 0), 1) AS avg_fix_hours
  FROM public.engineer_bug_reports_r2514 b;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.useful_rate_summary_r2514() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.useful_rate_summary_r2514() TO authenticated;
