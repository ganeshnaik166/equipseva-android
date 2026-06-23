-- Round 2520: Customer onboarding feedback trends
-- Hospital wave × NPS × CSAT × top compliment × top complaint × action taken × deflection

CREATE TABLE IF NOT EXISTS public.customer_onboarding_feedback_waves_r2520 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wave_label text NOT NULL,
  wave_start date NOT NULL,
  wave_end date NOT NULL,
  hospitals_count int NOT NULL DEFAULT 0,
  avg_nps numeric(5,2),
  avg_csat numeric(5,2),
  top_compliment_md text,
  top_complaint_md text,
  completion_rate_pct numeric(5,2),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','dropped')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.feedback_wave_actions_r2520 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wave_id uuid NOT NULL REFERENCES public.customer_onboarding_feedback_waves_r2520(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('product','process','training','communication','policy')),
  action_summary_md text NOT NULL,
  owner_email text,
  target_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_onboarding_feedback_waves_r2520 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback_wave_actions_r2520 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_onboarding_feedback_waves_r2520;
CREATE POLICY founder_all ON public.customer_onboarding_feedback_waves_r2520
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.feedback_wave_actions_r2520;
CREATE POLICY founder_all ON public.feedback_wave_actions_r2520
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed: 4 waves
INSERT INTO public.customer_onboarding_feedback_waves_r2520
  (wave_label, wave_start, wave_end, hospitals_count, avg_nps, avg_csat, top_compliment_md, top_complaint_md, completion_rate_pct, status, owner_email, notes)
VALUES
  ('Wave Q1-2026 Tier-1', '2026-01-05', '2026-03-31', 18, 62.50, 4.40, '**Fast engineer dispatch**: median ETA <90 min in metros', '**App onboarding too long**: 11 screens before first job', 88.00, 'completed', 'cx@equipseva.com', 'Strongest cohort yet'),
  ('Wave Q2-2026 Tier-2', '2026-04-01', '2026-05-31', 24, 48.30, 4.10, '**Transparent pricing breakdown** before approval', '**SMS confirmations unreliable** on Jio circles', 76.50, 'completed', 'cx@equipseva.com', 'Carrier-specific SMS gap'),
  ('Wave Q2-2026 Multi-spec chains', '2026-05-01', '2026-06-15', 9, 71.00, 4.55, '**Chain dashboard rollup** beats spreadsheet they had before', '**AMC tier confusion** Gold vs Platinum scope unclear', 94.00, 'in_progress', 'chains@equipseva.com', 'High-NPS small-N cohort'),
  ('Wave Q3-2026 Super-specialty', '2026-07-01', '2026-09-30', 0, NULL, NULL, NULL, NULL, NULL, 'planned', 'cx@equipseva.com', 'Cardiac + oncology pilot');

-- Seed actions
WITH w1 AS (SELECT id FROM public.customer_onboarding_feedback_waves_r2520 WHERE wave_label='Wave Q1-2026 Tier-1' LIMIT 1),
     w2 AS (SELECT id FROM public.customer_onboarding_feedback_waves_r2520 WHERE wave_label='Wave Q2-2026 Tier-2' LIMIT 1),
     w3 AS (SELECT id FROM public.customer_onboarding_feedback_waves_r2520 WHERE wave_label='Wave Q2-2026 Multi-spec chains' LIMIT 1)
INSERT INTO public.feedback_wave_actions_r2520
  (wave_id, action_kind, action_summary_md, owner_email, target_at, status, outcome, closed_at, notes)
SELECT (SELECT id FROM w1), 'product', '**Shrink onboarding** from 11 to 5 screens; defer KYC to first repair', 'product@equipseva.com', '2026-04-15'::timestamptz, 'done', 'positive', '2026-04-10'::timestamptz, 'Drop-off -38%'
UNION ALL
SELECT (SELECT id FROM w2), 'process', '**Add fallback WhatsApp** when SMS bounces twice on Jio circles', 'ops@equipseva.com', '2026-06-01'::timestamptz, 'in_progress', 'pending', NULL, 'Vendor BSP in eval'
UNION ALL
SELECT (SELECT id FROM w2), 'communication', '**Carrier-detection script** in app to warn user about delivery on flaky circles', 'product@equipseva.com', '2026-07-01'::timestamptz, 'open', 'pending', NULL, NULL
UNION ALL
SELECT (SELECT id FROM w3), 'training', '**Chain-admin webinar** on Gold vs Platinum scope with comparison table PDF', 'chains@equipseva.com', '2026-06-30'::timestamptz, 'in_progress', 'pending', NULL, 'PDF in design'
UNION ALL
SELECT (SELECT id FROM w3), 'policy', '**AMC tier scope doc v2** ratified by founder; sales must attach to quote', 'founder@equipseva.com', '2026-07-15'::timestamptz, 'open', 'pending', NULL, NULL;

CREATE OR REPLACE FUNCTION public.list_waves_r2520()
RETURNS TABLE (
  id uuid, wave_label text, wave_start date, wave_end date, hospitals_count int,
  avg_nps numeric, avg_csat numeric, completion_rate_pct numeric, status text, owner_email text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.wave_label, w.wave_start, w.wave_end, w.hospitals_count,
         w.avg_nps, w.avg_csat, w.completion_rate_pct, w.status, w.owner_email, w.notes
  FROM public.customer_onboarding_feedback_waves_r2520 w
  ORDER BY w.wave_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_waves_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_waves_r2520() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2520()
RETURNS TABLE (
  id uuid, wave_label text, action_kind text, action_summary_md text, owner_email text,
  target_at timestamptz, status text, outcome text, closed_at timestamptz, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, w.wave_label, a.action_kind, a.action_summary_md, a.owner_email,
         a.target_at, a.status, a.outcome, a.closed_at, a.notes
  FROM public.feedback_wave_actions_r2520 a
  JOIN public.customer_onboarding_feedback_waves_r2520 w ON w.id = a.wave_id
  ORDER BY COALESCE(a.target_at, a.created_at) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2520() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_complaint_themes_r2520()
RETURNS TABLE (wave_label text, top_complaint_md text, avg_nps numeric, hospitals_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.wave_label, w.top_complaint_md, w.avg_nps, w.hospitals_count
  FROM public.customer_onboarding_feedback_waves_r2520 w
  WHERE w.top_complaint_md IS NOT NULL
  ORDER BY COALESCE(w.avg_nps, 100) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_complaint_themes_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_complaint_themes_r2520() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_kind_summary_r2520()
RETURNS TABLE (action_kind text, total int, done_count int, positive_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         COUNT(*)::int AS total,
         COUNT(*) FILTER (WHERE a.status = 'done')::int AS done_count,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::int AS positive_count
  FROM public.feedback_wave_actions_r2520 a
  GROUP BY a.action_kind
  ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_summary_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_summary_r2520() TO authenticated;

CREATE OR REPLACE FUNCTION public.wave_completion_summary_r2520()
RETURNS TABLE (status text, waves_count int, avg_completion_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.status, COUNT(*)::int AS waves_count, ROUND(AVG(w.completion_rate_pct), 2) AS avg_completion_pct
  FROM public.customer_onboarding_feedback_waves_r2520 w
  GROUP BY w.status
  ORDER BY waves_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.wave_completion_summary_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wave_completion_summary_r2520() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_wave_trend_r2520()
RETURNS TABLE (month_start date, waves_count int, avg_nps numeric, avg_csat numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', w.wave_start)::date AS month_start,
         COUNT(*)::int AS waves_count,
         ROUND(AVG(w.avg_nps), 2) AS avg_nps,
         ROUND(AVG(w.avg_csat), 2) AS avg_csat
  FROM public.customer_onboarding_feedback_waves_r2520 w
  GROUP BY date_trunc('month', w.wave_start)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_wave_trend_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_wave_trend_r2520() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_hospitals_by_nps_in_wave_r2520()
RETURNS TABLE (wave_label text, avg_nps numeric, hospitals_count int, completion_rate_pct numeric, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.wave_label, w.avg_nps, w.hospitals_count, w.completion_rate_pct, w.status
  FROM public.customer_onboarding_feedback_waves_r2520 w
  WHERE w.avg_nps IS NOT NULL
  ORDER BY w.avg_nps DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_nps_in_wave_r2520() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_nps_in_wave_r2520() TO authenticated;
