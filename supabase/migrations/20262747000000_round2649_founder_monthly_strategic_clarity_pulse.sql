-- r2649 founder monthly strategic clarity pulse

CREATE TABLE IF NOT EXISTS public.founder_strategic_clarity_r2649 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  north_star_clear boolean NOT NULL DEFAULT false,
  top_3_priorities_md text NOT NULL DEFAULT '',
  top_3_kills_md text NOT NULL DEFAULT '',
  clarity_score int NOT NULL DEFAULT 0 CHECK (clarity_score BETWEEN 0 AND 100),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','calibrating','aligned','blurry')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.clarity_recovery_actions_r2649 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_id uuid NOT NULL REFERENCES public.founder_strategic_clarity_r2649(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('retreat','peer_audit','customer_immersion','strategic_pause','redo_kpis')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_strategic_clarity_r2649 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clarity_recovery_actions_r2649 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_strategic_clarity_r2649;
CREATE POLICY founder_all ON public.founder_strategic_clarity_r2649
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.clarity_recovery_actions_r2649;
CREATE POLICY founder_all ON public.clarity_recovery_actions_r2649
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed clarity pulses
INSERT INTO public.founder_strategic_clarity_r2649
  (month_label, north_star_clear, top_3_priorities_md, top_3_kills_md, clarity_score, owner_email, status, notes)
VALUES
  ('2026-02', true, 'AMC GMV; engineer NPS; Tier-1 share', 'B2C app; logistics in-house; multi-vertical splash', 78, 'founder@equipseva.com', 'aligned', 'Steady focus on Tier-1 hospital chains'),
  ('2026-03', true, 'Series A close; hospital chain MSA; v0.5 GA', 'Franchise pilot; international expansion; AI triage v2', 82, 'founder@equipseva.com', 'aligned', 'High clarity heading into Series A'),
  ('2026-04', false, 'Series A close; Tier-2 expansion; engineer payouts', 'Franchise v1; international pilot; AI ops', 55, 'founder@equipseva.com', 'calibrating', 'Tier-2 vs Tier-1 focus debate'),
  ('2026-05', false, 'Series A close; v0.5 GA; hospital chain wins', 'Tier-2 burn-heavy markets; AI triage v2', 48, 'founder@equipseva.com', 'blurry', 'Too many priorities flagged by board'),
  ('2026-06', true, 'Series A close; v0.5 GA; AMC churn fix', 'Tier-2 burn markets; franchise v1; SL/BD/NP pilot', 72, 'founder@equipseva.com', 'aligned', 'Re-focused after May board feedback');

-- Seed recovery actions
INSERT INTO public.clarity_recovery_actions_r2649
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-20 10:00:00+05:30'::timestamptz, 'peer_audit', 'positive', 'founder@equipseva.com', 'done', 'Founder peer group flagged Tier-2 over-reach'
FROM public.founder_strategic_clarity_r2649 WHERE month_label='2026-04';

INSERT INTO public.clarity_recovery_actions_r2649
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-15 09:00:00+05:30'::timestamptz, 'retreat', 'positive', 'founder@equipseva.com', 'done', 'Two-day strategic retreat re-set priorities'
FROM public.founder_strategic_clarity_r2649 WHERE month_label='2026-05';

INSERT INTO public.clarity_recovery_actions_r2649
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-22 11:00:00+05:30'::timestamptz, 'redo_kpis', 'neutral', 'founder@equipseva.com', 'done', 'Re-baselined OKRs for Q2'
FROM public.founder_strategic_clarity_r2649 WHERE month_label='2026-05';

INSERT INTO public.clarity_recovery_actions_r2649
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-05 10:00:00+05:30'::timestamptz, 'customer_immersion', 'positive', 'founder@equipseva.com', 'done', 'Three days on-site with hospital admins clarified roadmap'
FROM public.founder_strategic_clarity_r2649 WHERE month_label='2026-06';

INSERT INTO public.clarity_recovery_actions_r2649
  (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-12 14:00:00+05:30'::timestamptz, 'strategic_pause', 'pending', 'founder@equipseva.com', 'open', 'One-week no-meetings pause to think'
FROM public.founder_strategic_clarity_r2649 WHERE month_label='2026-06';

-- RPCs

CREATE OR REPLACE FUNCTION public.list_clarity_r2649()
RETURNS TABLE (
  id uuid,
  month_label text,
  north_star_clear boolean,
  top_3_priorities_md text,
  top_3_kills_md text,
  clarity_score int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.month_label, c.north_star_clear, c.top_3_priorities_md, c.top_3_kills_md,
         c.clarity_score, c.owner_email, c.status, c.notes, c.created_at
  FROM public.founder_strategic_clarity_r2649 c
  ORDER BY c.month_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_clarity_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_clarity_r2649() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2649()
RETURNS TABLE (
  id uuid,
  pulse_id uuid,
  month_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pulse_id, c.month_label, a.action_at, a.action_kind,
         a.outcome, a.owner_email, a.status, a.notes
  FROM public.clarity_recovery_actions_r2649 a
  JOIN public.founder_strategic_clarity_r2649 c ON c.id = a.pulse_id
  ORDER BY a.action_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2649() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_blurry_focus_r2649()
RETURNS TABLE (
  month_label text,
  clarity_score int,
  status text,
  north_star_clear boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.month_label, c.clarity_score, c.status, c.north_star_clear
  FROM public.founder_strategic_clarity_r2649 c
  ORDER BY c.clarity_score ASC NULLS LAST, c.month_label DESC
  LIMIT 5;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_blurry_focus_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_blurry_focus_r2649() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2649()
RETURNS TABLE (
  status text,
  pulse_count bigint,
  avg_clarity numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status,
         count(*)::bigint AS pulse_count,
         round(coalesce(avg(c.clarity_score), 0)::numeric, 1) AS avg_clarity
  FROM public.founder_strategic_clarity_r2649 c
  GROUP BY c.status
  ORDER BY pulse_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2649() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_clarity_trend_r2649()
RETURNS TABLE (
  month_label text,
  clarity_score int,
  status text,
  north_star_clear boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.month_label, c.clarity_score, c.status, c.north_star_clear
  FROM public.founder_strategic_clarity_r2649 c
  ORDER BY c.month_label ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.monthly_clarity_trend_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_clarity_trend_r2649() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_kind_distribution_r2649()
RETURNS TABLE (
  action_kind text,
  action_count bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         count(*)::bigint AS action_count,
         count(*) FILTER (WHERE a.outcome='positive')::bigint AS positive_count
  FROM public.clarity_recovery_actions_r2649 a
  GROUP BY a.action_kind
  ORDER BY action_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.action_kind_distribution_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_distribution_r2649() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2649()
RETURNS TABLE (
  pulses_logged bigint,
  avg_clarity numeric,
  blurry_months bigint,
  aligned_months bigint,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (SELECT count(*)::bigint FROM public.founder_strategic_clarity_r2649),
         (SELECT round(coalesce(avg(clarity_score), 0)::numeric, 1) FROM public.founder_strategic_clarity_r2649),
         (SELECT count(*)::bigint FROM public.founder_strategic_clarity_r2649 WHERE status='blurry'),
         (SELECT count(*)::bigint FROM public.founder_strategic_clarity_r2649 WHERE status='aligned'),
         (SELECT count(*)::bigint FROM public.clarity_recovery_actions_r2649 WHERE status='open');
END; $$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2649() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2649() TO authenticated;
