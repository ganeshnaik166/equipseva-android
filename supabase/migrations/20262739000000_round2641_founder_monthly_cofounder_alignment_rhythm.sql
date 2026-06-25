-- r2641 founder monthly cofounder alignment rhythm

CREATE TABLE IF NOT EXISTS public.founder_cofounder_alignment_r2641 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  alignment_score int NOT NULL CHECK (alignment_score BETWEEN 0 AND 100),
  decisions_in_sync int NOT NULL DEFAULT 0,
  decisions_diverged int NOT NULL DEFAULT 0,
  tension_kind text NOT NULL CHECK (tension_kind IN ('none','strategy','people','money','pace')),
  recovery_md text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('monitoring','resolving','aligned','strained')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.alignment_recovery_actions_r2641 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alignment_id uuid NOT NULL REFERENCES public.founder_cofounder_alignment_r2641(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('retreat','coach','peer_advisor','decision_framework','structured_pause')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_cofounder_alignment_r2641 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alignment_recovery_actions_r2641 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_cofounder_alignment_r2641;
CREATE POLICY founder_all ON public.founder_cofounder_alignment_r2641
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.alignment_recovery_actions_r2641;
CREATE POLICY founder_all ON public.alignment_recovery_actions_r2641
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.founder_cofounder_alignment_r2641
  (month_label, alignment_score, decisions_in_sync, decisions_diverged, tension_kind, recovery_md, owner_email, status, notes)
VALUES
  ('2026-02', 82, 14, 3, 'pace', 'Slow down hiring cadence by one role per month', 'founder@equipseva.in', 'aligned', 'Mostly aligned month'),
  ('2026-03', 68, 11, 6, 'strategy', 'Pause on vertical expansion until Q2 review', 'founder@equipseva.in', 'resolving', 'Strategy divergence on dental push'),
  ('2026-04', 55, 9, 8, 'people', 'Bring in peer advisor to mediate hiring debate', 'founder@equipseva.in', 'strained', 'Friction over senior engineer hire'),
  ('2026-05', 71, 12, 5, 'money', 'Adopt joint budget framework for spends above 5L', 'founder@equipseva.in', 'resolving', 'Spend disagreement on marketing'),
  ('2026-06', 88, 16, 2, 'none', 'Continue weekly 30-min walking sync', 'founder@equipseva.in', 'aligned', 'Best month in a while');

INSERT INTO public.alignment_recovery_actions_r2641
  (alignment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-04-12 10:00:00+05:30'::timestamptz, 'peer_advisor', 'positive', 'founder@equipseva.in', 'done', 'Brought in advisor Ramesh'
FROM public.founder_cofounder_alignment_r2641 WHERE month_label='2026-04' LIMIT 1;

INSERT INTO public.alignment_recovery_actions_r2641
  (alignment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-03-20 18:00:00+05:30'::timestamptz, 'decision_framework', 'neutral', 'founder@equipseva.in', 'done', 'Adopted RICE for vertical bets'
FROM public.founder_cofounder_alignment_r2641 WHERE month_label='2026-03' LIMIT 1;

INSERT INTO public.alignment_recovery_actions_r2641
  (alignment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-05-15 11:00:00+05:30'::timestamptz, 'structured_pause', 'pending', 'founder@equipseva.in', 'open', 'Two-week spend freeze'
FROM public.founder_cofounder_alignment_r2641 WHERE month_label='2026-05' LIMIT 1;

INSERT INTO public.alignment_recovery_actions_r2641
  (alignment_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-05 09:00:00+05:30'::timestamptz, 'retreat', 'positive', 'founder@equipseva.in', 'done', 'Weekend retreat in Pondicherry'
FROM public.founder_cofounder_alignment_r2641 WHERE month_label='2026-06' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_alignment_r2641()
RETURNS SETOF public.founder_cofounder_alignment_r2641
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_cofounder_alignment_r2641 ORDER BY month_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_alignment_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_alignment_r2641() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2641()
RETURNS SETOF public.alignment_recovery_actions_r2641
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.alignment_recovery_actions_r2641 ORDER BY action_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2641() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_tension_focus_r2641()
RETURNS TABLE(tension_kind text, months_count bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.tension_kind, COUNT(*)::bigint, ROUND(AVG(a.alignment_score)::numeric, 1)
    FROM public.founder_cofounder_alignment_r2641 a
    GROUP BY a.tension_kind
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_tension_focus_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_tension_focus_r2641() TO authenticated;

CREATE OR REPLACE FUNCTION public.alignment_score_trend_r2641()
RETURNS TABLE(month_label text, alignment_score int, decisions_in_sync int, decisions_diverged int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.month_label, a.alignment_score, a.decisions_in_sync, a.decisions_diverged
    FROM public.founder_cofounder_alignment_r2641 a
    ORDER BY a.month_label ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.alignment_score_trend_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.alignment_score_trend_r2641() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2641()
RETURNS TABLE(status text, months_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.status, COUNT(*)::bigint
    FROM public.founder_cofounder_alignment_r2641 a
    GROUP BY a.status
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2641() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_recovery_action_summary_r2641()
RETURNS TABLE(action_kind text, actions_count bigint, positive_count bigint, pending_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.action_kind,
           COUNT(*)::bigint,
           COUNT(*) FILTER (WHERE r.outcome='positive')::bigint,
           COUNT(*) FILTER (WHERE r.outcome='pending')::bigint
    FROM public.alignment_recovery_actions_r2641 r
    GROUP BY r.action_kind
    ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.monthly_recovery_action_summary_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_recovery_action_summary_r2641() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2641()
RETURNS TABLE(months_tracked bigint, avg_alignment numeric, strained_months bigint, open_actions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::bigint FROM public.founder_cofounder_alignment_r2641),
      (SELECT ROUND(AVG(alignment_score)::numeric, 1) FROM public.founder_cofounder_alignment_r2641),
      (SELECT COUNT(*)::bigint FROM public.founder_cofounder_alignment_r2641 WHERE status='strained'),
      (SELECT COUNT(*)::bigint FROM public.alignment_recovery_actions_r2641 WHERE status='open');
END; $$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2641() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2641() TO authenticated;
