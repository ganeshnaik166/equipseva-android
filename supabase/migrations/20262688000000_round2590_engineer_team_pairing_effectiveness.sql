-- Round 2590: engineer-team-pairing-effectiveness
-- Tables + 7 RPCs for founder console

BEGIN;

-- ============================================================
-- TABLE 1: engineer_team_pairings_r2590
-- ============================================================
CREATE TABLE IF NOT EXISTS public.engineer_team_pairings_r2590 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_a_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_b_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pairing_start_at timestamptz NOT NULL DEFAULT now(),
  pairing_end_at timestamptz,
  duration_days integer NOT NULL DEFAULT 0,
  cases_worked_count integer NOT NULL DEFAULT 0,
  csat_lift_pct numeric(6,2) NOT NULL DEFAULT 0,
  productivity_lift_pct numeric(6,2) NOT NULL DEFAULT 0,
  satisfaction_score integer NOT NULL DEFAULT 0 CHECK (satisfaction_score BETWEEN 0 AND 10),
  decision_kind text NOT NULL DEFAULT 'continue' CHECK (decision_kind IN ('continue','swap','dissolve','scale_up')),
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','cancelled')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_team_pairings_r2590 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_team_pairings_r2590;
CREATE POLICY founder_all ON public.engineer_team_pairings_r2590
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_etp_r2590_start ON public.engineer_team_pairings_r2590(pairing_start_at DESC);
CREATE INDEX IF NOT EXISTS idx_etp_r2590_decision ON public.engineer_team_pairings_r2590(decision_kind);
CREATE INDEX IF NOT EXISTS idx_etp_r2590_status ON public.engineer_team_pairings_r2590(status);

-- ============================================================
-- TABLE 2: pairing_swap_outcomes_r2590
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pairing_swap_outcomes_r2590 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_id uuid NOT NULL REFERENCES public.engineer_team_pairings_r2590(id) ON DELETE CASCADE,
  swap_at timestamptz NOT NULL DEFAULT now(),
  new_partner_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason_md text NOT NULL DEFAULT '',
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pairing_swap_outcomes_r2590 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.pairing_swap_outcomes_r2590;
CREATE POLICY founder_all ON public.pairing_swap_outcomes_r2590
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_pso_r2590_pairing ON public.pairing_swap_outcomes_r2590(pairing_id);
CREATE INDEX IF NOT EXISTS idx_pso_r2590_swap_at ON public.pairing_swap_outcomes_r2590(swap_at DESC);

-- ============================================================
-- SEED DATA
-- ============================================================
DO $seed$
DECLARE
  v_eng_a uuid;
  v_eng_b uuid;
  v_eng_c uuid;
  v_eng_d uuid;
  v_p1 uuid;
  v_p2 uuid;
  v_p3 uuid;
  v_p4 uuid;
BEGIN
  SELECT id INTO v_eng_a FROM public.profiles WHERE role = 'engineer' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng_b FROM public.profiles WHERE role = 'engineer' AND id <> COALESCE(v_eng_a, gen_random_uuid()) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng_c FROM public.profiles WHERE role = 'engineer' AND id NOT IN (COALESCE(v_eng_a, gen_random_uuid()), COALESCE(v_eng_b, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng_d FROM public.profiles WHERE role = 'engineer' AND id NOT IN (COALESCE(v_eng_a, gen_random_uuid()), COALESCE(v_eng_b, gen_random_uuid()), COALESCE(v_eng_c, gen_random_uuid())) ORDER BY created_at ASC LIMIT 1;

  IF v_eng_a IS NULL OR v_eng_b IS NULL THEN
    RETURN;
  END IF;

  IF v_eng_c IS NULL THEN v_eng_c := v_eng_a; END IF;
  IF v_eng_d IS NULL THEN v_eng_d := v_eng_b; END IF;

  INSERT INTO public.engineer_team_pairings_r2590
    (engineer_a_user_id, engineer_b_user_id, pairing_start_at, pairing_end_at, duration_days, cases_worked_count, csat_lift_pct, productivity_lift_pct, satisfaction_score, decision_kind, owner_email, status, notes)
  VALUES
    (v_eng_a, v_eng_b, now() - interval '90 days', NULL, 90, 42, 18.50, 24.30, 9, 'scale_up', 'ops@equipseva.com', 'active', 'Top pair - dental specialist combo')
  RETURNING id INTO v_p1;

  INSERT INTO public.engineer_team_pairings_r2590
    (engineer_a_user_id, engineer_b_user_id, pairing_start_at, pairing_end_at, duration_days, cases_worked_count, csat_lift_pct, productivity_lift_pct, satisfaction_score, decision_kind, owner_email, status, notes)
  VALUES
    (v_eng_b, v_eng_c, now() - interval '60 days', NULL, 60, 28, 8.20, 12.10, 7, 'continue', 'ops@equipseva.com', 'active', 'Steady but room to grow')
  RETURNING id INTO v_p2;

  INSERT INTO public.engineer_team_pairings_r2590
    (engineer_a_user_id, engineer_b_user_id, pairing_start_at, pairing_end_at, duration_days, cases_worked_count, csat_lift_pct, productivity_lift_pct, satisfaction_score, decision_kind, owner_email, status, notes)
  VALUES
    (v_eng_c, v_eng_d, now() - interval '120 days', now() - interval '30 days', 90, 35, -3.40, -1.20, 4, 'swap', 'ops@equipseva.com', 'completed', 'Personality clash - swapped out')
  RETURNING id INTO v_p3;

  INSERT INTO public.engineer_team_pairings_r2590
    (engineer_a_user_id, engineer_b_user_id, pairing_start_at, pairing_end_at, duration_days, cases_worked_count, csat_lift_pct, productivity_lift_pct, satisfaction_score, decision_kind, owner_email, status, notes)
  VALUES
    (v_eng_a, v_eng_d, now() - interval '45 days', NULL, 45, 19, 11.80, 15.60, 8, 'continue', 'ops@equipseva.com', 'active', 'New combo showing promise')
  RETURNING id INTO v_p4;

  INSERT INTO public.pairing_swap_outcomes_r2590
    (pairing_id, swap_at, new_partner_user_id, reason_md, outcome, owner_email, status, notes)
  VALUES
    (v_p3, now() - interval '30 days', v_eng_a, 'Skill mismatch on radiology cases', 'positive', 'ops@equipseva.com', 'done', 'Swap to A worked well');

  INSERT INTO public.pairing_swap_outcomes_r2590
    (pairing_id, swap_at, new_partner_user_id, reason_md, outcome, owner_email, status, notes)
  VALUES
    (v_p2, now() - interval '20 days', v_eng_d, 'Geographic coverage - need east zone', 'pending', 'ops@equipseva.com', 'open', 'Awaiting Q2 results');

  INSERT INTO public.pairing_swap_outcomes_r2590
    (pairing_id, swap_at, new_partner_user_id, reason_md, outcome, owner_email, status, notes)
  VALUES
    (v_p1, now() - interval '10 days', v_eng_c, 'Scale up - rotate junior in for mentoring', 'neutral', 'ops@equipseva.com', 'open', 'Mentor rotation experiment');
END;
$seed$;

-- ============================================================
-- RPC 1: list_pairings_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_pairings_r2590()
RETURNS TABLE(
  id uuid,
  engineer_a_user_id uuid,
  engineer_b_user_id uuid,
  pairing_start_at timestamptz,
  pairing_end_at timestamptz,
  duration_days integer,
  cases_worked_count integer,
  csat_lift_pct numeric,
  productivity_lift_pct numeric,
  satisfaction_score integer,
  decision_kind text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.engineer_a_user_id, p.engineer_b_user_id, p.pairing_start_at, p.pairing_end_at,
           p.duration_days, p.cases_worked_count, p.csat_lift_pct, p.productivity_lift_pct,
           p.satisfaction_score, p.decision_kind, p.owner_email, p.status, p.notes
    FROM public.engineer_team_pairings_r2590 p
    ORDER BY p.pairing_start_at DESC NULLS LAST
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pairings_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pairings_r2590() TO authenticated;

-- ============================================================
-- RPC 2: list_swap_outcomes_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_swap_outcomes_r2590()
RETURNS TABLE(
  id uuid,
  pairing_id uuid,
  swap_at timestamptz,
  new_partner_user_id uuid,
  reason_md text,
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
    SELECT s.id, s.pairing_id, s.swap_at, s.new_partner_user_id, s.reason_md, s.outcome,
           s.owner_email, s.status, s.notes
    FROM public.pairing_swap_outcomes_r2590 s
    ORDER BY s.swap_at DESC NULLS LAST
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_swap_outcomes_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_swap_outcomes_r2590() TO authenticated;

-- ============================================================
-- RPC 3: top_lift_pairings_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_lift_pairings_r2590()
RETURNS TABLE(
  id uuid,
  engineer_a_user_id uuid,
  engineer_b_user_id uuid,
  csat_lift_pct numeric,
  productivity_lift_pct numeric,
  combined_lift numeric,
  cases_worked_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.engineer_a_user_id, p.engineer_b_user_id,
           p.csat_lift_pct, p.productivity_lift_pct,
           (p.csat_lift_pct + p.productivity_lift_pct) AS combined_lift,
           p.cases_worked_count
    FROM public.engineer_team_pairings_r2590 p
    ORDER BY (p.csat_lift_pct + p.productivity_lift_pct) DESC NULLS LAST
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lift_pairings_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lift_pairings_r2590() TO authenticated;

-- ============================================================
-- RPC 4: decision_kind_distribution_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.decision_kind_distribution_r2590()
RETURNS TABLE(
  decision_kind text,
  pair_count bigint,
  avg_csat_lift numeric,
  avg_prod_lift numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.decision_kind, COUNT(*)::bigint AS pair_count,
           ROUND(AVG(p.csat_lift_pct)::numeric, 2) AS avg_csat_lift,
           ROUND(AVG(p.productivity_lift_pct)::numeric, 2) AS avg_prod_lift
    FROM public.engineer_team_pairings_r2590 p
    GROUP BY p.decision_kind
    ORDER BY pair_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.decision_kind_distribution_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decision_kind_distribution_r2590() TO authenticated;

-- ============================================================
-- RPC 5: satisfaction_summary_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.satisfaction_summary_r2590()
RETURNS TABLE(
  bucket text,
  pair_count bigint,
  avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN p.satisfaction_score >= 9 THEN 'promoter (9-10)'
        WHEN p.satisfaction_score >= 7 THEN 'passive (7-8)'
        WHEN p.satisfaction_score >= 4 THEN 'detractor (4-6)'
        ELSE 'critical (0-3)'
      END AS bucket,
      COUNT(*)::bigint AS pair_count,
      ROUND(AVG(p.satisfaction_score)::numeric, 2) AS avg_score
    FROM public.engineer_team_pairings_r2590 p
    GROUP BY 1
    ORDER BY avg_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.satisfaction_summary_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.satisfaction_summary_r2590() TO authenticated;

-- ============================================================
-- RPC 6: monthly_pairing_trend_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.monthly_pairing_trend_r2590()
RETURNS TABLE(
  month_start timestamptz,
  pair_count bigint,
  avg_csat_lift numeric,
  avg_prod_lift numeric,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', p.pairing_start_at) AS month_start,
           COUNT(*)::bigint AS pair_count,
           ROUND(AVG(p.csat_lift_pct)::numeric, 2) AS avg_csat_lift,
           ROUND(AVG(p.productivity_lift_pct)::numeric, 2) AS avg_prod_lift,
           ROUND(AVG(p.satisfaction_score)::numeric, 2) AS avg_satisfaction
    FROM public.engineer_team_pairings_r2590 p
    GROUP BY 1
    ORDER BY 1 DESC NULLS LAST
    LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_pairing_trend_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_pairing_trend_r2590() TO authenticated;

-- ============================================================
-- RPC 7: swap_reason_summary_r2590
-- ============================================================
CREATE OR REPLACE FUNCTION public.swap_reason_summary_r2590()
RETURNS TABLE(
  outcome text,
  swap_count bigint,
  open_count bigint,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.outcome,
           COUNT(*)::bigint AS swap_count,
           COUNT(*) FILTER (WHERE s.status = 'open')::bigint AS open_count,
           COUNT(*) FILTER (WHERE s.status = 'done')::bigint AS done_count
    FROM public.pairing_swap_outcomes_r2590 s
    GROUP BY s.outcome
    ORDER BY swap_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.swap_reason_summary_r2590() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.swap_reason_summary_r2590() TO authenticated;

