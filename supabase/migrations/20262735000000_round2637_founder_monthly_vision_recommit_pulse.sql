-- Round 2637: Founder monthly vision recommit pulse
-- Two tables tracking monthly vision clarity recommit cycles + alignment practices

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_vision_recommit_r2637 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  vision_clarity_score int NOT NULL CHECK (vision_clarity_score BETWEEN 0 AND 100),
  conviction_score int NOT NULL CHECK (conviction_score BETWEEN 0 AND 100),
  dissonance_md text,
  recommit_action_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','recommit_done','pivot','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vision_alignment_practices_r2637 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pulse_id uuid NOT NULL REFERENCES public.founder_vision_recommit_r2637(id) ON DELETE CASCADE,
  practice_at timestamptz NOT NULL DEFAULT now(),
  practice_kind text NOT NULL CHECK (practice_kind IN ('retreat','peer_panel','board_review','customer_visit','strategic_pause')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_vision_recommit_r2637 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vision_alignment_practices_r2637 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_vision_recommit_r2637;
CREATE POLICY founder_all ON public.founder_vision_recommit_r2637
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.vision_alignment_practices_r2637;
CREATE POLICY founder_all ON public.vision_alignment_practices_r2637
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_vision_recommit_r2637_month ON public.founder_vision_recommit_r2637(month_label);
CREATE INDEX IF NOT EXISTS idx_vision_recommit_r2637_status ON public.founder_vision_recommit_r2637(status);
CREATE INDEX IF NOT EXISTS idx_align_practices_r2637_pulse ON public.vision_alignment_practices_r2637(pulse_id);
CREATE INDEX IF NOT EXISTS idx_align_practices_r2637_kind ON public.vision_alignment_practices_r2637(practice_kind);

-- Seed pulse rows
INSERT INTO public.founder_vision_recommit_r2637 (month_label, vision_clarity_score, conviction_score, dissonance_md, recommit_action_md, owner_email, status, notes)
VALUES
  ('2026-04', 72, 78, 'Felt pull toward hospital chains over engineers focus', 'Recommit to engineer-first wedge for 2 quarters', 'founder@equipseva.in', 'recommit_done', 'Clarity returned after customer visits'),
  ('2026-05', 65, 70, 'Investor pressure for faster GMV vs slow trust build', 'Hold trust-first; share AMC retention chart with board', 'founder@equipseva.in', 'monitoring', 'Mid-month wobble'),
  ('2026-06', 80, 85, 'Minor noise around AI triage hype; resisting feature creep', 'Stay focused on AMC pool + verified parts moat', 'founder@equipseva.in', 'recommit_done', 'Highest clarity in 6 months'),
  ('2026-03', 58, 62, 'Considered pivot to logistics-only', 'Reread founding doc; pivot dropped; doubled down on full-stack', 'founder@equipseva.in', 'pivot', 'Pivot considered then rejected');

-- Seed practice rows referencing the pulses above
INSERT INTO public.vision_alignment_practices_r2637 (pulse_id, practice_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-10 10:00:00'::timestamptz, 'customer_visit', 'positive', 'founder@equipseva.in', 'done', 'Visited 4 hospitals in Hyderabad'
FROM public.founder_vision_recommit_r2637 WHERE month_label = '2026-04' LIMIT 1;

INSERT INTO public.vision_alignment_practices_r2637 (pulse_id, practice_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-15 09:00:00'::timestamptz, 'peer_panel', 'neutral', 'founder@equipseva.in', 'done', 'Founder peer group session'
FROM public.founder_vision_recommit_r2637 WHERE month_label = '2026-05' LIMIT 1;

INSERT INTO public.vision_alignment_practices_r2637 (pulse_id, practice_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-05 08:00:00'::timestamptz, 'retreat', 'positive', 'founder@equipseva.in', 'done', '2-day silent retreat near Goa'
FROM public.founder_vision_recommit_r2637 WHERE month_label = '2026-06' LIMIT 1;

INSERT INTO public.vision_alignment_practices_r2637 (pulse_id, practice_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-18 16:00:00'::timestamptz, 'board_review', 'positive', 'founder@equipseva.in', 'done', 'Quarterly board alignment'
FROM public.founder_vision_recommit_r2637 WHERE month_label = '2026-06' LIMIT 1;

INSERT INTO public.vision_alignment_practices_r2637 (pulse_id, practice_at, practice_kind, outcome, owner_email, status, notes)
SELECT id, '2026-03-20 11:00:00'::timestamptz, 'strategic_pause', 'positive', 'founder@equipseva.in', 'done', '3-day strategic pause; reread mission'
FROM public.founder_vision_recommit_r2637 WHERE month_label = '2026-03' LIMIT 1;

-- RPC 1: list pulses
DROP FUNCTION IF EXISTS public.list_vision_r2637();
CREATE OR REPLACE FUNCTION public.list_vision_r2637()
RETURNS TABLE (
  id uuid,
  month_label text,
  vision_clarity_score int,
  conviction_score int,
  dissonance_md text,
  recommit_action_md text,
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
  SELECT v.id, v.month_label, v.vision_clarity_score, v.conviction_score,
         v.dissonance_md, v.recommit_action_md, v.owner_email, v.status, v.notes, v.created_at
  FROM public.founder_vision_recommit_r2637 v
  ORDER BY v.month_label DESC, v.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_vision_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_vision_r2637() TO authenticated;

-- RPC 2: list alignment practices
DROP FUNCTION IF EXISTS public.list_alignment_practices_r2637();
CREATE OR REPLACE FUNCTION public.list_alignment_practices_r2637()
RETURNS TABLE (
  id uuid,
  pulse_id uuid,
  month_label text,
  practice_at timestamptz,
  practice_kind text,
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
  SELECT p.id, p.pulse_id, v.month_label, p.practice_at, p.practice_kind,
         p.outcome, p.owner_email, p.status, p.notes
  FROM public.vision_alignment_practices_r2637 p
  JOIN public.founder_vision_recommit_r2637 v ON v.id = p.pulse_id
  ORDER BY p.practice_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_alignment_practices_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_alignment_practices_r2637() TO authenticated;

-- RPC 3: top dissonance focus
DROP FUNCTION IF EXISTS public.top_dissonance_focus_r2637();
CREATE OR REPLACE FUNCTION public.top_dissonance_focus_r2637()
RETURNS TABLE (
  id uuid,
  month_label text,
  vision_clarity_score int,
  conviction_score int,
  gap int,
  dissonance_md text,
  recommit_action_md text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.month_label, v.vision_clarity_score, v.conviction_score,
         (100 - v.vision_clarity_score) AS gap,
         v.dissonance_md, v.recommit_action_md, v.status
  FROM public.founder_vision_recommit_r2637 v
  WHERE v.status IN ('monitoring','pivot')
  ORDER BY (100 - v.vision_clarity_score) DESC, v.month_label DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_dissonance_focus_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_dissonance_focus_r2637() TO authenticated;

-- RPC 4: clarity score trend
DROP FUNCTION IF EXISTS public.clarity_score_trend_r2637();
CREATE OR REPLACE FUNCTION public.clarity_score_trend_r2637()
RETURNS TABLE (
  month_label text,
  avg_clarity numeric,
  avg_conviction numeric,
  pulses int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.month_label,
         ROUND(AVG(v.vision_clarity_score)::numeric, 1) AS avg_clarity,
         ROUND(AVG(v.conviction_score)::numeric, 1) AS avg_conviction,
         COUNT(*)::int AS pulses
  FROM public.founder_vision_recommit_r2637 v
  GROUP BY v.month_label
  ORDER BY v.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.clarity_score_trend_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clarity_score_trend_r2637() TO authenticated;

-- RPC 5: status funnel
DROP FUNCTION IF EXISTS public.status_funnel_r2637();
CREATE OR REPLACE FUNCTION public.status_funnel_r2637()
RETURNS TABLE (
  status text,
  pulses int,
  avg_clarity numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.status,
         COUNT(*)::int AS pulses,
         ROUND(AVG(v.vision_clarity_score)::numeric, 1) AS avg_clarity
  FROM public.founder_vision_recommit_r2637 v
  GROUP BY v.status
  ORDER BY pulses DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2637() TO authenticated;

-- RPC 6: monthly practice summary
DROP FUNCTION IF EXISTS public.monthly_practice_summary_r2637();
CREATE OR REPLACE FUNCTION public.monthly_practice_summary_r2637()
RETURNS TABLE (
  month_label text,
  practice_kind text,
  practices int,
  positive_outcomes int,
  done_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.month_label, p.practice_kind,
         COUNT(*)::int AS practices,
         COUNT(*) FILTER (WHERE p.outcome = 'positive')::int AS positive_outcomes,
         COUNT(*) FILTER (WHERE p.status = 'done')::int AS done_count
  FROM public.vision_alignment_practices_r2637 p
  JOIN public.founder_vision_recommit_r2637 v ON v.id = p.pulse_id
  GROUP BY v.month_label, p.practice_kind
  ORDER BY v.month_label DESC, practices DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_practice_summary_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_practice_summary_r2637() TO authenticated;

-- RPC 7: founder pulse summary
DROP FUNCTION IF EXISTS public.founder_pulse_summary_r2637();
CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2637()
RETURNS TABLE (
  total_pulses int,
  recommit_done int,
  monitoring int,
  pivots int,
  dropped int,
  avg_clarity numeric,
  avg_conviction numeric,
  total_practices int,
  positive_practices int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.founder_vision_recommit_r2637),
    (SELECT COUNT(*)::int FROM public.founder_vision_recommit_r2637 WHERE status = 'recommit_done'),
    (SELECT COUNT(*)::int FROM public.founder_vision_recommit_r2637 WHERE status = 'monitoring'),
    (SELECT COUNT(*)::int FROM public.founder_vision_recommit_r2637 WHERE status = 'pivot'),
    (SELECT COUNT(*)::int FROM public.founder_vision_recommit_r2637 WHERE status = 'dropped'),
    (SELECT ROUND(AVG(vision_clarity_score)::numeric, 1) FROM public.founder_vision_recommit_r2637),
    (SELECT ROUND(AVG(conviction_score)::numeric, 1) FROM public.founder_vision_recommit_r2637),
    (SELECT COUNT(*)::int FROM public.vision_alignment_practices_r2637),
    (SELECT COUNT(*)::int FROM public.vision_alignment_practices_r2637 WHERE outcome = 'positive');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2637() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2637() TO authenticated;

COMMIT;
