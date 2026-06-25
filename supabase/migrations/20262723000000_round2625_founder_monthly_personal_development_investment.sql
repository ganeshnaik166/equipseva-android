-- Round 2625: Founder Monthly Personal Development Investment
-- Tracks monthly personal development hours and how insights are applied

BEGIN;

-- ============================================================
-- TABLE: founder_personal_dev_r2625
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_personal_dev_r2625 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  hours_invested numeric NOT NULL DEFAULT 0,
  dev_kind text NOT NULL CHECK (dev_kind IN ('book','course','coach','conference','peer_group','podcast')),
  top_insight_md text,
  application_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_personal_dev_r2625_month ON public.founder_personal_dev_r2625(month_label);
CREATE INDEX IF NOT EXISTS idx_personal_dev_r2625_kind ON public.founder_personal_dev_r2625(dev_kind);
CREATE INDEX IF NOT EXISTS idx_personal_dev_r2625_status ON public.founder_personal_dev_r2625(status);

ALTER TABLE public.founder_personal_dev_r2625 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_personal_dev_r2625;
CREATE POLICY founder_all ON public.founder_personal_dev_r2625
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE: personal_dev_application_log_r2625
-- ============================================================
CREATE TABLE IF NOT EXISTS public.personal_dev_application_log_r2625 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dev_id uuid NOT NULL REFERENCES public.founder_personal_dev_r2625(id) ON DELETE CASCADE,
  applied_at timestamptz NOT NULL DEFAULT now(),
  application_kind text NOT NULL CHECK (application_kind IN ('strategic_decision','team_change','product_pivot','relationship_repair','financial')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dev_app_log_r2625_dev ON public.personal_dev_application_log_r2625(dev_id);
CREATE INDEX IF NOT EXISTS idx_dev_app_log_r2625_kind ON public.personal_dev_application_log_r2625(application_kind);
CREATE INDEX IF NOT EXISTS idx_dev_app_log_r2625_outcome ON public.personal_dev_application_log_r2625(outcome);
CREATE INDEX IF NOT EXISTS idx_dev_app_log_r2625_status ON public.personal_dev_application_log_r2625(status);

ALTER TABLE public.personal_dev_application_log_r2625 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.personal_dev_application_log_r2625;
CREATE POLICY founder_all ON public.personal_dev_application_log_r2625
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.founder_personal_dev_r2625 (month_label, hours_invested, dev_kind, top_insight_md, application_md, owner_email, status, notes) VALUES
  ('2026-02', 18.5, 'book', 'Hard Things About Hard Things — wartime CEO mindset', 'Adopted 1-on-1 cadence with engineering leads weekly', 'founder@equipseva.com', 'done', 'Re-read chapters 7-9 twice'),
  ('2026-03', 12.0, 'coach', 'Distinguish urgent vs important; delegate everything not founder-unique', 'Stopped owning AMC ops directly; promoted ops lead', 'founder@equipseva.com', 'done', 'Bi-weekly coach sessions'),
  ('2026-04', 24.0, 'conference', 'Series A health-tech founders share burn discipline patterns', 'Re-modeled runway to 18 months unit-economics-first', 'founder@equipseva.com', 'done', 'Bengaluru founder summit'),
  ('2026-05', 8.0, 'peer_group', 'YPO forum — relationship repair after co-founder disputes', 'Reopened weekly co-founder retro', 'founder@equipseva.com', 'done', NULL),
  ('2026-06', 14.0, 'course', 'Operating model design — RACI clarity prevents shadow ops', 'Documented RACI for repair-job lifecycle', 'founder@equipseva.com', 'planned', 'In progress');

INSERT INTO public.personal_dev_application_log_r2625 (dev_id, applied_at, application_kind, outcome, owner_email, status, notes)
SELECT id, '2026-03-05'::timestamptz, 'team_change', 'positive', 'founder@equipseva.com', 'done', 'Weekly 1-on-1s reduced churn signals'
FROM public.founder_personal_dev_r2625 WHERE month_label = '2026-02' LIMIT 1;

INSERT INTO public.personal_dev_application_log_r2625 (dev_id, applied_at, application_kind, outcome, owner_email, status, notes)
SELECT id, '2026-03-20'::timestamptz, 'strategic_decision', 'positive', 'founder@equipseva.com', 'done', 'Delegated AMC ops fully'
FROM public.founder_personal_dev_r2625 WHERE month_label = '2026-03' LIMIT 1;

INSERT INTO public.personal_dev_application_log_r2625 (dev_id, applied_at, application_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-15'::timestamptz, 'financial', 'positive', 'founder@equipseva.com', 'done', 'Cut 3 non-essential SaaS subscriptions'
FROM public.founder_personal_dev_r2625 WHERE month_label = '2026-04' LIMIT 1;

INSERT INTO public.personal_dev_application_log_r2625 (dev_id, applied_at, application_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-12'::timestamptz, 'relationship_repair', 'neutral', 'founder@equipseva.com', 'open', 'Co-founder retro reopened; outcome TBD'
FROM public.founder_personal_dev_r2625 WHERE month_label = '2026-05' LIMIT 1;

INSERT INTO public.personal_dev_application_log_r2625 (dev_id, applied_at, application_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-10'::timestamptz, 'product_pivot', 'pending', 'founder@equipseva.com', 'open', 'RACI doc in review'
FROM public.founder_personal_dev_r2625 WHERE month_label = '2026-06' LIMIT 1;

-- ============================================================
-- RPCs (7)
-- ============================================================

-- 1. list_dev_r2625
CREATE OR REPLACE FUNCTION public.list_dev_r2625()
RETURNS TABLE (
  id uuid,
  month_label text,
  hours_invested numeric,
  dev_kind text,
  top_insight_md text,
  application_md text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.month_label, d.hours_invested, d.dev_kind, d.top_insight_md,
         d.application_md, d.owner_email, d.status, d.notes, d.created_at
  FROM public.founder_personal_dev_r2625 d
  ORDER BY d.month_label DESC, d.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_dev_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dev_r2625() TO authenticated;

-- 2. list_application_log_r2625
CREATE OR REPLACE FUNCTION public.list_application_log_r2625()
RETURNS TABLE (
  id uuid,
  dev_id uuid,
  month_label text,
  dev_kind text,
  applied_at timestamptz,
  application_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.dev_id, d.month_label, d.dev_kind,
         l.applied_at, l.application_kind, l.outcome, l.owner_email,
         l.status, l.notes
  FROM public.personal_dev_application_log_r2625 l
  LEFT JOIN public.founder_personal_dev_r2625 d ON d.id = l.dev_id
  ORDER BY l.applied_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_application_log_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_application_log_r2625() TO authenticated;

-- 3. top_hours_focus_r2625
CREATE OR REPLACE FUNCTION public.top_hours_focus_r2625()
RETURNS TABLE (
  month_label text,
  total_hours numeric,
  top_kind text,
  entry_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.month_label,
         SUM(d.hours_invested)::numeric AS total_hours,
         (ARRAY_AGG(d.dev_kind ORDER BY d.hours_invested DESC))[1] AS top_kind,
         COUNT(*)::bigint AS entry_count
  FROM public.founder_personal_dev_r2625 d
  GROUP BY d.month_label
  ORDER BY total_hours DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hours_focus_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hours_focus_r2625() TO authenticated;

-- 4. dev_kind_distribution_r2625
CREATE OR REPLACE FUNCTION public.dev_kind_distribution_r2625()
RETURNS TABLE (
  dev_kind text,
  entry_count bigint,
  total_hours numeric,
  avg_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.dev_kind,
         COUNT(*)::bigint AS entry_count,
         COALESCE(SUM(d.hours_invested),0)::numeric AS total_hours,
         COALESCE(AVG(d.hours_invested),0)::numeric AS avg_hours
  FROM public.founder_personal_dev_r2625 d
  GROUP BY d.dev_kind
  ORDER BY total_hours DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dev_kind_distribution_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dev_kind_distribution_r2625() TO authenticated;

-- 5. status_funnel_r2625
CREATE OR REPLACE FUNCTION public.status_funnel_r2625()
RETURNS TABLE (
  status text,
  entry_count bigint,
  total_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.status,
         COUNT(*)::bigint AS entry_count,
         COALESCE(SUM(d.hours_invested),0)::numeric AS total_hours
  FROM public.founder_personal_dev_r2625 d
  GROUP BY d.status
  ORDER BY entry_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2625() TO authenticated;

-- 6. monthly_dev_trend_r2625
CREATE OR REPLACE FUNCTION public.monthly_dev_trend_r2625()
RETURNS TABLE (
  month_label text,
  hours_invested numeric,
  done_count bigint,
  planned_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.month_label,
         COALESCE(SUM(d.hours_invested),0)::numeric AS hours_invested,
         COUNT(*) FILTER (WHERE d.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE d.status = 'planned')::bigint AS planned_count
  FROM public.founder_personal_dev_r2625 d
  GROUP BY d.month_label
  ORDER BY d.month_label DESC
  LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_dev_trend_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_dev_trend_r2625() TO authenticated;

-- 7. application_outcome_summary_r2625
CREATE OR REPLACE FUNCTION public.application_outcome_summary_r2625()
RETURNS TABLE (
  application_kind text,
  outcome text,
  entry_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.application_kind, l.outcome, COUNT(*)::bigint AS entry_count
  FROM public.personal_dev_application_log_r2625 l
  GROUP BY l.application_kind, l.outcome
  ORDER BY l.application_kind, entry_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.application_outcome_summary_r2625() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.application_outcome_summary_r2625() TO authenticated;

COMMIT;
